# Numerical validation of REML endpoints and the constrained MFH2 refit.
# Rscript --vanilla tests/test_mfh_convergence.R --library=/path/to/R/library
args <- commandArgs(trailingOnly = TRUE)
lib <- sub("^--library=", "", args[grepl("^--library=", args)])
if (length(lib)) .libPaths(c(lib[1], .libPaths()))
# Keep helpers and the temporary optimizer replacement in the same scope when
# the aggregate runner sources this test into a fresh environment.
source("R/msae_compat.R", local = TRUE)
source("R/mfh_convergence_check.R", local = TRUE)
source("scripts/eblupMFH2_robust.R", local = TRUE)
checks <- 0L
ok <- function(value, message) {
  checks <<- checks + 1L
  if (!isTRUE(value)) stop("FAILED: ", message, call. = FALSE)
  cat("ok -", message, "\n")
}
set.seed(19)
dat <- data.frame(y1 = rnorm(20), y2 = rnorm(20), x = rnorm(20),
                  v1 = .2, v2 = .3, v12 = .03)
f <- list(y1 ~ x, y2 ~ 1)
v <- c("v1", "v2", "v12")
d <- sae_mfh_design(f, v, dat)
G <- matrix(c(.4, .1, .1, .4), 2)
derivatives <- list(diag(2), matrix(c(0, 1, 1, 0), 2))
block <- sae_mfh_reml_evaluate(d, G, derivatives)
V <- kronecker(G, diag(d$n)) + d$R
Vi <- solve(V)
M <- crossprod(d$X, Vi %*% d$X)
P <- Vi - Vi %*% d$X %*% solve(M, t(d$X) %*% Vi)
Py <- P %*% d$y
D <- lapply(derivatives, kronecker, diag(d$n))
score <- vapply(D, function(a) .5 * (sum(Py * (a %*% Py)) - sum(diag(P %*% a))), numeric(1))
information <- outer(1:2, 1:2, Vectorize(function(i, j) .5 * sum(diag(P %*% D[[i]] %*% P %*% D[[j]]))))
ll <- -.5 * (as.numeric(determinant(V, TRUE)$modulus) +
              as.numeric(determinant(M, TRUE)$modulus) + sum(d$y * Py))
ok(abs(block$loglik - ll) < 1e-10 && max(abs(block$score - score)) < 1e-10 &&
     max(abs(block$information - information)) < 1e-10,
   "block REML likelihood, score and Fisher information equal independent dense algebra")

# Construct a stationary minimum for the first variance component. A score-only
# check accepts this root, whereas the observed-curvature check must reject it.
root_data <- data.frame(y1 = c(0, sqrt(132), 0), y2 = rep(sqrt(2), 3),
                        v1 = c(.1, 10, 10), v2 = 1, v12 = 0)
root_fit <- list(eblup = matrix(0, 3, 2),
                 fit = list(convergence = TRUE, iterations = 1, refvar = c(1, 1)))
root_check <- sae_mfh_reml_endpoint(root_fit, "MFH1", list(y1 ~ 0, y2 ~ 0), v, root_data)
ok(root_check$status == "invalid_curvature" && root_check$newton_decrement < 1e-15,
   "a stationary likelihood minimum cannot pass as a REML maximum")

# rho = 0 must not evaluate 0 * rho^(-1) in the MSE derivatives.
rho0 <- .eblupMFH2_finalize(.4, 0, d$y, d$X, d$R, 2, d$n,
                            c("y1", "y2"), TRUE, 1)
ok(all(is.finite(as.matrix(rho0$MSE))) && rho0$fit$numerical_diagnostics$g3_available,
   "exactly zero correlation has finite Fisher information and MSE")
residual <- sae_mfh_standardized_residuals(rho0, "MFH2", f, v, dat)
V0 <- kronecker(diag(.4, 2), diag(d$n)) + d$R
Vi0 <- solve(V0)
P0 <- Vi0 - Vi0 %*% d$X %*% solve(crossprod(d$X, Vi0 %*% d$X), t(d$X) %*% Vi0)
variance0 <- matrix(diag(d$R %*% P0 %*% d$R), d$n, 2)
ok(max(abs(residual$variance - variance0)) < 1e-11 &&
     max(abs(residual$standardized - residual$raw / sqrt(variance0))) < 1e-11,
   "standardized residual variances equal diag(R P R), including fixed-effect estimation")

if (!requireNamespace("msae", quietly = TRUE)) {
  stop("Installed-package checks require msae; supply --library.", call. = FALSE)
}
original <- sae_patch_msae_function("eblupMFH2")
data("datasae2", package = "msae")
f2 <- list(Y1 ~ X1 + X2, Y2 ~ X1 + X2)
base <- original(f2, v, data = datasae2)
fit <- eblupMFH2_robust(f2, v, data = datasae2, .orig_fn = original)
ok(sae_mfh_fit_usable(fit, "MFH2", f2, v, datasae2) &&
     !isTRUE(attr(fit, ".robust_refit_used")) && identical(base$eblup, fit$eblup),
   "the production msae interior fixture is retained unchanged when validated")
