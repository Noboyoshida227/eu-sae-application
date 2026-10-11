# Read-only-in-operation, base-R checks for the shared MFH bootstrap contract.
# Run from the repository root: Rscript --vanilla tests/test_mfh_bootstrap_methodology.R
source("R/mfh_bootstrap_helpers.R")
source("scripts/pbmcpe_with_existing_dispatch.R")
source("scripts/bench_regional_mfh.R")
checks <- 0L
ok <- function(value, message) {
  checks <<- checks + 1L
  if (!isTRUE(value)) stop("FAILED: ", message, call. = FALSE)
  cat("ok -", message, "\n")
}
errors <- function(expr) inherits(tryCatch(force(expr), error = identity), "error")

offset_value <- 2
formulas <- list(y1 ~ 1, y2 ~ 0 + x + offset(offset_value))
new <- sae_mfh_bootstrap_formulas(formulas, c("B1", "B2"))
ok(identical(new[[1]][[3]], formulas[[1]][[3]]) &&
     identical(new[[2]][[3]], formulas[[2]][[3]]) &&
     identical(environment(new[[2]]), environment(formulas[[2]])),
   "bootstrap formulas preserve intercept-only, no-intercept, offsets, and environment")

dat <- data.frame(domain = letters[1:4], y1 = log(c(10, 12, 15, 18)),
                  y2 = log(c(11, 13, 16, 20)), v1 = .04, v2 = .09,
                  v12 = c(.02, .08, -.07, .01))
vardir <- c("v1", "v2", "v12")
prepared <- sae_mfh_prepare_sampling_covariance(dat, vardir, 2)
ok(sum(prepared$diagnostics$repaired) == 2L &&
     identical(prepared$data$v1, dat$v1) && identical(prepared$data$v2, dat$v2),
   "invalid sampling correlations are repaired while variances are preserved")
ok(all(vapply(seq_len(4), function(d) min(eigen(prepared$Sigma[, , d], symmetric = TRUE)$values) >= -1e-12, logical(1))),
   "all prepared domain sampling matrices are positive semidefinite")
ok(errors(sae_mfh_prepare_sampling_covariance(dat, vardir, 2, repair = FALSE)),
   "bootstrap refuses to silently repair covariance after the original fit")
dat <- prepared$data
ok(!any(sae_mfh_prepare_sampling_covariance(dat, vardir, 2, repair = FALSE)$diagnostics$repaired),
   "repaired fitting data pass strict bootstrap validation unchanged")
bad <- dat
bad$v1[1] <- NA_real_
ok(errors(sae_mfh_prepare_sampling_covariance(bad, vardir, 2)), "non-finite sampling variances are rejected")

f <- list(y1 ~ 1, y2 ~ 1)
beta <- c(log(14), log(16))
make_model <- function(type, zero = FALSE) {
  refvar <- if (type == "MFH2") .06 else c(.06, .08)
  if (zero) refvar[] <- 0
  list(eblup = matrix(rep(beta, each = nrow(dat)), nrow(dat), 2,
                       dimnames = list(NULL, c("y1", "y2"))),
       fit = list(convergence = TRUE, refvar = refvar,
                  rho = if (type == "MFH1") NULL else .35,
                  estcoef = matrix(beta, ncol = 1)))
}
fit <- make_model("MFH2")
G <- .06 / (1 - .35^2) * matrix(c(1, .35, .35, 1), 2)
expected <- t(vapply(seq_len(nrow(dat)), function(d) {
  S <- prepared$Sigma[, , d]
  exp(beta + diag(G - G %*% solve(G + S, G)) / 2)
}, numeric(2)))
actual <- sae_mfh_estimate_matrix(fit, "MFH2", dat, vardir, "log", TRUE)
ok(max(abs(actual - expected)) < 1e-12,
   "log estimates equal the independent Gaussian conditional-expectation formula")
ok(max(abs(sae_mfh_estimate_matrix(fit, "MFH2", dat, vardir, "log", FALSE) - exp(fit$eblup))) < 1e-12,
   "bias-correction off gives exactly exp(eta)")

for (type in c("MFH1", "MFH2", "MFH3")) {
  template <- make_model(type)
  seen <- 0L
  refit <- function(formula, vardir, data, MAXITER = NULL) {
    seen <<- seen + 1L
    stopifnot(all(vapply(formula, function(z) identical(z[[3]], quote(1)), logical(1))))
    stopifnot(identical(as.matrix(data[, vardir]), as.matrix(dat[, vardir])))
    stopifnot(identical(MAXITER, 17L))
    template
  }
  result <- pbmcpe_with_existing(type, f, vardir, "domain", template,
                                  nB = 40, data = dat, seed = 100L,
                                  refit_fn = refit, MAXITER = 17L,
                                  fit_validator = function(...) TRUE)
  ok(result$n_success == 40L && seen == 40L,
     paste(type, "intercept-only refits receive the exact prepared covariance and controls"))
  ok(all(vapply(seq_len(nrow(dat)), function(d) {
    min(eigen(result$error_second_moment[, , d], symmetric = TRUE)$values) >= -1e-12
  }, logical(1))), paste(type, "joint bootstrap moments form positive-semidefinite matrices"))
  difference_mse <- result$mse[, 1] + result$mse[, 2] - 2 * result$mcpe[, 1]
  ok(all(difference_mse >= -1e-12), paste(type, "same-draw change variance is nonnegative"))
}

zero_fit <- make_model("MFH2", zero = TRUE)
zero <- sae_mfh_bootstrap("MFH2", f, vardir, "domain", zero_fit,
                           nB = 10, data = dat, back_transform = "log",
                           refit_fn = function(...) zero_fit,
                           fit_validator = function(...) TRUE)
