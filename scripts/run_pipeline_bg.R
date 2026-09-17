# ============================================================
# run_pipeline_bg.R -- background driver for one dashboard run
# ============================================================
#
# Launched by the app (sae_bg_launch() in app_support.R) as
#     Rscript --vanilla scripts/run_pipeline_bg.R <run_dir>
# with the package root as working directory. It performs everything the
# dashboard used to do inside its own process after the configuration was
# written: the UFH / MFH / Comparison steps (each in its own R child), the
# optional AI interpretations, the final report, and the archive copy of
# outputs/ into the run folder. Progress is written to
# <run_dir>/run_status.rds and messages to <run_dir>/run.log; the app polls
# both and stays responsive while this process works.
#
# The user's Stop button writes <run_dir>/STOP and ends the R child of the
# current step; sae_bg_check_stop() turns that into the final state
# "stopped" at the next check point.
#
# Inputs: <run_dir>/job.rds, a list written by the app with
#   config_path       app_config.yml of this run
#   steps             requested steps
#   ai$requested / ai$eligible / ai$provider / ai$model / ai$language /
#   ai$consent / ai$indicator_type / ai$currency_symbol / ai$log_transform /
#   ai$disabled_reason
# The API key (if any) is read from the environment variable
# SAE_LLM_API_KEY set by the app for this process only.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1L || !dir.exists(args[[1]])) {
  stop("Usage: Rscript scripts/run_pipeline_bg.R <run_dir>", call. = FALSE)
}
run_dir <- normalizePath(args[[1]], winslash = "/", mustWork = TRUE)
options(warn = 1)

# ---- Load the app's helper code (no Shiny needed) ----
source("app_support.R")
for (f in c("R/release_controls.R", "R/multilingual.R", "R/llm_assistant.R",
            "R/comparison_report_ai.R", "R/validation_checks.R")) {
  if (file.exists(f)) source(f)
}

Sys.setenv(SAE_RUN_DIR = run_dir)
sae_bg_record_pid(run_dir, "driver")
api_key <- Sys.getenv("SAE_LLM_API_KEY", "")
Sys.unsetenv("SAE_LLM_API_KEY")

job <- readRDS(file.path(run_dir, "job.rds"))
run_log_path <- file.path(run_dir, "run.log")

logger <- function(msg) {
  line <- sprintf("[%s] %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
                  paste(as.character(msg), collapse = " "))
  tryCatch(cat(line, "\n", file = run_log_path, append = TRUE, sep = ""),
           error = function(e) NULL)
  cat(line, "\n", sep = "")
}

set_phase <- function(phase, detail = NULL) {
  sae_bg_write_status(run_dir, state = "running", phase = phase,
                      phase_detail = detail %||% phase)
}

progress_callback <- function(event, label) {
  if (identical(event, "start")) {
    detail <- switch(label,
      UFH        = "Univariate Fay-Herriot model",
      MFH        = "Multivariate Fay-Herriot model",
      Comparison = "Comparing UFH and MFH results",
      Report     = "Rendering the final report",
      label
    )
    set_phase(label, detail)
  } else if (identical(event, "skipped")) {
    set_phase(label, sprintf("%s skipped", label))
  }
}