cached <- fit
cached$fit$convergence <- FALSE
ok(!sae_mfh_fit_usable(cached, "MFH2", f2, v, datasae2),
   "cached endpoint approval cannot override a false convergence flag")
shifted <- datasae2
shifted$Y1 <- shifted$Y1 + seq_len(nrow(shifted))
ok(!sae_mfh_fit_usable(fit, "MFH2", f2, v, shifted),
   "cached endpoint approval is invalidated when fitting data change")

flat <- data.frame(y1 = rep(2, 20), y2 = rep(3, 20), v1 = .04, v2 = .05, v12 = .01)
fi <- list(y1 ~ 1, y2 ~ 1)
zero <- suppressWarnings(eblupMFH2_robust(fi, v, data = flat,
                                         .orig_fn = function(...) stop("force refit")))
ok(zero$fit$refvar == 0 && sae_mfh_fit_usable(zero, "MFH2", fi, v, flat) &&
     all(as.matrix(zero$randomEffect) == 0),
   "a genuine zero-variance boundary is retained and passes all feasible directions")

u <- seq(-1, 1, length.out = 40)
for (direction in c(1, -1)) {
  high <- data.frame(y1 = 2 + u + .01 * sin(seq_along(u)),
                     y2 = 3 + direction * u + .01 * cos(seq_along(u)),
                     v1 = .02, v2 = .02, v12 = 0)
  high_fit <- eblupMFH2_robust(fi, v, data = high, .orig_fn = original)
  high_check <- attr(high_fit, ".reml_endpoint")
  ok(high_check$status == "ok" && sign(high_fit$fit$rho$rho) == direction &&
       abs(high_fit$fit$rho$rho) > .99 && high_fit$fit$variance_boundary,
     paste("the", direction, "high-correlation optimum passes the constrained KKT check"))
  cat("  high-correlation fixture:", direction, "rho", high_fit$fit$rho$rho,
      "REML", high_check$reml_loglik, "decrement", high_check$newton_decrement, "\n")
}

# A failed optimization may not replace a better original likelihood.
saved_optimizer <- .eblupMFH2_optim_refit
inferior <- fit
inferior$fit$convergence <- FALSE
original_bad <- base
original_bad$fit$convergence <- FALSE
.eblupMFH2_optim_refit <- function(...) {
  bad_design <- sae_mfh_design(f2, v, datasae2)
  .eblupMFH2_finalize(1e6, .1, bad_design$y, bad_design$X, bad_design$R,
                     2, bad_design$n, c("Y1", "Y2"), TRUE, 1)
}
kept <- tryCatch(eblupMFH2_robust(f2, v, data = datasae2,
                                  .orig_fn = function(...) original_bad),
                 finally = { .eblupMFH2_optim_refit <- saved_optimizer })
ok(isTRUE(attr(kept, ".robust_refit_failed")) && identical(kept$eblup, original_bad$eblup) &&
     !sae_mfh_fit_usable(kept, "MFH2", f2, v, datasae2),
   "an inferior refit is never substituted and the invalid original stays blocked")

# Existing Spanish artifacts contain the original fitting frame in the saved
# formula environment. Read only: no pipeline is sourced and nothing is saved.
artifact_path <- "outputs/data/mfh_artifacts.rds"
if (file.exists(artifact_path)) {
  artifact <- readRDS(artifact_path)
  env <- environment(artifact$formula[[1]])
  if (exists("domain_dt", env, inherits = TRUE)) {
    spain <- get("domain_dt", env, inherits = TRUE)
    spain_before <- sae_mfh_reml_endpoint(artifact$selected_model, "MFH2",
                                          artifact$formula, artifact$vardir_cols, spain)
    spain_fit <- eblupMFH2_robust(artifact$formula, artifact$vardir_cols,
                                  data = spain, .orig_fn = original)
    spain_after <- attr(spain_fit, ".reml_endpoint")
    ok(spain_after$status == "ok" &&
         spain_after$reml_loglik >= spain_before$reml_loglik - 1e-8,
       "the saved Spanish fitting frame yields a valid, non-inferior REML refit")
    cat("  Spain before/after REML:", spain_before$reml_loglik, spain_after$reml_loglik,
        "; rho:", artifact$selected_model$fit$rho$rho, spain_fit$fit$rho$rho,
        "; decrement:", spain_before$newton_decrement, spain_after$newton_decrement,
        "; largest estimate change:", max(abs(as.matrix(spain_fit$eblup) - as.matrix(artifact$selected_model$eblup))), "\n")
  }
}
cat("Passed", checks, "MFH convergence checks.\n")
