# R3/R5 regression checks. Run from the package root with the locked R library
# available through standard R discovery or R_LIBS_USER. All fixtures are synthetic.
local({
  verify <- if (exists("check", mode = "function", inherits = TRUE)) {
    get("check", mode = "function", inherits = TRUE)
  } else function(ok, label) {
    if (!isTRUE(ok)) stop(label, call. = FALSE)
    cat("PASS -", label, "\n")
  }
  suppressPackageStartupMessages({
    library(dplyr)
    library(tidyr)
    library(data.table)
    library(survey)
  })
  source("scripts/ufh_functions.R", local = TRUE)
  source("scripts/population_helpers.R", local = TRUE)
  source("R/pipeline_helpers.R", local = TRUE)
  source("R/variance_policy.R", local = TRUE)
  wanted <- c("run_fh_year", "make_sae_design", ".safe_cv", ".safe_cv_from_mse",
              ".targets_from_optional_benchmark", "build_mse_decomposition")
  for (expr in parse("scripts/01_ufh.R", encoding = "UTF-8")) {
    if (is.call(expr) && identical(expr[[1]], as.name("<-")) &&
        is.symbol(expr[[2]]) && as.character(expr[[2]]) %in% wanted) eval(expr)
  }
  scratch <- tempfile("ufh_reporting_")
  dir.create(scratch)
  on.exit(unlink(scratch, recursive = TRUE), add = TRUE)
  # run_fh_year writes precision diagnostics when bootstrap is used. Redirect
  # that existing side effect into the fixture directory, never outputs/.
  write.csv <- function(x, file, ...) {
    utils::write.csv(x, file = file.path(scratch, basename(file)), ...)
  }
  indicator_type <- "poverty"
  fgt_alpha <- 0L
  log_transform <- FALSE
  use_strata <- FALSE
  ufh_bias_correction <- TRUE
  ufh_bootstrap_nB <- 8L
  analysis_seed <- 123L
  ufh_ic_criterion <- "BIC"
  price_factors <- setNames(c(1, 1), c("2019", "2020"))
  survey_input <- do.call(rbind, lapply(seq_len(24), function(i) {
    n <- 20 + 3 * i
    data.frame(domain = sprintf("D%02d", i), year = 2019L,
      psu = paste(i, seq_len(n), sep = "_"), weight = 1, hh_size = 1,
      population_weight = 1,
      welfare = ifelse(seq_len(n) <= ceiling(n * (.15 + .4 * i / 24)), 0, 2),
      povline = 1)
  }))
  rhs <- data.frame(domain = sprintf("D%02d", seq_len(24)), year = 2019L, x = seq_len(24))
  groups <- data.frame(domain = rhs$domain, region = rep(c("north", "south"), each = 12))
  original_fit <- sae_ufh_fit
  fitted_input <- NULL
  sae_ufh_fit <- function(...) {
    fitted_input <<- original_fit(...)
    fitted_input
  }
  run_case <- function(data = survey_input, auxiliaries = rhs, transform = "no",
                       choice = "sm_out", benchmark = FALSE, target_path = "") {
    result <- NULL
    survey_both <- rbind(data, transform(data, year = setdiff(c(2019L, 2020L), unique(data$year))))
    invisible(capture.output(result <- suppressWarnings(run_fh_year(
      unique(data$year), survey_both, auxiliaries, NULL, c(2019L, 2020L), groups,
      transformation = transform, formula_override = direct_povrate ~ x,
      var_choice = choice, do_benchmark = benchmark,
      benchmark_target_path = target_path))))
    outcome <- if (identical(indicator_type, "poverty")) {
      compute_fgt(data$welfare, data$povline, fgt_alpha)
    } else data$welfare
    raw_data <- transform(data, test_outcome = outcome)
    raw <- survey::svyby(~test_outcome, ~domain, make_sae_design(raw_data),
                         survey::svymean, na.rm = TRUE)
    rows <- match(as.character(result$pov_fh$domain), as.character(raw$domain))
    expected <- as.numeric(survey::SE(raw))^2
    verify(isTRUE(all.equal(result$pov_fh$Direct_MSE, expected[rows], tolerance = 1e-12)),
      paste("raw Direct variance retained:", indicator_type, fgt_alpha, transform, choice, benchmark))
    model_rows <- match(as.character(result$fh_model$MSE$Domain), as.character(raw$domain))
    verify(isTRUE(all.equal(result$fh_model$MSE$Direct, expected[model_rows], tolerance = 1e-12)) &&
      isTRUE(all.equal(result$fh_model$ind, fitted_input$ind)) &&
      isTRUE(all.equal(result$fh_model$framework, fitted_input$framework)),
      "raw-variance reporting preserves fitted point estimates and model framework")
    if (!benchmark) {
      verify(isTRUE(all.equal(result$fh_model$MSE$FH, fitted_input$MSE$FH)),
        "raw-variance repair preserves unbenchmarked model MSE")
    } else {
      bench_rows <- match(as.character(result$fh_bench$MSE$Domain), as.character(raw$domain))
      verify(isTRUE(all.equal(result$fh_bench$MSE$Direct, expected[bench_rows], tolerance = 1e-12)),
        "benchmarked model carries raw Direct variance")
    }
    verify(isTRUE(all.equal(result$pov_fh$Direct_CV,
      .safe_cv(sqrt(result$pov_fh$Direct_MSE), result$pov_fh$Direct), tolerance = 1e-12)),
      "UFH table Direct CV agrees with raw Direct MSE")
    result
  }

  reviewed <- run_case(choice = "sm_all")
  first <- match("D01", reviewed$variance_audit$domain)
  verify(abs(reviewed$variance_audit$direct_variance_raw[first] - .006250934) < 5e-10 &&
    abs(reviewed$variance_audit$working_variance[first] - .006750478) < 5e-10,
    "reviewed sm_all fixture reports 0.006250934 raw and 0.006750478 working variance")
  for (alpha in c(1L, 2L)) {
    fgt_alpha <- alpha
    fractional <- survey_input
    fractional$welfare[fractional$welfare == 0] <- .7
    run_case(data = fractional, choice = "sm_out", benchmark = alpha == 2L)
  }
  fgt_alpha <- 0L
  run_case(transform = "arcsin", choice = "sm_all")
  zero_data <- survey_input
  zero_data$welfare[zero_data$domain == "D01"] <- 2
  zero_direct <- run_case(data = zero_data, choice = "direct")
  zero_row <- match("D01", zero_direct$variance_audit$domain)
  verify(zero_direct$variance_audit$direct_variance_raw[zero_row] == 0 &&
    zero_direct$variance_audit$working_variance[zero_row] > 0 &&
    is.na(zero_direct$pov_fh$Direct_CV[match("D01", zero_direct$pov_fh$domain)]),
    "production direct-mode backfills zero model variance without changing zero raw variance or unavailable CV")
  indicator_type <- "mean_welfare"
  welfare_data <- survey_input
  welfare_data$welfare <- 30 + 2 * as.numeric(sub("D", "", welfare_data$domain)) +
    welfare_data$welfare * 3
  run_case(data = welfare_data, choice = "direct")
  log_transform <- TRUE
  log_case <- run_case(data = welfare_data, choice = "sm_all", benchmark = TRUE)
  log_diagnostic <- build_mse_decomposition(log_case)
  verify(all(log_diagnostic$target_source == "survey") &&
    all(log_diagnostic$B_r > 10), "log survey lambda uses arithmetic currency-scale targets")

  # Two years with fixed targets and price conversion. Targets are supplied
  # in current-price units and the production loader deflates before use.
  target_path <- file.path(scratch, "targets.csv")
  utils::write.csv(data.frame(region = c("north", "south"),
    `2019` = c(60, 100), `2020` = c(80, 120), check.names = FALSE), target_path, row.names = FALSE)
  price_factors <- setNames(c(.5, .8), c("2019", "2020"))
  for (year in c(2019L, 2020L)) {
    dated <- welfare_data
    dated$year <- year
    dated$welfare <- dated$welfare * price_factors[as.character(year)]
    dated_rhs <- rhs
    dated_rhs$year <- year
    fixed <- run_case(data = dated, auxiliaries = dated_rhs, choice = "sm_out",
                       benchmark = TRUE, target_path = target_path)
    factors <- fixed$fh_bench$sae_benchmark_factors
    targets <- if (year == 2019L) c(60, 100) * .5 else c(80, 120) * .8
    verify(isTRUE(all.equal(factors$B_r[match(c("north", "south"), factors$region)], targets)) &&
      all(build_mse_decomposition(fixed)$target_source == "fixed"),
      paste("fixed log benchmark diagnostics use applied price-adjusted targets", year))
  }

  # Boundary and missing raw variance cannot be replaced in reporting just
  # because a positive working variance is available for estimation.
  boundary_raw <- c(0, NA_real_, .000999, .001, .001001)
  restored_input <- list(MSE = data.frame(Domain = c("005", "003", "001", "004", "002", "999"),
    Direct = .5, FH = .2), framework = list(vardir = rep(.5, 6)))
  restored <- sae_ufh_restore_direct_variance(restored_input, data.frame(
    domain = sprintf("%03d", seq_along(boundary_raw)), direct_variance_raw = boundary_raw))
  verify(identical(restored$MSE$Direct, c(.001001, .000999, 0, .001, NA_real_, NA_real_)) &&
    identical(restored$framework, restored_input$framework) &&
    identical(restored$MSE$FH, restored_input$MSE$FH),
    "raw restoration matches zero-padded domain IDs and preserves zero/missing/unsampled variance")
  verify(identical(sae_sm_out_variance(boundary_raw, rep(.4, 5)), c(.4, .4, .4, .001, .001001)),
    "sm_out replaces strictly below 0.001, retaining the exact threshold")
  cv_object <- list(MSE = data.frame(Domain = c("a", "b", "c"), Direct = c(0, NA, 1), FH = 1),
    ind = data.frame(Domain = c("a", "b", "c"), Direct = c(0, 3, -2), FH = 2))
  class(cv_object) <- "fh"
  verify(identical(as.numeric(mse_emdi(cv_object, CV = TRUE)$ind_cv$Direct), c(NA_real_, NA_real_, .5)),
    "raw Direct CV stays unavailable for zero means/missing variances and nonnegative for negative means")

  make_diagnostic <- function(direct, fixed_target = NULL, groups = c("all", "all")) {
    meta <- sae_ufh_ratio_benchmark(c(1, 3), c(2, 4), groups, c(1, 1),
      fixed_target, return_diagnostics = TRUE)
    list(fh_dt = data.frame(domain = c("A", "B"), region = groups, Nd = 1, direct_povrate = direct),
      fh_bench = list(sae_benchmark_factors = meta$factors),
      pov_fh = data.frame(domain = c("A", "B"), Direct_MSE = .1, FH_MSE = .05, FH_Bench_MSE = .08))
  }
  external <- build_mse_decomposition(make_diagnostic(c(2, 4), c(all = 5)))
  logged <- build_mse_decomposition(make_diagnostic(log(c(2, 4))))
  verify(all(external$lambda_r == 2.5) && all(logged$lambda_r == 1.5),
    "reviewed diagnostic fixtures log 2.5 external and 1.5 survey-log factors")
  zero <- sae_ufh_ratio_benchmark(c(0, 0), c(0, 0), c("all", "all"), c(1, 1),
                                 return_diagnostics = TRUE)
  verify(identical(zero$estimate, c(0, 0)) && is.na(zero$factors$lambda_r) &&
    zero$factors$benchmark_operation == "zero_target_zero_mean",
    "zero/zero benchmarking records a zero result without inventing a ratio factor")
  disabled <- make_diagnostic(c(2, 4))
  disabled$fh_bench <- NULL
  verify(all(is.na(build_mse_decomposition(disabled)$lambda_r)),
    "disabled benchmarking reports no applied lambda")
})
