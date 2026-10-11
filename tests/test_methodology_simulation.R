# Independent numerical and model-based assurance checks for the QER repairs.
# No files are written. Run from the repository root, for example:
# Rscript tests/test_methodology_simulation.R --library=/path/to/R/library
# Rscript tests/test_methodology_simulation.R --coverage --outer=100 --bootstrap=100
#
# The default run checks exact known-parameter Gaussian/lognormal identities
# and exercises the installed MFH fit/bootstrap implementations. --coverage
# adds an outer simulation with parameter re-estimation. Its printed Monte
# Carlo results are evidence, not a certificate or a pass/fail coverage gate.
# It does not simulate complex survey designs, variable selection, or GVF
# estimation. Those require additional, application-specific validation.

args <- commandArgs(trailingOnly = TRUE)
option <- function(name, default) {
  hits <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (length(hits)) sub(paste0("^--", name, "="), "", tail(hits, 1L)) else default
}
library_path <- option("library", "")
if (nzchar(library_path)) .libPaths(c(library_path, .libPaths()))
outer_reps <- as.integer(option("outer", "20"))
bootstrap_reps <- as.integer(option("bootstrap", "20"))
oracle_reps <- as.integer(option("oracle", "30000"))
stopifnot(outer_reps >= 2L, bootstrap_reps >= 2L, oracle_reps >= 1000L)
if (!file.exists("R/mfh_bootstrap_helpers.R")) {
  stop("Run this script from the repository root.")
}
source("R/mfh_bootstrap_helpers.R")
failures <- character()
check <- function(ok, label) {
  cat(if (isTRUE(ok)) "PASS" else "FAIL", "-", label, "\n")
  if (!isTRUE(ok)) failures <<- c(failures, label)
}
mc_mean_se <- function(x) stats::sd(x) / sqrt(length(x))

