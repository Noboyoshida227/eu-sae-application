# Illustrative sm_out counts from the production Direct/GVF code, without any
# FH/MFH model fitting or bootstrap campaign. Run from the repository root:
# Rscript docs/reviews/w5p_2026-10-28/checks/measure_sm_out_examples.R <scratch-output>
# Set R_LIBS_USER externally when a separate installed library is required.
args <- commandArgs(trailingOnly = TRUE)
out_dir <- if (length(args)) args[1L] else tempfile("w5p_sm_out_")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
suppressPackageStartupMessages({
  library(survey); library(dplyr); library(tidyr); library(purrr); library(tibble)
  library(data.table)
})
options(survey.lonely.psu = "adjust")
source("scripts/ufh_functions.R")
source("scripts/population_helpers.R")
source("R/pipeline_helpers.R")
source("R/variance_policy.R")
ufh_expr <- parse("scripts/01_ufh.R", encoding = "UTF-8")
assigned <- function(e, name) {
  is.call(e) && identical(e[[1L]], as.name("<-")) && identical(e[[2L]], as.name(name))
}
for (e in ufh_expr) {
  if (any(vapply(c("run_fh_year", "make_sae_design", ".safe_cv"),
                 function(n) assigned(e, n), logical(1)))) eval(e)
}
# Evaluate the actual run_fh_year Direct and smoothing prefix, ending before
# joining covariates/selection/fitting. No copied alternative variance formula.
ufh_prefix <- as.list(body(run_fh_year))[-1L]
cut <- which(vapply(ufh_prefix, assigned, logical(1), name = "fh_dt"))[1L]
stopifnot(is.finite(cut), cut > 1L)
ufh_prefix <- ufh_prefix[seq_len(cut - 1L)]

# The corresponding MFH block defines the joint two-year survey design and
# runs Direct estimation, GVF and the shared variance policy only.
mfh_source <- paste(readLines("scripts/02_mfh.R", warn = FALSE, encoding = "UTF-8"), collapse = "\n")
start <- regexpr("# Ensure years_keep is standardized for consistent filtering", mfh_source, fixed = TRUE)[1L]
end <- regexpr("##### Option 1: Cov - Domain direct", mfh_source, fixed = TRUE)[1L]
stopifnot(start > 0L, end > start)
mfh_prefix <- parse(text = substr(mfh_source, start, end - 1L))