finish <- function(state, ...) {
  sae_bg_write_status(run_dir, state = state,
                      finished_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S"), ...)
}

sae_bg_write_status(run_dir, state = "running", phase = "Starting",
                    phase_detail = "Analysis process started",
                    driver_pid = Sys.getpid())
logger(sprintf("Background analysis process started (PID %d).", Sys.getpid()))

ok      <- TRUE
stopped <- FALSE
err_msg <- NULL

# ---- Step 2: UFH / MFH / Comparison ----
tryCatch(
  {
    run_pipeline_from_config(
      config_path       = job$config_path,
      logger            = logger,
      progress_callback = progress_callback,
      render_report     = FALSE
    )
  },
  sae_run_stopped = function(e) stopped <<- TRUE,
  error = function(e) {
    ok      <<- FALSE
    err_msg <<- conditionMessage(e)
  }
)

if (stopped) {
  logger("Run stopped by the user before the analysis was complete.")
  finish("stopped", ok = FALSE, err_msg = "Run stopped by the user.")
  quit(save = "no", status = 0L)
}

# ---- Step 2b: AI interpretations (optional) ----
ai <- job$ai %||% list()
ai_requested <- isTRUE(ai$requested)
ai_eligible  <- ok && isTRUE(ai$eligible) && nzchar(api_key)
provider_hint <- ai$provider %||% NA_character_
model_hint    <- ai$model %||% NA_character_
disabled_reason <- if (!ai_requested) {
  "AI interpretation was not requested for this run."
} else if (!isTRUE(ai$consent)) {
  "AI interpretation was disabled because external-transfer consent was not recorded."
} else if (!nzchar(api_key)) {
  "AI interpretation was disabled because no provider API key was supplied."
} else if (!ok) {
  "AI interpretation was not attempted because the statistical pipeline failed."
} else {
  "AI interpretation was not available."
}
logger(sprintf("AI note check: ok=%s, Comparison=%s, requested=%s, api_key_set=%s -> eligible=%s",
               ok, "Comparison" %in% (job$steps %||% character()), ai_requested,
               nzchar(api_key), ai_eligible))

ai_state <- new_comparison_ai_interpretation_state(
  requested = ai_requested,
  enabled = ai_eligible,
  provider = provider_hint,
  model = model_hint,
  language = ai$language %||% "en",
  consent_recorded = isTRUE(ai$consent),
  include_in_report = ai_requested,
  default_status = "disabled",
  default_reason = disabled_reason
)

if (ai_eligible) {
  tryCatch(sae_bg_check_stop(logger = logger),
           sae_run_stopped = function(e) stopped <<- TRUE)
}
if (stopped) {
  finish("stopped", ok = FALSE, err_msg = "Run stopped by the user.")
  quit(save = "no", status = 0L)
}

if (ai_eligible) {
  set_phase("LLM Interpretation", "Generating report interpretations")
  logger("Generating AI interpretations for the final report...")
  tryCatch({
    llm <- llm_assistant(api_key = api_key, provider = detect_llm_provider(api_key))
    ai_state <- generate_comparison_ai_interpretations(
      llm              = llm,
      language         = ai$language %||% "en",
      indicator_type   = ai$indicator_type %||% "poverty",
      currency_symbol  = ai$currency_symbol %||% "EUR",
      log_transform    = isTRUE(ai$log_transform),
      consent_recorded = isTRUE(ai$consent),
      logger           = logger
    )
    generated_count <- sum(vapply(
      ai_state$sections,
      function(section) identical(section$status, "generated"),
      logical(1)
    ))
    if (generated_count > 0L) {
      logger(sprintf(
        "%d AI interpretation section(s) prepared for integration into final_report.html.",
        generated_count
      ))
    } else {
      logger("WARNING: No AI interpretation sections were generated; failure statuses will appear in the final report.")
    }
  }, error = function(e) {
    failure_reason <- sanitize_ai_failure_message(conditionMessage(e))
    ai_state <<- new_comparison_ai_interpretation_state(
      requested = TRUE,
      enabled = TRUE,
      provider = provider_hint,
      model = model_hint,
      language = ai$language %||% "en",
      consent_recorded = TRUE,
      include_in_report = TRUE,
      default_status = "failed",
      default_reason = failure_reason
    )
    logger(paste("WARNING: AI interpretation generation failed:", failure_reason))
  })
}
rm(api_key)

# ---- Step 2c: final report ----
report_result <- NULL
if (ok) {
  tryCatch(sae_bg_check_stop(logger = logger),
           sae_run_stopped = function(e) stopped <<- TRUE)
  if (stopped) {
    finish("stopped", ok = FALSE, err_msg = "Run stopped by the user.")
    quit(save = "no", status = 0L)
  }
  tryCatch({
    save_comparison_ai_interpretations(ai_state)
    statuses <- vapply(ai_state$sections, function(section) section$status, character(1))
    logger(sprintf(
      "AI interpretation state saved: %d generated, %d failed, %d disabled section(s).",
      sum(statuses == "generated"), sum(statuses == "failed"),
      sum(statuses == "disabled")
    ))
    report_result <- render_final_report(
      include_ai = ai_requested,
      logger = logger,
      progress_callback = progress_callback
    )
  }, error = function(e) {
    ok      <<- FALSE
    err_msg <<- paste("Final report rendering failed:", conditionMessage(e))
  })
}
report_missing <- ok && !is.null(report_result) && !isTRUE(report_result$rendered)
report_reason  <- if (report_missing && is.character(report_result$reason)) report_result$reason else NULL

# ---- Step 3: archive outputs into the run folder ----
archive_dir <- NULL
if (ok) {
  set_phase("Finalizing", "Archiving outputs")
  archive_dir <- file.path(run_dir, "outputs")
  tryCatch({
    if (dir.exists(archive_dir)) {
      unlink(archive_dir, recursive = TRUE, force = TRUE)
    }
    dir.create(archive_dir, recursive = TRUE, showWarnings = FALSE)
    output_files <- list.files("outputs", all.files = TRUE, no.. = TRUE,
                               full.names = TRUE)
    if (length(output_files) > 0) {
      file.copy(output_files, archive_dir, recursive = TRUE,
                overwrite = TRUE, copy.date = TRUE)
    }
    logger(paste("Archived run outputs:",
                 normalizePath(archive_dir, winslash = "/", mustWork = FALSE)))
  }, error = function(e) {
    logger(paste("WARNING: Could not archive run outputs:", e$message))
    archive_dir <<- NULL
  })
  if (report_missing) {
    logger(paste0(
      "NOTE: Run finished without the final report. ",
      report_reason %||% "Pandoc unavailable",
      " Re-run after Pandoc is available to produce outputs/final_report.html."
    ))
  }
  logger("Pipeline finished.")
  finish("finished", ok = TRUE, err_msg = NULL,
         report_missing = report_missing, report_reason = report_reason,
         archive_dir = archive_dir)
} else {
  logger(paste("ERROR:", err_msg))
  finish("failed", ok = FALSE, err_msg = err_msg,
         report_missing = FALSE, report_reason = NULL, archive_dir = NULL)
}
quit(save = "no", status = 0L)
