# Aggregate-only evidence for advisory UFH/MFH recommendations. Identifiers
# are used locally for matching and never returned in this payload.
comparison_ai_inference_summary <- function(artifacts = list(), metadata = list(), convergence = NULL) {
  allowed <- c("regular", "ok", "boundary_sensitive", "unavailable", "period_independence")
  model <- as.character(artifacts$diag_model %||% metadata$mfh_selected_model %||% "not_recorded")[1L]
  if (!model %in% c("MFH1", "MFH2", "MFH3")) model <- "not_recorded"
  if (is.null(convergence)) convergence <- artifacts$convergence_check
  selected <- if (is.data.frame(convergence) && "model" %in% names(convergence)) {
    convergence[!is.na(convergence$model) & as.character(convergence$model) == model, , drop = FALSE]
  } else data.frame()
  status <- c(artifacts$inference_status, metadata$mfh_inference_status,
              if (nrow(selected)) selected$inference_status)
  status <- as.character(status)
  status <- status[status %in% allowed]
  failed <- isTRUE(artifacts$model_fit_failed) || identical(artifacts$inference_valid, FALSE) ||
    (nrow(selected) > 0L && "status" %in% names(selected) &&
       any(!is.na(selected$status) & selected$status != "ok"))
  inference <- if (failed || "unavailable" %in% status) "unavailable" else
    if ("boundary_sensitive" %in% status) "boundary_sensitive" else
      if (any(status %in% c("regular", "ok"))) "regular" else "not_recorded"
  convergence_status <- if (failed) "failed" else if (nrow(selected) &&
    "status" %in% names(selected) && all(!is.na(selected$status) & selected$status == "ok")) "passed" else "not_recorded"
  list(selected_mfh_model = model, mfh_inference = inference,
       selected_mfh_convergence = convergence_status,
       ufh_change_assumption = "period_independence")
}