configs <- list(
  Spain = list(path = "Data/Spain/survey.rds", years = c(2012L, 2013L),
               use_strata = FALSE, domain = "prov", psu = "ea_id"),
  simulated = list(path = "Data/simulated/survey_example.csv", years = c(2022L, 2023L),
                   use_strata = TRUE, domain = "domain", psu = "psu")
)
results <- list(); settings <- list(); events <- list()
file_sha256 <- function(path) {
  # Reading bytes avoids platform file.access() false negatives in restricted
  # Windows sessions; the hash remains SHA-256 of the unmodified file bytes.
  digest::digest(readBin(path, "raw", n = file.info(path)$size),
                 algo = "sha256", serialize = FALSE)
}
capture_eval <- function(expressions, env) {
  warnings <- character()
  error <- tryCatch(withCallingHandlers({
    for (e in expressions) eval(e, envir = env)
    ""
  }, warning = function(w) {
    warnings <<- c(warnings, conditionMessage(w)); invokeRestart("muffleWarning")
  }), error = function(e) conditionMessage(e))
  list(error = error, warnings = unique(warnings))
}
summarize_policy <- function(dataset, path, year, alpha, raw, working, error = "") {
  eligible <- !is.finite(raw) | raw < SAE_SM_OUT_VARIANCE_THRESHOLD
  success <- eligible & is.finite(working) & working > 0
  data.frame(dataset = dataset, design_path = path, year = year,
    indicator = paste0("FGT", alpha), variance_scale = "identity proportion squared",
    denominator = length(raw), eligible = sum(eligible), proportion_eligible = mean(eligible),
    nonfinite = sum(!is.finite(raw)), finite_below_0_001 = sum(is.finite(raw) & raw < .001),
    equal_to_0_001 = sum(is.finite(raw) & raw == .001),
    above_0_001 = sum(is.finite(raw) & raw > .001),
    successful_replacements = sum(success), failed_replacements = sum(eligible & !success),
    error = error, stringsAsFactors = FALSE)
}
for (dataset in names(configs)) {
  cfg <- configs[[dataset]]
  input <- if (tools::file_ext(cfg$path) == "rds") readRDS(cfg$path) else read.csv(cfg$path)
  survey_all <- as.data.frame(input)
  names(survey_all)[names(survey_all) == cfg$domain] <- "domain"
  names(survey_all)[names(survey_all) == cfg$psu] <- "psu"
  names(survey_all)[names(survey_all) == "income"] <- "welfare"
  names(survey_all)[names(survey_all) == "hhsize"] <- "hh_size"
  survey_all <- sae_apply_survey_unit(survey_all, "household", "example audit")
  survey_all <- sae_add_population_weight(survey_all, context = "example audit")
  survey_all$domain <- trimws(as.character(survey_all$domain))
  survey_all <- survey_all[survey_all$year %in% cfg$years, , drop = FALSE]
  use_strata <- cfg$use_strata
  settings[[dataset]] <- list(input = cfg$path,
    sha256 = file_sha256(cfg$path), years = cfg$years,
    survey_unit = "household", weight = "weight * hh_size", psu = cfg$psu,
    strata = if (use_strata) "strata (nest = TRUE)" else "none",
    lonely_psu = "adjust", poverty_line = "supplied povline column; no recomputation",
    transformation = "identity", variance_policy = "sm_out", threshold = .001,
    seed = "none; deterministic Direct/GVF calculation", model_fits = 0L, bootstrap_draws = 0L)
  for (alpha in 0:2) {
    base_env <- new.env(parent = globalenv())
    base_env$indicator_type <- "poverty"; base_env$fgt_alpha <- alpha
    base_env$log_transform <- FALSE; base_env$years_keep <- cfg$years
    base_env$use_strata <- use_strata
    for (yr in cfg$years) {
      env <- new.env(parent = base_env)
      env$survey_all <- survey_all
      env$rhs_dt_raw <- unique(survey_all[c("domain", "year")]); env$rhs_dt_raw$x <- 1
      env$yr <- yr; env$transformation <- "no"; env$candidate_vars_override <- NULL
      env$var_choice <- "sm_out"
      outcome <- capture_eval(ufh_prefix, env)
      stopifnot(exists("var_dt", envir = env, inherits = FALSE))
      raw <- env$var_dt$se^2
      working <- rep(NA_real_, length(raw))
      if (!nzchar(outcome$error) && "Domain" %in% names(env$direct_dt)) {
        working <- env$direct_dt$vardir[match(as.character(env$var_dt$domain),
                                             as.character(env$direct_dt$Domain))]
      }
      key <- paste(dataset, "UFH", yr, alpha, sep = "_")
      results[[key]] <- summarize_policy(dataset, "UFH annual design", yr, alpha, raw, working, outcome$error)
      events[[key]] <- outcome
    }
    env <- new.env(parent = base_env); env$survey_dt <- survey_all
    outcome <- capture_eval(mfh_prefix, env)
    stopifnot(exists("all_var_hat_domain_dt", envir = env, inherits = FALSE))
    for (i in seq_along(cfg$years)) {
      raw <- env$all_var_hat_domain_dt[[paste0("v", i)]]
      working <- env$all_var_hat_domain_dt[[paste0("v", i, "_sm_out")]]
      if (is.null(working)) working <- rep(NA_real_, length(raw))
      key <- paste(dataset, "MFH", cfg$years[i], alpha, sep = "_")
      results[[key]] <- summarize_policy(dataset, "MFH joint design", cfg$years[i], alpha, raw, working, outcome$error)
      events[[key]] <- outcome
    }
  }
}
result <- do.call(rbind, results); rownames(result) <- NULL
write.csv(result, file.path(out_dir, "sm_out_counts.csv"), row.names = FALSE)
source_paths <- c("scripts/01_ufh.R", "scripts/02_mfh.R", "scripts/ufh_functions.R",
                  "scripts/population_helpers.R", "R/pipeline_helpers.R", "R/variance_policy.R")
provenance <- list(settings = settings, events = events,
  source_sha256 = setNames(vapply(source_paths, file_sha256, character(1)), source_paths),
  R = R.version.string,
  package_versions = setNames(vapply(c("survey", "dplyr", "tidyr", "purrr", "tibble", "data.table"),
                                    function(p) as.character(packageVersion(p)), character(1)),
                             c("survey", "dplyr", "tidyr", "purrr", "tibble", "data.table")),
  interpretation = "Illustrative synthetic examples only; counts do not establish country-wide replacement prevalence or coverage.")
jsonlite::write_json(provenance, file.path(out_dir, "sm_out_provenance.json"), pretty = TRUE, auto_unbox = TRUE)
print(result, row.names = FALSE)
cat("No model fits or bootstrap draws. Results:", normalizePath(out_dir, winslash = "/"), "\n")