ok(all(zero$mse == 0) && all(zero$mcpe == 0) && zero$output_scale == "original",
   "a legitimate zero random-effect covariance remains bootstrapable")
ok(zero$inference_status == "boundary_sensitive" &&
     zero$covariance_boundary_count == 10L && zero$covariance_boundary_fraction == 1,
   "zero covariance preserves estimates while explicitly marking boundary-sensitive inference")

for (type in c("MFH1", "MFH2", "MFH3")) {
  interior <- make_model(type)
  small <- interior
  small$fit$refvar[] <- .Machine$double.eps
  ok(!sae_mfh_covariance_boundary(small, type)$boundary,
     paste(type, "positive variances are not classified as zero by an empirical threshold"))
  endpoint <- interior
  endpoint$fit$refvar[1] <- 0
  ok(sae_mfh_covariance_boundary(endpoint, type)$variance_zero,
     paste(type, "a single zero variance parameter is a covariance boundary"))
  if (type != "MFH1") {
    endpoint <- interior
    endpoint$fit$rho <- -(1 - 1e-6)
    ok(sae_mfh_covariance_boundary(endpoint, type)$correlation_limit,
       paste(type, "negative as well as positive numerical correlation limits are detected"))
  }
  # The first attempted draw is on a boundary but has non-finite predictions.
  # Among four accepted draws, two have zero variance, one only high rho,
  # and one is interior. Rejected draws must not enter the numerator.
  boundary_calls <- 0L
  refit_boundary <- function(...) {
    boundary_calls <<- boundary_calls + 1L
    candidate <- interior
    if (boundary_calls %in% c(1L, 2L, 3L)) candidate$fit$refvar[1] <- 0
    if (boundary_calls == 1L) candidate$eblup[1, 1] <- Inf
    if (boundary_calls == 4L && type != "MFH1") candidate$fit$rho <- 1 - 1e-6
    candidate
  }
  counted <- suppressWarnings(sae_mfh_bootstrap(type, f, vardir, "domain", interior,
    nB = 4, data = dat, refit_fn = refit_boundary, fit_validator = function(...) TRUE))
  expected_boundaries <- if (type == "MFH1") 2L else 3L
  ok(counted$fails == 1L && counted$n_success == 4L &&
       counted$covariance_boundary_count == expected_boundaries &&
       counted$covariance_boundary_fraction == expected_boundaries / 4 &&
       counted$variance_zero_count == 2L &&
       counted$correlation_limit_count == as.integer(type != "MFH1") &&
       counted$inference_status == "regular",
     paste(type, "boundary fractions count only accepted draws and do not relabel an interior original fit"))
}

calls <- 0L
reject_once <- function(...) {
  calls <<- calls + 1L
  result <- fit
  if (calls == 1L) result$eblup[1, 1] <- Inf
  result
}
finite <- suppressWarnings(sae_mfh_bootstrap("MFH2", f, vardir, "domain", fit,
                               nB = 5, data = dat, refit_fn = reject_once,
                               fit_validator = function(...) TRUE))
ok(finite$fails == 1L && finite$n_success == 5L && all(is.finite(finite$mse)),
   "a converged but non-finite draw cannot contaminate the moments")
exhausted <- suppressWarnings(sae_mfh_bootstrap("MFH2", f, vardir, "domain", fit,
                                 nB = 3, max_attempts = 3, data = dat,
                                 refit_fn = function(...) stop("failed"),
                                 fit_validator = function(...) TRUE))
ok(is.null(exhausted), "insufficient successful draws return unavailable uncertainty")

target <- matrix(c(20, 25), 1, 2, dimnames = list("all", c("y1", "y2")))
direct <- as.matrix(dat[, c("y1", "y2")])
rownames(direct) <- NULL
bench <- bench_regional_mfh(fit$eblup, domain_vec = dat$domain,
  region_vec = rep("all", nrow(dat)), Nd_vec = 1:4,
  direct_mat = direct, regional_benchmark_mat = target,
  model_obj = fit, model_type = "MFH2", formula = f, vardir = vardir,
  data = dat, MSE = TRUE, nB = 30, back_transform = "log",
  refit_fn = function(...) fit, fit_validator = function(...) TRUE)
ok(max(abs(apply(bench$eblup_bench, 2, weighted.mean, w = 1:4) - target[1, ])) < 1e-12,
   "final log-model benchmarks match uploaded currency targets")
ok(bench$output_scale == "original" && all(is.finite(bench$mse_bench)),
   "benchmark uncertainty is computed on the final currency scale")

# Zero G, equal fitted means, and one area: final internal benchmark equals
# exp(observed log mean) exactly. Its MSE against exp(beta) is known analytically.
one <- data.frame(domain = "a", y = log(10), v = .04)
one_fit <- list(eblup = matrix(log(10), 1, 1, dimnames = list(NULL, "y")),
                fit = list(convergence = TRUE, refvar = 0,
                           estcoef = matrix(log(10), 1, 1)))
oracle <- bench_regional_mfh(one_fit$eblup, domain_vec = "a", region_vec = "all",
  Nd_vec = 1, direct_mat = matrix(log(10), 1, 1), model_obj = one_fit,
  model_type = "MFH1", formula = list(y ~ 1), vardir = "v", data = one,
  MSE = TRUE, nB = 1500, seed = 842L, back_transform = "log",
  refit_fn = function(...) one_fit, fit_validator = function(...) TRUE)
oracle_mse <- 100 * (exp(2 * .04) - 2 * exp(.04 / 2) + 1)
ok(abs(oracle$mse_bench[1, 1] - oracle_mse) < 5 * oracle$mse_mcse[1, 1],
   "full log-scale benchmark bootstrap matches analytic lognormal MSE")
cat("Passed", checks, "MFH bootstrap methodology checks.\n")