load_comparison_ai_recommendation_evidence <- function(data_dir = "outputs/data", tables_dir = "outputs/tables", indicator_type = NULL) {
  read_rds <- function(name) {
    path <- file.path(data_dir, name)
    x <- if (file.exists(path)) tryCatch(readRDS(path), error = function(e) list()) else list()
    if (is.list(x)) x else list()
  }
  read_csv <- function(name) {
    path <- file.path(tables_dir, name)
    if (file.exists(path)) tryCatch(utils::read.csv(path, stringsAsFactors = FALSE), error = function(e) NULL) else NULL
  }
  read_xlsx <- function(name) {
    path <- file.path(data_dir, name)
    if (file.exists(path)) tryCatch(as.data.frame(readxl::read_excel(path)), error = function(e) NULL) else NULL
  }
  number <- function(x) suppressWarnings(as.numeric(x))
  finite_mean <- function(x) if (length(x) && any(is.finite(x))) mean(x[is.finite(x)]) else NA_real_
  count <- function(x) { x <- number(x); if (length(x) == 1L && is.finite(x) && x >= 0) x else NA_real_ }
  artifacts <- read_rds("mfh_artifacts.rds")
  metadata <- read_rds("run_metadata.rds")
  indicator_info <- read_csv("indicator_info.csv")
  indicator <- as.character(indicator_type %||% indicator_info$indicator_type %||% "not_recorded")[1L]
  if (!indicator %in% c("poverty", "mean_welfare")) indicator <- "not_recorded"
  units <- list(indicator = indicator, CV = "dimensionless_ratio_not_percent",
    level_estimate_RMSE = switch(indicator, poverty = "proportion", mean_welfare = "currency_units", "not_recorded"),
    level_MSE = switch(indicator, poverty = "proportion_squared", mean_welfare = "currency_units_squared", "not_recorded"),
    change_interval_width = switch(indicator, poverty = "proportion_difference", mean_welfare = "percent_change", "not_recorded"),
    change_MSE = switch(indicator, poverty = "proportion_difference_squared", mean_welfare = "percent_change_squared", "not_recorded"))
  fit <- comparison_ai_inference_summary(artifacts, metadata, read_csv("mfh_convergence_check.csv"))
  cfg_path <- Sys.getenv("SAE_APP_CONFIG", unset = "")
  cfg <- if (nzchar(cfg_path) && file.exists(cfg_path))
    tryCatch(yaml::read_yaml(cfg_path), error = function(e) list()) else list()
  bench <- function(method) {
    x <- cfg[[method]]$do_benchmark %||% cfg$benchmarking$enabled %||% metadata$benchmarking$enabled
    if (identical(x, TRUE)) "enabled" else if (identical(x, FALSE)) "disabled" else "not_recorded"
  }
  final_benchmark <- list(UFH = bench("ufh"), MFH = bench("mfh"))
  ufh <- read_xlsx("pov_fh.xlsx")
  mfh <- read_xlsx("pov_mfh.xlsx")
  key_check <- function(x, yearly = TRUE) {
    fields <- if (yearly) c("domain", "year") else "domain"
    if (!is.data.frame(x) || !all(fields %in% names(x))) return(list(valid = FALSE, rows = 0L, duplicates = NA_integer_, missing_keys = NA_integer_))
    d <- trimws(as.character(x$domain))
    bad <- is.na(d) | !nzchar(d)
    if (yearly) bad <- bad | !is.finite(number(x$year))
    key <- if (yearly) paste(d, number(x$year), sep = "\r") else d
    duplicates <- sum(duplicated(key))
    list(valid = !any(bad) && duplicates == 0L, rows = nrow(x), duplicates = duplicates, missing_keys = sum(bad))
  }
  completeness <- list(UFH = key_check(ufh), MFH = key_check(mfh), matched_domain_years = 0L,
                       UFH_only_keys = NA_integer_, MFH_only_keys = NA_integer_,
                       mfh_domains_available = count(artifacts$n_domains),
                       mfh_domains_fitted = count(artifacts$n_domains_fitted),
                       mfh_excluded_domain_count = if (is.null(artifacts$excluded_domains)) NA_integer_ else length(artifacts$excluded_domains))
  levels <- list()
  if (completeness$UFH$valid && completeness$MFH$valid) {
    ufh$domain <- trimws(as.character(ufh$domain)); mfh$domain <- trimws(as.character(mfh$domain))
    ufh$year <- number(ufh$year); mfh$year <- number(mfh$year)
    ufh$.ufh_present <- TRUE; mfh$.mfh_present <- TRUE
    paired <- merge(ufh, mfh, by = c("domain", "year"), all = TRUE, suffixes = c("_ufh", "_mfh"))
    completeness$UFH_only_keys <- sum(is.na(paired$.mfh_present))
    completeness$MFH_only_keys <- sum(is.na(paired$.ufh_present))
    completeness$matched_domain_years <- sum(!is.na(paired$.ufh_present) & !is.na(paired$.mfh_present))
    model <- fit$selected_mfh_model
    if (model == "not_recorded") {
      candidates <- intersect(c("MFH1", "MFH2", "MFH3"), sub("^rate_", "", grep("^rate_MFH[123]$", names(mfh), value = TRUE)))
      if (length(candidates) == 1L) model <- candidates
    }
    scopes <- list(unbenchmarked = c("FH", "FH_MSE", "FH_CV", paste0("rate_", model), paste0("mse_", model), paste0("cv_", model)))
    if (identical(final_benchmark$UFH, "enabled") && identical(final_benchmark$MFH, "enabled"))
      scopes$benchmarked <- c("FH_Bench", "FH_Bench_MSE", "FH_Bench_CV", "rate_Bench", "mse_Bench", "cv_Bench")
    for (scope in names(scopes)) for (year in sort(unique(paired$year))) {
      cols <- scopes[[scope]]
      if (!all(cols %in% names(paired))) next
      z <- paired[paired$year == year, cols, drop = FALSE]
      z[] <- lapply(z, number)
      valid <- is.finite(z[[1]]) & is.finite(z[[4]]) & is.finite(z[[2]]) & z[[2]] >= 0 & is.finite(z[[5]]) & z[[5]] >= 0
      cv_valid <- valid & z[[1]] != 0 & z[[4]] != 0 & is.finite(z[[3]]) & z[[3]] >= 0 & is.finite(z[[6]]) & z[[6]] >= 0
      ratio_valid <- valid & z[[2]] > 0
      levels[[length(levels) + 1L]] <- data.frame(year = year, benchmark_scope = scope,
        union_domains = nrow(z), paired_finite_estimate_MSE = sum(valid), excluded_pairs = sum(!valid),
        mean_UFH_MSE = finite_mean(z[[2]][valid]), mean_MFH_MSE = finite_mean(z[[5]][valid]),
        mean_UFH_RMSE = finite_mean(sqrt(z[[2]][valid])), mean_MFH_RMSE = finite_mean(sqrt(z[[5]][valid])),
        paired_valid_CV = sum(cv_valid), mean_UFH_CV = finite_mean(z[[3]][cv_valid]), mean_MFH_CV = finite_mean(z[[6]][cv_valid]),
        positive_UFH_MSE_denominator_pairs = sum(ratio_valid),
        mean_paired_MFH_to_UFH_MSE_ratio = finite_mean(z[[5]][ratio_valid] / z[[2]][ratio_valid]))
    }
  }
  changes <- list()
  change_completeness <- list()
  sig <- read_xlsx("statistical_significance_comparison.xlsx")
  if (is.data.frame(sig) && all(c("method", "domain", "diff", "mse", "lb", "ub") %in% names(sig))) {
    for (scope in c("unbenchmarked", "benchmarked")) {
      if (scope == "benchmarked" && !all(unlist(final_benchmark) == "enabled")) next
      suffix <- if (scope == "benchmarked") " Benchmarked" else ""
      a <- sig[sig$method == paste0("FH", suffix), , drop = FALSE]
      b <- sig[sig$method == paste0("MFH", suffix), , drop = FALSE]
      change_completeness[[scope]] <- list(UFH = key_check(a, FALSE), MFH = key_check(b, FALSE))
      if (!key_check(a, FALSE)$valid || !key_check(b, FALSE)$valid || !nrow(a) || !nrow(b)) next
      status <- function(x, fallback) {
        out <- if ("inference_status" %in% names(x)) as.character(x$inference_status) else rep(fallback, nrow(x))
        out[is.na(out) | !out %in% c("regular", "ok", "period_independence", "boundary_sensitive", "unavailable")] <- "not_recorded"
        if ("joint_moment_status" %in% names(x)) out[grepl("invalid|unavailable", x$joint_moment_status)] <- "unavailable"
        out
      }
      a$.status <- status(a, "period_independence"); b$.status <- status(b, fit$mfh_inference)
      if (fit$mfh_inference == "unavailable") b$.status[] <- "unavailable"
      if (fit$mfh_inference == "boundary_sensitive") b$.status[b$.status != "unavailable"] <- "boundary_sensitive"
      a$domain <- trimws(as.character(a$domain)); b$domain <- trimws(as.character(b$domain))
      z <- merge(a, b, by = "domain", suffixes = c("_ufh", "_mfh"))
      valid <- is.finite(number(z$diff_ufh)) & is.finite(number(z$diff_mfh)) &
        is.finite(number(z$mse_ufh)) & number(z$mse_ufh) >= 0 & is.finite(number(z$mse_mfh)) & number(z$mse_mfh) >= 0 &
        z$.status_ufh != "unavailable" & z$.status_mfh != "unavailable"
      width_a <- number(z$ub_ufh) - number(z$lb_ufh); width_b <- number(z$ub_mfh) - number(z$lb_mfh)
      width_valid <- valid & is.finite(width_a) & width_a >= 0 & is.finite(width_b) & width_b >= 0
      changes[[length(changes) + 1L]] <- data.frame(benchmark_scope = scope, matched_domains = nrow(z),
        UFH_available_domains = nrow(a), MFH_available_domains = nrow(b),
        union_domains = length(union(a$domain, b$domain)),
        UFH_only_domains = length(setdiff(a$domain, b$domain)), MFH_only_domains = length(setdiff(b$domain, a$domain)),
        paired_finite_change_MSE = sum(valid), excluded_pairs = sum(!valid),
        boundary_sensitive_pairs = sum(z$.status_mfh == "boundary_sensitive"),
        unknown_status_pairs = sum(z$.status_mfh == "not_recorded" | z$.status_ufh == "not_recorded"),
        mean_UFH_change_MSE = finite_mean(number(z$mse_ufh)[valid]), mean_MFH_change_MSE = finite_mean(number(z$mse_mfh)[valid]),
        paired_finite_interval_widths = sum(width_valid), mean_UFH_interval_width = finite_mean(width_a[width_valid]),
        mean_MFH_interval_width = finite_mean(width_b[width_valid]))
    }
  }
  # Diagnostic exports may contain formulas, free text, paths, or domain rows.
  # Only these numeric summaries and canonical labels enter the payload.
  diagnostic_summary <- function(x, method_col = "method", component = FALSE) {
    if (!is.data.frame(x) || !method_col %in% names(x)) return(data.frame())
    method <- as.character(x[[method_col]])
    method <- ifelse(method %in% c("FH", "UFH"), "UFH", ifelse(method %in% c("MFH", "MFH1", "MFH2", "MFH3"), "MFH", "unknown"))
    keep <- method != "unknown"
    out <- data.frame(method = method[keep])
    for (col in intersect(c("year", "n", "n_domains", "n_predictors", "residual_sd", "random_effect_variance", "W", "p_value", "qq_correlation"), names(x))) {
      value <- number(x[[col]][keep]); value[!is.finite(value)] <- NA_real_; out[[col]] <- value
    }
    if (component && "component" %in% names(x)) out$component <- ifelse(x$component[keep] %in% c("Residual", "Random effect"), x$component[keep], "other")
    out
  }
  bootstrap <- read_csv("mfh_mcpe_validation.csv")
  if (is.data.frame(bootstrap) && "model" %in% names(bootstrap)) bootstrap <- bootstrap[bootstrap$model == fit$selected_mfh_model, , drop = FALSE]
  boot <- list()
  for (col in c("target_replicates", "successful_replicates", "failed_refits", "attempts", "near_pd_adjustments", "covariance_boundary_count", "covariance_boundary_fraction", "median_relative_mse_mcse", "median_relative_mcpe_mcse"))
    boot[[col]] <- if (is.data.frame(bootstrap) && col %in% names(bootstrap) && nrow(bootstrap) == 1L) count(bootstrap[[col]]) else NA_real_
  levels <- if (length(levels)) do.call(rbind, levels) else data.frame()
  changes <- if (length(changes)) do.call(rbind, changes) else data.frame()
  list(evidence_version = "ufh-mfh-advice-v1", units = units, fit = fit, final_benchmarking = final_benchmark,
       completeness = completeness, change_completeness = change_completeness,
       paired_level_precision = levels, paired_change_precision = changes,
       UFH_fit_diagnostics = diagnostic_summary(read_csv("ufh_model_diagnostics.csv")),
       MFH_fit_diagnostics = diagnostic_summary(read_csv("mfh_model_diagnostics.csv")),
       normality_diagnostics = diagnostic_summary(read_csv("normality_diagnostics.csv"), component = TRUE),
       MFH_bootstrap_diagnostics = boot,
       evidence_status = if (nrow(levels) && any(levels$paired_finite_estimate_MSE > 0)) "comparative_summaries_available" else "insufficient_usable_evidence")
}

