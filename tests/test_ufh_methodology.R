# Source from the repository root. These checks use synthetic data only and
# exercise the installed production emdi package; they write no output files.
local({
  verify <- if (exists("check", mode = "function", inherits = TRUE)) {
    get("check", mode = "function", inherits = TRUE)
  } else function(ok, label) {
    if (!isTRUE(ok)) stop(label, call. = FALSE)
    cat("PASS -", label, "\n")
  }
  if (!requireNamespace("emdi", quietly = TRUE)) {
    stop("UFH methodology tests require the production emdi package.")
  }
  source("scripts/ufh_functions.R", local = TRUE)
  set.seed(42)
  d <- data.frame(Domain = as.character(seq_len(24)),
                  x = seq(-1, 1, length.out = 24))
  d$y <- exp(4 + .3 * d$x + stats::rnorm(24, sd = .3))
  d$v <- (.15 * d$y)^2
  d$n_eff <- rep(30, 24)
  corrected <- suppressWarnings(sae_ufh_fit(
    y ~ x, "v", d, transformation = "log", backtransformation = "bc_sm"))
  reference <- suppressWarnings(emdi::fh(
    y ~ x, "v", d, domains = "Domain", method = "ml",
    transformation = "log", backtransformation = "bc_sm", MSE = TRUE,
    interval = corrected$sae_variance_interval, B = c(0, 0)))
  verify(isTRUE(all.equal(corrected$ind$FH, reference$ind$FH, tolerance = 1e-12)) &&
           isTRUE(all.equal(corrected$MSE$FH, reference$MSE$FH, tolerance = 1e-12)),
         "UFH log correction and analytical MSE equal native emdi Slud-Maiti")
  verify(isTRUE(all.equal(as.numeric(corrected$framework$direct), log(d$y))) &&
           isTRUE(all.equal(as.numeric(corrected$framework$vardir), d$v / d$y^2)),
         "UFH log model uses log arithmetic direct means and delta sampling variances")
  naive <- suppressWarnings(sae_ufh_fit(
    y ~ x, "v", d, transformation = "log", backtransformation = "naive",
    B = 24L, seed = 17L))
  log_data <- transform(d, y = log(y), v = v / y^2)
  log_reference <- suppressWarnings(emdi::fh(
    y ~ x, "v", log_data, domains = "Domain", method = "ml", MSE = FALSE,
    interval = naive$sae_variance_interval, B = c(0, 0)))
  verify(isTRUE(all.equal(naive$ind$FH, exp(log_reference$ind$FH))) &&
           all(is.finite(naive$MSE$FH)) && all(naive$MSE$FH >= 0),
         "UFH naive inverse uses the same ML log model and original-scale bootstrap MSE")
  bad <- d
  bad$y[1] <- 0
  verify(inherits(try(sae_ufh_fit(y ~ x, "v", bad, transformation = "log",
                                backtransformation = "bc_sm"), silent = TRUE), "try-error"),
         "UFH log fit rejects nonpositive area arithmetic means")

  boundary <- sae_ufh_backtransform(c(-.4, .2, 2), .1, rep(.02, 3),
                                     rep(TRUE, 3), "arcsin", "naive")
  verify(isTRUE(all.equal(boundary, c(0, sin(.2)^2, 1))),
         "UFH bootstrap uses the point estimator's arcsine boundary clamp")
  expected_bc <- getFromNamespace("arcsin_point", "emdi")(
    list(M = 3, obs_dom = rep(TRUE, 3)), .1,
    list(eblup_data = data.frame(FH = c(.1, .5, 1.5)), gamma = rep(.1 / .12, 3)), "bc")
  observed_bc <- sae_ufh_backtransform(c(.1, .5, 1.5), .1, rep(.02, 3),
                                       rep(TRUE, 3), "arcsin", "bc")
  verify(isTRUE(all.equal(observed_bc, expected_bc)),
         "UFH arcsine correction follows the installed package point estimator")
  pd <- transform(d, y = seq(0, 1, length.out = 24), v = .005)
  pd$v[c(1, 24)] <- 0
  for (back in c("naive", "bc")) {
    pf <- suppressWarnings(sae_ufh_fit(y ~ x, "v", pd,
      transformation = "arcsin", backtransformation = back, B = 24L, seed = 19L))
    verify(all(is.finite(pf$ind$FH)) && all(is.finite(pf$MSE$FH)) &&
             all(pf$MSE$FH >= 0) && identical(pf$MSE$Direct[c(1, 24)], c(0, 0)),
           paste("UFH arcsine", back, "handles zero/one directs without changing direct variances"))
  }

  identity_data <- transform(d, y = 30 + 4 * x + sin(seq_len(24)), v = 4)
  identity_fit <- suppressWarnings(sae_ufh_fit(y ~ x, "v", identity_data))
  single_groups <- data.frame(domain = d$Domain, region = d$Domain,
                              Nd = seq_len(24) * 100,
                              direct_povrate = identity_data$y)
  B <- 24L
  seed <- 214L
  survey_boot <- sae_ufh_bootstrap(identity_fit, single_groups,
                                   target_source = "survey", B = B, seed = seed)
  fixed_boot <- sae_ufh_bootstrap(identity_fit, single_groups,
                                  target_source = "fixed", B = B, seed = seed)
  # In a one-domain group a survey-target benchmark equals the replicate
  # direct estimator exactly, so its error is the sampled error e*, independently
  # of any FH prediction or ratio implementation. Fixed targets instead equal y.
  set.seed(seed)
  expected_survey <- expected_fixed <- matrix(0, 24, B)
  xb <- as.numeric(stats::model.matrix(y ~ x, identity_data) %*%
                     identity_fit$model$coefficients$coefficients)
  for (b in seq_len(B)) {
    truth <- xb + stats::rnorm(24, sd = sqrt(identity_fit$model$variance))
    error <- stats::rnorm(24, sd = 2)
    expected_survey[, b] <- error^2
    expected_fixed[, b] <- (identity_data$y - truth)^2
  }
  verify(isTRUE(all.equal(survey_boot$mse_bench, rowMeans(expected_survey), tolerance = 1e-10)),
         "UFH survey benchmark targets are recomputed from the same replicate survey errors")
  verify(isTRUE(all.equal(fixed_boot$mse_bench, rowMeans(expected_fixed), tolerance = 1e-10)),
         "UFH uploaded benchmark targets stay fixed in the bootstrap")
  verify(isTRUE(all.equal(survey_boot$mse_bench_mcse,
                          apply(expected_survey, 1L, stats::sd) / sqrt(B), tolerance = 1e-10)) &&
           isTRUE(all.equal(fixed_boot$mse_bench_mcse,
                            apply(expected_fixed, 1L, stats::sd) / sqrt(B), tolerance = 1e-10)),
         "UFH benchmark Monte Carlo precision matches independently simulated squared errors")
  no_area_variance <- identity_fit
  no_area_variance$model$variance <- 0
  no_area_variance$model$random_effects[] <- 0
  no_area_variance$model$real_residuals[] <- 0
  zero_boot <- sae_ufh_bootstrap(no_area_variance, B = 24L, seed = 20L)
  verify(all(is.finite(zero_boot$mse)) && zero_boot$diagnostics$successful == 24L,
         "UFH bootstrap supports zero random-effect and empirical residual variance")
  repeat_boot <- sae_ufh_bootstrap(identity_fit, B = 24L, seed = 20L)
  changed_seed <- sae_ufh_bootstrap(identity_fit, B = 24L, seed = 21L)
  verify(identical(repeat_boot$mse, sae_ufh_bootstrap(identity_fit, B = 24L, seed = 20L)$mse) &&
           !identical(repeat_boot$mse, changed_seed$mse),
         "UFH bootstrap obeys the selected seed reproducibly")
  broken <- identity_fit
  broken$model$coefficients$coefficients[] <- NA_real_
  failure <- suppressWarnings(try(sae_ufh_bootstrap(broken, B = 4L), silent = TRUE))
  verify(inherits(failure, "try-error") && grepl("finite replicates", as.character(failure)),
         "UFH bootstrap fails explicitly when insufficient finite replicates succeed")

  groups <- data.frame(domain = d$Domain, region = rep(c("a", "b"), each = 12),
                       Nd = seq_len(24) * 100, direct_povrate = d$y)
  bench <- suppressWarnings(bench_regional(corrected, groups, MSE = TRUE, B = 24L, seed = 22L))
  group_means <- vapply(split(seq_len(24), groups$region), function(rows) {
    weighted.mean(bench$ind$FH_Bench[rows], groups$Nd[rows]) -
      weighted.mean(d$y[rows], groups$Nd[rows])
  }, numeric(1))
  verify(max(abs(group_means)) < 1e-10 && all(is.finite(bench$MSE$FH_Bench)),
         "UFH log benchmarks reconcile in currency units with final-estimator bootstrap MSE")

  # Exercise the production year function without sourcing the top-level
  # pipeline (which loads user data and writes reports).
  suppressPackageStartupMessages({
    library(dplyr)
    library(data.table)
    library(emdi)
  })
  source("R/pipeline_helpers.R", local = TRUE)
  source("R/variance_policy.R", local = TRUE)
  year_code <- parse("scripts/01_ufh.R", encoding = "UTF-8")
  wanted <- c("run_fh_year", "make_sae_design", ".safe_cv", ".safe_cv_from_mse")
  for (expr in year_code) {
    if (is.call(expr) && identical(expr[[1]], as.name("<-")) &&
        is.symbol(expr[[2]]) && as.character(expr[[2]]) %in% wanted) eval(expr)
  }
  indicator_type <- "mean_welfare"
  log_transform <- TRUE
  ufh_bias_correction <- TRUE
  fgt_alpha <- 0L
  analysis_seed <- 50L
  use_strata <- FALSE
  survey_input <- data.frame(domain = rep(d$Domain, each = 3), year = 2020L,
                              psu = seq_len(72), population_weight = 1,
                              welfare = rep(d$y / 4, each = 3) * rep(c(-1, 0, 13), 24))
  rhs <- data.frame(domain = d$Domain, year = 2020L, x = d$x)
  invisible(capture.output(year_result <- suppressWarnings(run_fh_year(
    2020L, survey_input, rhs, NULL, c(2020L, 2021L), NULL,
    transformation = "no", formula_override = direct_povrate ~ x,
    var_choice = "direct"))))
  matched <- match(d$Domain, as.character(year_result$pov_fh$domain))
  verify(isTRUE(all.equal(year_result$pov_fh$Direct[matched], d$y, tolerance = 1e-12)) &&
           isTRUE(all.equal(as.numeric(year_result$fh_model$framework$direct),
                            log(year_result$fh_model$ind$Direct), tolerance = 1e-12)),
         "UFH production log path aggregates all welfare first, including zero/negative records")

  source("R/validation_checks.R", local = TRUE)
  source("R/indicator_helpers.R", local = TRUE)
  readiness_survey <- data.frame(
    domain = rep(letters[1:4], each = 4), year = 2020L,
    welfare = rep(c(1, 2, 7, 20), each = 4) * rep(c(-1, 0, 13, NA_real_), 4),
    weight = rep(c(1, 2, 3, 1), 4), hh_size = 2, psu = seq_len(16))
  readiness_aux <- data.frame(domain = letters[1:4], year = 2020L, x = c(1, 4, 2, 8))
  readiness <- assess_data_readiness(readiness_survey, readiness_aux, save_to = NULL,
                                     indicator_type = "mean_welfare", log_transform = TRUE)
  arithmetic <- vapply(split(readiness_survey, readiness_survey$domain), function(rows) {
    weighted.mean(rows$welfare, rows$weight * rows$hh_size, na.rm = TRUE)
  }, numeric(1))
  national <- weighted.mean(readiness_survey$welfare,
                             readiness_survey$weight * readiness_survey$hh_size, na.rm = TRUE)
  verify(isTRUE(all.equal(readiness$domain_poverty$poverty_rate, unname(arithmetic))) &&
           identical(readiness$domain_poverty$n_obs, rep(3L, 4)) &&
           readiness$national_poverty$n_households == 12L &&
           readiness$national_poverty$national_rate == round(national, 6) &&
           !any(grepl("ERROR|leaves them out", readiness$messages)),
         "Log readiness displays arithmetic Direct means and counts zero/negative welfare")
  pooled <- readiness$aux_summary$year == "All years"
  verify(readiness$aux_summary$cor_poverty[pooled] ==
           round(stats::cor(readiness_aux$x, log(arithmetic)), 4) &&
           grepl("log of area arithmetic mean", attr(readiness$aux_summary, "cor_target_label"),
                 ignore.case = TRUE),
         "Log readiness correlations transform area arithmetic means after aggregation")
  nonpositive <- readiness_survey
  nonpositive$welfare[nonpositive$domain == "a"] <- 0
  nonpositive$welfare[nonpositive$domain == "b"] <- -1
  invalid_readiness <- assess_data_readiness(nonpositive, readiness_aux, save_to = NULL,
                                             indicator_type = "mean_welfare", log_transform = TRUE)
  verify(any(grepl("Test 0e: ERROR.*2 area-year", invalid_readiness$messages)) &&
           identical(invalid_readiness$domain_poverty$poverty_rate[1:2], c(0, -1)),
         "Log readiness blocks nonpositive area means without changing displayed Direct values")
  verify(identical(build_target_column(readiness_survey, "mean_welfare", log_transform = TRUE),
                   readiness_survey$welfare),
         "Shared target helper retains individual welfare values before log-area estimation")
})