# These 2-period covariance matrices are written independently from the
# production recurrence. For MFH3, u1=rho*u0+a1 and u2=rho*u1+a2.
rho <- 0.35
innovation <- c(0.30, 0.45)
G_by_model <- list(
  MFH1 = diag(innovation),
  MFH2 = 0.25 / (1 - rho^2) * matrix(c(1, rho, rho, 1), 2L),
  MFH3 = matrix(c(rho^2 + innovation[1L],
                 rho * (rho^2 + innovation[1L]),
                 rho * (rho^2 + innovation[1L]),
                 rho^2 * (rho^2 + innovation[1L]) + innovation[2L]), 2L)
)
R_sampling <- matrix(c(0.09, 0.025, 0.025, 0.12), 2L)
vardir <- c("v1", "v2", "c12")
model_refvar <- function(type) if (type == "MFH2") 0.25 else innovation
oracle_results <- list()
for (type in names(G_by_model)) {
  set.seed(41801L + match(type, names(G_by_model)))
  G <- G_by_model[[type]]
  n <- oracle_reps
  means <- matrix(rep(c(2, 2.1), each = n), n, 2L)
  latent <- means + matrix(rnorm(2L * n), n) %*% chol(G)
  observed <- latent + matrix(rnorm(2L * n), n) %*% chol(R_sampling)
  # Independent oracle uses precision addition, rather than the production
  # G-G(G+R)^-1G expression. With known beta the posterior is exactly normal.
  C <- solve(solve(G) + solve(R_sampling))
  posterior_mean <- (means %*% solve(G) + observed %*% solve(R_sampling)) %*% C
  fake_fit <- list(eblup = posterior_mean,
                   fit = list(refvar = model_refvar(type), rho = rho))
  dat <- data.frame(v1 = rep(R_sampling[1L, 1L], n),
                    v2 = R_sampling[2L, 2L], c12 = R_sampling[1L, 2L])
  point <- sae_mfh_estimate_matrix(fake_fit, type, dat, vardir,
                                    back_transform = "log", bias_correction = TRUE)
  oracle_point <- exp(sweep(posterior_mean, 2L, diag(C) / 2, "+"))
  check(max(abs(point / oracle_point - 1)) < 1e-12,
        paste(type, "log predictor equals the independent conditional lognormal mean"))
  naive <- sae_mfh_estimate_matrix(fake_fit, type, dat, vardir,
                                    back_transform = "log", bias_correction = FALSE)
  check(isTRUE(all.equal(naive, exp(posterior_mean))),
        paste(type, "uncorrected log predictor is exp of the fitted log area mean"))
  linear_error <- posterior_mean - latent
  change_error <- linear_error[, 2L] - linear_error[, 1L]
  change_var <- sum(diag(C)) - 2 * C[1L, 2L]
  gaussian_coverage <- mean(abs(change_error) <= qnorm(0.975) * sqrt(change_var))
  original_error <- point - exp(latent)
  conditional_var <- sweep(point^2, 2L, expm1(diag(C)), "*")
  conditional_cross <- point[, 1L] * point[, 2L] * expm1(C[1L, 2L])
  mse_gap <- original_error^2 - conditional_var
  cross_gap <- original_error[, 1L] * original_error[, 2L] - conditional_cross
  log_interval_coverage <- colMeans(abs(posterior_mean - latent) <=
    matrix(rep(qnorm(0.975) * sqrt(diag(C)), each = n), n, 2L))
  # Five Monte Carlo SEs protects against occasional random test failures;
  # these assess exact identities, not normal approximations on currency.
  check(all(abs(colMeans(original_error)) <
              5 * apply(original_error, 2L, mc_mean_se)),
        paste(type, "conditional-mean prediction is unbiased in the known-parameter experiment"))
  check(all(abs(colMeans(mse_gap)) < 5 * apply(mse_gap, 2L, mc_mean_se)) &&
          abs(mean(cross_gap)) < 5 * mc_mean_se(cross_gap),
        paste(type, "original-scale MSE and MCPE agree with exact lognormal moments"))
  check(abs(gaussian_coverage - 0.95) < 5 * sqrt(0.95 * 0.05 / n) &&
          all(abs(log_interval_coverage - 0.95) < 5 * sqrt(0.95 * 0.05 / n)),
        paste(type, "exact Gaussian change and transformed-normal intervals have 95% coverage"))
  oracle_results[[type]] <- data.frame(
    model = type, independent_draws = n, gaussian_change_coverage = gaussian_coverage,
    log_level_coverage_1 = log_interval_coverage[1L],
    log_level_coverage_2 = log_interval_coverage[2L],
    original_mse_ratio_1 = mean(original_error[, 1L]^2) / mean(conditional_var[, 1L]),
    original_mse_ratio_2 = mean(original_error[, 2L]^2) / mean(conditional_var[, 2L]))
}
cat("\nKnown-parameter oracle results (not fitted-model coverage):\n")
print(do.call(rbind, oracle_results), row.names = FALSE, digits = 5)

if (!requireNamespace("msae", quietly = TRUE)) {
  stop("Installed-package checks require msae; supply --library if needed. Oracle checks alone are insufficient.")
}
cat("\nRuntime: R ", as.character(getRversion()), "; msae ",
    as.character(packageVersion("msae")), "\n", sep = "")
source("R/msae_compat.R")
sae_install_msae_compat_functions()
source("R/mfh_convergence_check.R")
source("scripts/eblupMFH2_robust.R")
.eblupMFH2_patched <- eblupMFH2
eblupMFH2 <- eblupMFH2_robust

make_trial <- function(type, seed, intercept_only = FALSE, n = 60L) {
  set.seed(seed)
  x <- seq(-1, 1, length.out = n)
  means <- if (intercept_only) matrix(rep(c(2, 2.1), each = n), n, 2L) else
    cbind(2 + 0.3 * x, 2.1 + 0.4 * x)
  latent <- means + matrix(rnorm(2L * n), n) %*% chol(G_by_model[[type]])
  y <- latent + matrix(rnorm(2L * n), n) %*% chol(R_sampling)
  dat <- data.frame(id = seq_len(n), x = x, y1 = y[, 1L], y2 = y[, 2L],
                    v1 = R_sampling[1L, 1L], v2 = R_sampling[2L, 2L],
                    c12 = R_sampling[1L, 2L])
  formulas <- if (intercept_only) list(y1 ~ 1, y2 ~ 1) else list(y1 ~ x, y2 ~ x)
  fit <- tryCatch(suppressWarnings(get(paste0("eblup", type))(
    formula = formulas, vardir = vardir, data = dat, MAXITER = 300,
    PRECISION = 1e-5)), error = function(e) NULL)
  list(data = dat, formula = formulas, fit = fit, latent = latent)
}
usable <- function(trial, type) {
  if (is.null(trial$fit) || !isTRUE(trial$fit$fit$convergence)) return(FALSE)
  if (exists("sae_mfh_fit_usable", mode = "function")) {
    return(isTRUE(sae_mfh_fit_usable(trial$fit, type, trial$formula, vardir, trial$data)))
  }
  identical(sae_mfh_reml_endpoint(trial$fit, type, trial$formula,
                                  vardir, trial$data)$status, "ok")
}
bootstrap_trial <- function(trial, type, scale, seed, nB = bootstrap_reps) {
  suppressWarnings(sae_mfh_bootstrap(
    type, formula = trial$formula, vardir = vardir, domain_var = "id",
    existing_model = trial$fit, nB = nB, data = trial$data, seed = seed,
    back_transform = scale, bias_correction = TRUE,
    refit_fn = get(paste0("eblup", type)), MAXITER = 300, PRECISION = 1e-5))
}

