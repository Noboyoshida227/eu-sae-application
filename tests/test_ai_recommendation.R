# All providers are mocked. Fixtures contain artificial outputs only; no
# survey microdata, external requests, or model estimation is used.
local({
  checks <- 0L
  verify <- function(ok, label) {
    checks <<- checks + 1L
    if (exists("check", mode = "function", inherits = TRUE)) get("check", mode = "function", inherits = TRUE)(ok, label)
    else { if (!isTRUE(ok)) stop(label, call. = FALSE); cat("PASS -", label, "\n") }
  }
  `%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x
  source("R/comparison_report_ai.R", local = TRUE)
  report_lines <- readLines("report.Rmd", warn = FALSE)
  driver <- parse("scripts/run_pipeline_bg.R")
  eligibility <- Filter(function(x) is.call(x) && identical(x[[1]], as.name("<-")) &&
    identical(x[[2]], as.name("ai_eligible")), driver)[[1L]]
  root <- getwd()
  source("R/brief_generator.R", local = TRUE)
  make_summary <- function(cv, mse) list(`2022` = list(cv_median = cv,
    cv_max = cv, mse_median = mse, n_cv_above_25pct = 0))
  for (pair in list(c(10, 5), c(5, 10), c(5, 5), c(NA, NA), c(Inf, 5))) {
    text <- paste(format_comparison_section(4, make_summary(.2, pair[1]),
      make_summary(.1, pair[2])), collapse = "\n")
    verify(!grepl("indicating more accurate|generally preferred|improved precision from", text) &&
      grepl("do not establish model accuracy", text, fixed = TRUE) &&
      grepl("matched domains", text, fixed = TRUE) &&
      grepl("covariance-boundary", text, fixed = TRUE),
      paste("legacy comparison qualifies lower, equal or unavailable estimated MSE:", paste(pair, collapse = "/")))
  }
  captured_prompt <- NULL
  # Exercise the actual brief/AI entry without making a provider request.
  brief_env <- new.env(parent = environment())
  source("R/brief_generator.R", local = brief_env)
  brief_env$format_model_section <- function(...) "Synthetic model diagnostics"
  brief <- brief_env$generate_analysis_brief(list(), list(), NULL,
    llm = list(enabled = TRUE, query = function(prompt) {
      captured_prompt <<- prompt; "Review requires comparable evidence."
    }), ufh_diagnostics = list(), mfh_diagnostics = list(),
    ufh_bench = make_summary(.2, 10), mfh_bench = make_summary(.1, 5))
  verify(grepl("lower median estimated MSE", brief$template_brief, fixed = TRUE) &&
    grepl("insufficient evidence", captured_prompt, fixed = TRUE) &&
    !grepl("State which approach is better|accuracy \\(MSE\\)", captured_prompt),
    "legacy AI brief preserves conditional precision language without forcing a winner")
  fixture <- tempfile("ai_recommendation_")
  dir.create(file.path(fixture, "outputs/data"), recursive = TRUE)
  dir.create(file.path(fixture, "outputs/tables"), recursive = TRUE)
  old_config <- Sys.getenv("SAE_APP_CONFIG", unset = NA_character_)
  Sys.unsetenv("SAE_APP_CONFIG")
  setwd(fixture)
  on.exit({ setwd(root); if (is.na(old_config)) Sys.unsetenv("SAE_APP_CONFIG") else Sys.setenv(SAE_APP_CONFIG = old_config); unlink(fixture, recursive = TRUE) }, add = TRUE)
  ids <- rep(c("private_domain_A", "private_domain_B"), 2L)
  years <- rep(c(2019L, 2020L), each = 2L)
  fh <- data.frame(domain = ids, year = years, FH = c(.2, .3, .25, .35), FH_MSE = c(1, 100, 1, 100), FH_CV = 5,
    FH_Bench = c(.21, .31, .26, .36), FH_Bench_MSE = c(10, 20, 10, 20), FH_Bench_CV = 6)
  mfh <- data.frame(domain = ids, year = years, direct_rate = .3, direct_mse = .02, direct_cv = 10,
    rate_MFH2 = c(.2, .3, .25, .35), mse_MFH2 = c(.5, NA, .5, NA), cv_MFH2 = 4,
    rate_Bench = c(.21, .31, .26, .36), mse_Bench = c(5, 10, 5, 10), cv_Bench = 5)
  sig <- do.call(rbind, lapply(c("FH", "MFH", "FH Benchmarked", "MFH Benchmarked"), function(method)
    data.frame(domain = unique(ids), method = method, diff = c(.05, .1), mse = c(.002, .003),
      lb = c(-.03, .02), ub = c(.13, .18), p_value = c(.3, .02),
      significant_unadjusted = c(FALSE, TRUE), p_value_bh = c(.3, .04), significant_bh = c(FALSE, TRUE),
      p_value_bonferroni = c(.6, .04), significant_bonferroni = c(FALSE, TRUE),
      inference_status = if (grepl("^MFH", method)) "regular" else "period_independence",
      inference_warning = "", joint_moment_status = "valid")))
  artifacts <- list(diag_model = "MFH2", inference_status = "regular", model_fit_failed = FALSE,
    inference_valid = TRUE, n_domains = 2L, n_domains_fitted = 2L, excluded_domains = character(),
    convergence_check = data.frame(model = c("MFH1", "MFH2"), status = c("not_converged", "ok"),
      inference_status = c("unavailable", "regular")),
    selected_model = list(secret = "sk-artifact-secret-12345678", data = data.frame(domain = ids)),
    formula = "private_covariate ~ private_name", private_path = "C:/private/user/data")
  metadata <- list(mfh_selected_model = "MFH2", mfh_inference_status = "regular", benchmarking = list(enabled = TRUE),
    run_folder = "C:/private/user/data", api_key = "sk-metadata-secret-12345678")
  save_inputs <- function() {
    writexl::write_xlsx(fh, "outputs/data/pov_fh.xlsx")
    writexl::write_xlsx(mfh, "outputs/data/pov_mfh.xlsx")
    writexl::write_xlsx(sig, "outputs/data/statistical_significance_comparison.xlsx")
    saveRDS(artifacts, "outputs/data/mfh_artifacts.rds")
    saveRDS(metadata, "outputs/data/run_metadata.rds")
  }
  save_inputs()
  utils::write.csv(data.frame(method = c("FH", "MFH"), year = 2019L, component = "Residual", n = 2L,
    W = .95, p_value = .2, qq_correlation = .98, secret = "private_domain_A"),
    "outputs/tables/normality_diagnostics.csv", row.names = FALSE)
  for (method in c("ufh", "mfh")) utils::write.csv(data.frame(method = toupper(method), year = 2019L,
    n_domains = 2L, n_predictors = 1L, residual_sd = .1, random_effect_variance = .01,
    formula = "private_covariate ~ private_name", note = "C:/private/user/data", AIC = -999),
    paste0("outputs/tables/", method, "_model_diagnostics.csv"), row.names = FALSE)
  utils::write.csv(data.frame(model = "MFH2", successful_replicates = 50L, failed_refits = 2L,
    covariance_boundary_count = 5L, covariance_boundary_fraction = .1, secret = "private_domain_A"),
    "outputs/tables/mfh_mcpe_validation.csv", row.names = FALSE)
  evidence <- load_comparison_ai_recommendation_evidence(indicator_type = "poverty")
  raw <- evidence$paired_level_precision
  unbench <- raw[raw$benchmark_scope == "unbenchmarked", ]
  bench <- raw[raw$benchmark_scope == "benchmarked", ]
  verify(all(unbench$paired_finite_estimate_MSE == 1L) && all(unbench$excluded_pairs == 1L) &&
    all(unbench$mean_UFH_MSE == 1) && all(unbench$mean_MFH_MSE == .5),
    "recommendation precision uses the same finite pairs rather than unequal marginal means")
  verify(all(bench$paired_finite_estimate_MSE == 2L) && all(bench$mean_UFH_MSE == 15) &&
    all(bench$mean_MFH_MSE == 7.5), "benchmarked precision is kept separate and compared like for like")
  verify(identical(evidence$fit$mfh_inference, "regular") &&
    identical(evidence$fit$selected_mfh_convergence, "passed"), "a nonselected MFH failure does not disqualify the selected valid fit")
  verify(evidence$MFH_bootstrap_diagnostics$failed_refits == 2L &&
    evidence$MFH_bootstrap_diagnostics$covariance_boundary_fraction == .1, "bootstrap failures and accepted boundary fraction reach aggregate evidence")
  payload <- build_comparison_ai_recommendation_prompt(evidence, "fr")
  verify(evidence$units$CV == "dimensionless_ratio_not_percent" && evidence$units$change_MSE == "proportion_difference_squared" &&
    load_comparison_ai_recommendation_evidence(indicator_type = "mean_welfare")$units$change_interval_width == "percent_change",
    "recommendation labels CV ratios and the distinct poverty/welfare level and change units")
  verify(!grepl("private_domain|private_covariate|private_name|C:/private|sk-artifact|sk-metadata|\"AIC\"", payload),
    "recommendation payload excludes identifiers, microdata, formulas, paths, secrets, and incomparable likelihood criteria")
  verify(grepl("French", payload, fixed = TRUE) && grepl("no clear preference", payload, fixed = TRUE) &&
    grepl("insufficient usable evidence", payload, fixed = TRUE) && grepl("period independence", payload, fixed = TRUE) &&
    grepl("not automatic model selection", payload, fixed = TRUE), "recommendation prompt carries language, nonwinner options, assumptions, and advisory scope")
  metadata$benchmarking$enabled <- FALSE; save_inputs()
  verify(all(load_comparison_ai_recommendation_evidence()$paired_level_precision$benchmark_scope == "unbenchmarked"),
    "inactive benchmark columns do not masquerade as final benchmark evidence")
  metadata$benchmarking$enabled <- TRUE
  fh$FH_MSE[1L] <- 0; mfh$mse_MFH2[1L] <- 0; save_inputs()
  zero_evidence <- load_comparison_ai_recommendation_evidence()$paired_level_precision
  zero_row <- zero_evidence$year == 2019 & zero_evidence$benchmark_scope == "unbenchmarked"
  verify(zero_evidence$positive_UFH_MSE_denominator_pairs[zero_row] == 0L &&
    is.na(zero_evidence$mean_paired_MFH_to_UFH_MSE_ratio[zero_row]), "zero MSE denominators are excluded rather than creating infinite precision wins")
  fh$FH_MSE[1L] <- 1; mfh$mse_MFH2[1L] <- .5

  artifacts$inference_status <- "boundary_sensitive"
  artifacts$convergence_check$inference_status[2L] <- "boundary_sensitive"
  invalid_row <- sig$method == "MFH" & sig$domain == "private_domain_B"
  sig$joint_moment_status[invalid_row] <- "invalid_non_psd"
  sig$significant_unadjusted[sig$method == "FH" & sig$domain == "private_domain_A"] <- NA
  save_inputs()
  loaded <- load_comparison_ai_data()
  one <- loaded$significance[loaded$significance$method == "MFH", ]
  verify(one$inference_status[one$domain == "private_domain_A"] == "boundary_sensitive" &&
    one$inference_status[one$domain == "private_domain_B"] == "unavailable" &&
    is.na(one$significant_unadjusted[one$domain == "private_domain_B"]),
    "actual workbook loader retains boundary status and excludes invalid joint-moment inference")
  verify(is.na(loaded$significance$significant_unadjusted[loaded$significance$method == "FH" &
    loaded$significance$domain == "private_domain_A"]), "unknown significance flags remain NA rather than nonsignificant")
  boundary <- load_comparison_ai_recommendation_evidence()$paired_change_precision
  boundary <- boundary[boundary$benchmark_scope == "unbenchmarked", ]
  verify(boundary$paired_finite_change_MSE == 1L && boundary$excluded_pairs == 1L &&
    boundary$boundary_sensitive_pairs == 1L, "global boundary status cannot rehabilitate an invalid per-domain joint moment")
  prompts <- build_comparison_ai_prompts("fr")
  verify(grepl("covariance-boundary-sensitive", prompts$system, fixed = TRUE),
    "actual loader and artifacts carry boundary qualifications into the shared AI system prompt")
  sig <- sig[!(sig$method == "MFH" & sig$domain == "private_domain_B"), ]; save_inputs()
  partial <- load_comparison_ai_recommendation_evidence()$paired_change_precision
  partial <- partial[partial$benchmark_scope == "unbenchmarked", ]
  verify(partial$UFH_only_domains == 1L && partial$union_domains == 2L && partial$matched_domains == 1L,
    "change comparisons disclose unmatched domains and their coverage denominator")
  fh <- rbind(fh, fh[1L, ]); save_inputs()
  duplicate <- load_comparison_ai_recommendation_evidence()
  verify(duplicate$completeness$UFH$duplicates == 1L && nrow(duplicate$paired_level_precision) == 0L &&
    duplicate$evidence_status == "insufficient_usable_evidence", "duplicate domain-year keys cannot multiply recommendation precision rows")
  verify(inherits(try(load_comparison_ai_data(), silent = TRUE), "try-error"),
    "descriptive AI loader also rejects duplicate keys")
  fh <- fh[-nrow(fh), ]; artifacts$model_fit_failed <- TRUE; save_inputs()
  failed <- load_comparison_ai_recommendation_evidence()
  verify(failed$fit$mfh_inference == "unavailable" &&
    all(failed$paired_change_precision$paired_finite_change_MSE == 0L),
    "failed selected fit makes change inference unavailable despite finite exported numbers")
  artifacts <- list(); metadata$mfh_inference_status <- NULL; metadata$mfh_selected_model <- NULL; save_inputs()
  verify(load_comparison_ai_recommendation_evidence()$fit$mfh_inference == "not_recorded", "missing fit status remains unknown rather than assumed valid")

  # Generation, metadata, numeric QA, consent, and failure behavior use mocks.
  sent <- list()
  mock <- list(enabled = TRUE, provider = "mock", model = "fixture-model", query = function(prompt, system_prompt = NULL) {
    sent[[length(sent) + 1L]] <<- list(prompt = prompt, system = system_prompt)
    if (grepl("advisory UFH-versus-MFH", prompt, fixed = TRUE)) "Aucune préférence nette. Une revue humaine est nécessaire. 777.9"
    else "Interprétation descriptive pour revue humaine."
  })
  numeric_files <- list.files("outputs", pattern = "\\.xlsx$", recursive = TRUE, full.names = TRUE)
  before <- tools::md5sum(numeric_files)
  state <- generate_comparison_ai_interpretations(mock, language = "fr", consent_recorded = TRUE, logger = function(...) NULL)
  verify(state$sections$recommendation$status == "generated" && length(sent) == length(comparison_ai_sections()) &&
    state$language == "fr" && state$human_review_status == "not_reviewed", "AI-on generates the dedicated recommendation with language and human-review metadata")
  verify(state$sections$recommendation$numeric_qa$status == "warning" &&
    777.9 %in% state$sections$recommendation$numeric_qa$unverified_numbers, "recommendation inherits warning-only numeric provenance QA")
  verify(identical(before, tools::md5sum(numeric_files)), "AI generation leaves numerical result workbooks unchanged")
  save_comparison_ai_interpretations(state)
  saved <- readRDS("outputs/data/run_metadata.rds")$ai_interpretations
  verify("recommendation" %in% saved$generated_sections && saved$numeric_qa_status[["recommendation"]] == "warning" &&
    grepl("recommendation", saved$prompt_version, fixed = TRUE), "recommendation state and prompt version are recorded in run metadata")
  sent <- list()
  disabled <- generate_comparison_ai_interpretations(mock, consent_recorded = FALSE, logger = function(...) NULL)
  verify(length(sent) == 0L && disabled$sections$recommendation$status == "disabled" && !disabled$enabled,
    "missing consent blocks all provider calls even if the provider object is enabled")
  mock$enabled <- FALSE
  disabled_provider <- generate_comparison_ai_interpretations(mock, consent_recorded = TRUE, logger = function(...) NULL)
  verify(length(sent) == 0L && disabled_provider$sections$recommendation$status == "disabled", "disabled provider does not generate a recommendation")
  mock$enabled <- TRUE
  mock$query <- function(prompt, system_prompt = NULL) {
    if (grepl("advisory UFH-versus-MFH", prompt, fixed = TRUE)) stop("provider failure sk-secret-fixture-12345678")
    "Available descriptive interpretation."
  }
  failure <- generate_comparison_ai_interpretations(mock, consent_recorded = TRUE, logger = function(...) NULL)
  verify(failure$sections$recommendation$status == "failed" &&
    !grepl("sk-secret", failure$sections$recommendation$failure_reason, fixed = TRUE) &&
    failure$sections$overview$status == "generated", "recommendation provider failure is isolated, explicit, and secret-redacted")
  verify(grepl("Failed", comparison_ai_section_html(failure, "recommendation"), fixed = TRUE) &&
    identical(comparison_ai_section_html(state, "recommendation", include_ai = FALSE), ""),
    "failed recommendation remains identifiable and AI-off hides the block")

  start <- grep("^```\\{r ai-model-recommendation", report_lines)
  end <- which(seq_along(report_lines) > start & report_lines == "```")[1L]
  report_code <- parse(text = report_lines[seq.int(start + 1L, end - 1L)])
  ai_state <- state; params <- list(include_ai = FALSE)
  off_html <- paste(capture.output(eval(report_code)), collapse = "\n")
  params$include_ai <- TRUE
  on_html <- paste(capture.output(eval(report_code)), collapse = "\n")
  verify(!nzchar(off_html) && grepl("AI Recommendation: UFH or MFH", on_html, fixed = TRUE) &&
    grepl('id="ai-recommendation"', on_html, fixed = TRUE), "actual report chunk renders the dedicated section only when include_ai is true")
  ai_state <- failure
  verify(grepl("Interpretation not generated", paste(capture.output(eval(report_code)), collapse = "\n"), fixed = TRUE),
    "actual report chunk displays recommendation failure without fabricated advice")

  ok <- TRUE; api_key <- "mock-key"
  for (scenario in c("valid", "off", "no_consent", "no_comparison")) {
    ai_requested <- scenario != "off"
    ai <- list(eligible = TRUE, consent = scenario != "no_consent")
    job <- list(steps = if (scenario == "no_comparison") "UFH" else "Comparison")
    eval(eligibility)
    verify(identical(ai_eligible, scenario == "valid"), paste("background driver enforces AI request/consent/Comparison gate:", scenario))
  }
  empty <- file.path(fixture, "missing_outputs")
  dir.create(empty); setwd(empty)
  missing_evidence <- load_comparison_ai_recommendation_evidence()
  missing_prompts <- build_comparison_ai_prompts()
  verify(missing_evidence$evidence_status == "insufficient_usable_evidence" &&
    grepl("insufficient_usable_evidence", missing_prompts$recommendation, fixed = TRUE),
    "missing artifacts produce an explicit insufficient-evidence prompt instead of a default winner")
  mock$query <- function(prompt, system_prompt = NULL) "Insufficient usable evidence. Obtain comparable outputs and diagnostics for human review."
  missing_state <- generate_comparison_ai_interpretations(mock, consent_recorded = TRUE, logger = function(...) NULL)
  verify(missing_state$sections$recommendation$status == "generated" &&
    missing_state$sections$overview$status == "failed", "insufficient-evidence advice can be generated while unavailable descriptive sections fail explicitly")
  cat(sprintf("All %d AI recommendation checks passed.\n", checks))
})