build_comparison_ai_recommendation_prompt <- function(evidence, language = "en", indicator_type = "poverty") {
  paste(
    "Write an advisory UFH-versus-MFH recommendation in exactly three short paragraphs.",
    "Use only the aggregate evidence below. Choose UFH, MFH, no clear preference, or insufficient usable evidence; do not force a winner.",
    "First address annual level estimation; then address changes within this same two-year fit/window/data vintage; finish with the qualifications and human checks needed before use.",
    "A preference may differ between levels and changes. The intended publication objective is not recorded: make any recommendation conditional on the objective rather than inventing it.",
    "UFH fits years separately while borrowing across areas. Its reported change uncertainty assumes period independence, which overlapping samples may invalidate.",
    "MFH can borrow temporal information and account for cross-period prediction-error covariance only under adequate model/design assumptions. Its joint change MSE does not apply to frozen annual estimates from separate fits or data vintages.",
    "Use matched finite pairs and their coverage/exclusion counts; compare like benchmark scopes and the same estimand/scale. If final benchmark statuses differ, unbenchmarked comparisons do not establish which final published estimator is preferable.",
    "Respect the supplied units: CV values are dimensionless ratios, not percentages; multiply by 100 only if explicitly expressing them as percent. Poverty interval widths are proportion differences (multiply by 100 for percentage points); welfare change widths are already percent changes. MSE units are squared.",
    "Lower estimated MSE/CV, narrower intervals, closer agreement with noisy Direct estimates, or more significant areas do not alone establish a superior or valid method. Do not rank methods using significance counts.",
    "Boundary-sensitive results are provisional and can understate uncertainty. Failed/unavailable/unknown convergence or inference, invalid joint moments, incomplete data, and missing diagnostics must be stated; unknown is not a pass.",
    "UFH companion diagnostics and finite estimates/MSE do not establish convergence or coverage; an explicit UFH convergence record is not supplied here.",
    "Bootstrap failure/boundary/repair counts and Monte Carlo errors are numerical diagnostics, not coverage certification. More draws alone do not cure model inadequacy or boundary undercoverage.",
    "Treat normality tests and Q-Q summaries as descriptive. Do not infer a plot you have not seen. Do not compare AIC/BIC across differently transformed or annual versus joint likelihoods; OLS companion R-squared is not SAE model validation.",
    "An unusable candidate does not validate the other by elimination. If evidence is insufficient, say so and identify the missing checks without inventing numbers or recommending a default winner.",
    "This is advice for analyst review, not automatic model selection, an official statistical approval, or a change to any numeric estimate.",
    if (identical(indicator_type, "mean_welfare")) "Levels are arithmetic mean welfare; change metrics come from the common reporting-scale comparison export." else "Levels are poverty indices; change metrics come from the common reporting-scale comparison export.",
    paste0("Write entirely in ", comparison_ai_language_label(language), "; use plain paragraphs and no heading."),
    "Aggregate evidence (null means not recorded/usable, not zero):",
    jsonlite::toJSON(evidence, auto_unbox = TRUE, dataframe = "rows", na = "null", null = "null", digits = 8), sep = "\n\n")
}