for (type in names(G_by_model)) {
  # Deliberately intercept-only: this regresses the former formula failure.
  trial <- make_trial(type, 129L + match(type, names(G_by_model)), TRUE)
  good <- usable(trial, type)
  check(good, paste(type, "installed fit has a satisfactory REML endpoint"))
  if (!good) next
  for (scale in c("none", "log")) {
    boot <- bootstrap_trial(trial, type, scale, 17201L)
    ok <- !is.null(boot) && boot$n_success == bootstrap_reps &&
      all(is.finite(boot$mse)) && all(is.finite(boot$mcpe))
    check(ok, paste(type, scale, "intercept-only bootstrap completes with the installed package"))
    if (ok) {
      difference_mse <- rowSums(boot$mse) - 2 * boot$mcpe[, 1L]
      check(all(difference_mse >= -1e-10) &&
              all(boot$mcpe[, 1L]^2 <= boot$mse[, 1L] * boot$mse[, 2L] + 1e-10),
            paste(type, scale, "joint error moments obey covariance bounds"))
      cat(sprintf("  %s/%s: %d successful draws, %d rejected; mean MSE %.6g, %.6g\n",
                  type, scale, boot$n_success, boot$fails, mean(boot$mse[, 1L]), mean(boot$mse[, 2L])))
    }
  }
}

source("scripts/bench_regional_mfh.R")
benchmark_trial <- make_trial("MFH2", 129L + 2L, TRUE)
if (usable(benchmark_trial, "MFH2")) {
  regions <- rep(c("A", "B"), each = 30L)
  populations <- seq(100, 690, by = 10)
  direct <- as.matrix(benchmark_trial$data[, c("y1", "y2")])
  fixed_targets <- matrix(c(8, 9, 10, 11), 2L,
                          dimnames = list(c("A", "B"), c("y1", "y2")))
  for (fixed in c(FALSE, TRUE)) {
    benchmark <- suppressWarnings(bench_regional_mfh(
      eblup_mat = benchmark_trial$fit$eblup,
      domain_vec = benchmark_trial$data$id, region_vec = regions,
      Nd_vec = populations, direct_mat = direct,
      regional_benchmark_mat = if (fixed) fixed_targets else NULL,
      model_obj = benchmark_trial$fit, model_type = "MFH2",
      formula = benchmark_trial$formula, vardir = vardir,
      data = benchmark_trial$data, MSE = TRUE, nB = bootstrap_reps,
      seed = 19471L, back_transform = "log", bias_correction = TRUE,
      MAXITER = 300, PRECISION = 1e-5))
    target <- if (fixed) fixed_targets else sapply(seq_len(2L), function(tt) {
      vapply(c("A", "B"), function(group) {
        rows <- regions == group
        weighted.mean(exp(direct[rows, tt]), populations[rows])
      }, numeric(1L))
    })
    achieved <- sapply(seq_len(2L), function(tt) {
      vapply(c("A", "B"), function(group) {
        rows <- regions == group
        weighted.mean(benchmark$eblup_bench[rows, tt], populations[rows])
      }, numeric(1L))
    })
    check(max(abs(achieved - target)) < 1e-10 &&
            benchmark$n_success == bootstrap_reps &&
            all(is.finite(benchmark$mse_bench)),
          paste("MFH2 log benchmark reaches", if (fixed) "fixed" else "survey-derived",
                "currency targets and bootstraps the final estimator"))
  }
}

if ("--coverage" %in% args) {
  cat("\nFitted-model outer simulation: fixed design and known sampling covariance; no variable selection.\n")
  cat("Failures are reported, not replaced by additional outer samples. Coverage is conditional on available inference.\n")
  reports <- list()
  for (type in names(G_by_model)) for (scale in c("none", "log")) {
    results <- list()
    failed_fit <- failed_bootstrap <- rejected_draws <- 0L
    for (b in seq_len(outer_reps)) {
      trial <- make_trial(type, 52100L + 1000L * match(type, names(G_by_model)) + b)
      if (!usable(trial, type)) {
        failed_fit <- failed_fit + 1L
        next
      }
      boot <- tryCatch(bootstrap_trial(trial, type, scale, 63100L + b), error = function(e) NULL)
      if (is.null(boot)) {
        failed_bootstrap <- failed_bootstrap + 1L
        next
      }
      rejected_draws <- rejected_draws + boot$fails
      truth <- if (scale == "log") exp(trial$latent) else trial$latent
      error <- boot$eblup - truth
      delta_error <- error[, 2L] - error[, 1L]
      delta_mse <- pmax(rowSums(boot$mse) - 2 * boot$mcpe[, 1L], 0)
      ratio_coverage <- NA_real_
      if (scale == "log") {
        ratio_var <- boot$mse[, 1L] / boot$eblup[, 1L]^2 +
          boot$mse[, 2L] / boot$eblup[, 2L]^2 -
          2 * boot$mcpe[, 1L] / (boot$eblup[, 1L] * boot$eblup[, 2L])
        ratio_error <- log(boot$eblup[, 2L] / boot$eblup[, 1L]) -
          (trial$latent[, 2L] - trial$latent[, 1L])
        ratio_coverage <- mean(abs(ratio_error) <= qnorm(0.975) * sqrt(pmax(ratio_var, 0)))
      }
      results[[length(results) + 1L]] <- c(
        bias = mean(error), actual_mse = mean(error^2), estimated_mse = mean(boot$mse),
        actual_change_mse = mean(delta_error^2), estimated_change_mse = mean(delta_mse),
        level_coverage = mean(abs(error) <= qnorm(0.975) * sqrt(boot$mse)),
        change_coverage = mean(abs(delta_error) <= qnorm(0.975) * sqrt(delta_mse)),
        percentage_change_coverage = ratio_coverage)
    }
    if (length(results)) {
      values <- do.call(rbind, results)
      reports[[paste(type, scale)]] <- data.frame(
        model = type, scale = if (scale == "log") "original lognormal" else "Gaussian",
        outer_requested = outer_reps, usable_outer = nrow(values),
        failed_fit = failed_fit, failed_bootstrap = failed_bootstrap,
        rejected_bootstrap_draws = rejected_draws,
        bias = mean(values[, "bias"]),
        mse_ratio = mean(values[, "estimated_mse"]) / mean(values[, "actual_mse"]),
        change_mse_ratio = mean(values[, "estimated_change_mse"]) / mean(values[, "actual_change_mse"]),
        level_coverage = mean(values[, "level_coverage"]),
        level_coverage_mcse = mc_mean_se(values[, "level_coverage"]),
        change_coverage = mean(values[, "change_coverage"]),
        change_coverage_mcse = mc_mean_se(values[, "change_coverage"]),
        percentage_change_coverage = mean(values[, "percentage_change_coverage"]),
        percentage_change_coverage_mcse = mc_mean_se(values[, "percentage_change_coverage"]))
      cat("Completed ", type, "/", scale, ": ", nrow(values), "/", outer_reps,
          " usable outer samples.\n", sep = "")
    } else {
      check(FALSE, paste(type, scale, "outer simulation produces usable inference"))
    }
  }
  if (length(reports)) print(do.call(rbind, reports), row.names = FALSE, digits = 4)
  cat("Coverage Monte Carlo SEs use the independent outer samples, not domain counts.\n")
  cat("These results do not establish performance under estimated survey covariance, GVF, selection, or benchmarking.\n")
}
if (length(failures)) stop(paste("Methodology checks failed:", paste(failures, collapse = "; ")))
cat("\nAll requested deterministic/oracle and runtime checks passed. Empirical coverage remains scenario-specific.\n")
