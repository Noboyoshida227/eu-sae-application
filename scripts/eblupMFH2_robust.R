#' Robust REML wrapper for eblupMFH2()
#'
#' msae's `eblupMFH2()` uses unconstrained Newton-Raphson to estimate the
#' random-effects variance components (sigma2_u, rho_u). Its stopping rule
#' may accept endpoints that are not restricted-likelihood maxima, including
#' positive-variance fits whose correlation updates repeatedly hit a bound.
#' A zero variance alone does not establish an optimization failure.
#'
#' This wrapper:
#'   1. Calls the original `eblupMFH2()` first (the AST-patched version
#'      that fixes the R 4.4 `&&` issue, but otherwise unchanged).
#'   2. Retains the original result when its convergence flag and independent
#'      REML endpoint checks pass, including valid zero-variance boundaries.
#'   3. Otherwise refits marginal variance >= 0 and -1 < rho < 1 using
#'      bounded optimization with exact REML gradients and multiple starts.
#'      After optimization and endpoint validation, the full fit
#'      object (eblup, MSE, randomEffect, fit$*) is reconstructed using
#'      the same plug-in formulas as msae's post-iteration block, so
#'      downstream code (`pbmcpe_*`, `compare_mfh`, benchmarking) sees an
#'      interchangeable structure.
#'
#'   4. If the refit fails or has an inferior restricted likelihood,
#'      the original fit is returned with attribute
#'      `.robust_refit_failed = TRUE` so callers can detect it.
#'
#' Parameter contract: same as `eblupMFH2()` plus an extra `.orig_fn`
#' argument that callers MUST pass (see the patch-msae chunk in
#' qmd/50-mfh_v2.qmd) to avoid infinite recursion when the global
#' `eblupMFH2` has been replaced by this wrapper.
#'
#' Result contract: same shape as `eblupMFH2()`, with the addition of an
#' attribute `.robust_refit_used = TRUE` on the result whenever the
#' optim-based refit was used (so downstream diagnostics can surface it).

# Local copy of msae's df2matR -- replicated rather than ::: so this module
# is namespace-safe and works regardless of which msae version is installed.
.df2matR_local <- function(var.df, r) {
  if (dim(var.df)[2] != sum(1:r))
    stop(".df2matR_local: ncol(var.df) does not match r")
  var.df <- as.data.frame(var.df)
  n <- nrow(var.df)
  R <- lapply(var.df, diag)
  R_1n <- matrix()
  for (i in 1:r) {
    R.row <- R[[i]]
    for (j in i:r) {
      if (i != j) R.row <- cbind(R.row, R[[sum((r - i):r) + j - r]])
    }
    if (i == 1) {
      R_1n <- R.row
    } else {
      tmp <- matrix(rep(0, n * n * (i - 1)), n, n * (i - 1))
      R.row <- cbind(tmp, R.row)
      R_1n <- rbind(R_1n, R.row)
    }
  }
  for (i in 1:(r * n)) {
    for (j in i:(r * n)) {
      if (R_1n[j, i] != R_1n[i, j]) R_1n[j, i] <- R_1n[i, j]
    }
  }
  R_1n
}

# Build Omega_AR (r x r), G (r x r), and GI (rn x rn) given (sigma2_u, rho).
.build_G_GI <- function(sigma2_u, rho, r, n, I_n) {
  Omega_AR <- matrix(0, r, r)
  for (i in 1:r) for (j in 1:r) {
    Omega_AR[i, j] <- rho^abs(i - j) / (1 - rho^2)
  }
  G <- sigma2_u * Omega_AR
  GI <- kronecker(G, I_n)
  list(Omega_AR = Omega_AR, G = G, GI = GI)
}

.safe_sym_inverse <- function(x, label) {
  x <- (x + t(x)) / 2
  # A matrix holding NA/NaN/Inf must never reach chol(). Whether chol()
  # signals an error for such input is platform- and LAPACK-dependent: where
  # it does not, it returns a non-finite factor, chol2inv() propagates the
  # non-finite values without complaint, and this function would report an
  # "available" inverse that silently turns every MSE term derived from it
  # into NaN - the exact outcome the unavailable path exists to prevent.
  # Rejecting non-finite input up front makes the result identical on every
  # platform and R version.
  if (!all(is.finite(x))) {
    warning(sprintf(
      "%s contained non-finite values; affected MSE terms are reported as unavailable.",
      label
    ), call. = FALSE)
    return(list(inverse = NULL, method = "unavailable",
                condition_number = Inf,
                condition_number_method = "exact_kappa",
                available = FALSE))
  }
  chol_x <- tryCatch(chol(x), error = function(e) NULL)
  if (!is.null(chol_x) && all(is.finite(chol_x))) {
    # For a symmetric positive-definite matrix x = R'R, the 2-norm
    # condition number of x is the square of the condition number of R.
    # kappa(..., exact = FALSE) uses a low-cost triangular-factor estimate;
    # squaring it preserves an actionable signal without repeating an exact
    # factorization of the large marginal-covariance matrix.
    chol_kappa <- tryCatch(kappa(chol_x, exact = FALSE),
                           error = function(e) NA_real_)
    condition_number <- if (is.finite(chol_kappa) && chol_kappa >= 0) {
      chol_kappa^2
    } else {
      NA_real_
    }
    if (!is.finite(condition_number)) condition_number <- Inf
    return(list(
      inverse = chol2inv(chol_x), method = "chol2inv",
      condition_number = condition_number,
      condition_number_method = "chol_factor_kappa_squared_estimate",
      available = TRUE
    ))
  }
  condition_number <- tryCatch(kappa(x, exact = TRUE), error = function(e) Inf)
  inverse <- if (requireNamespace("MASS", quietly = TRUE) && all(is.finite(x))) {
    tryCatch(MASS::ginv(x), error = function(e) NULL)
  } else {
    NULL
  }
  if (!is.null(inverse) && all(is.finite(inverse))) {
    warning(sprintf(
      "%s was not positive definite; using a Moore-Penrose generalized inverse (condition number: %s).",
      label, format(condition_number, scientific = TRUE)
    ), call. = FALSE)
    return(list(
      inverse = inverse, method = "MASS::ginv",
      condition_number = condition_number,
      condition_number_method = "exact_kappa",
      available = TRUE
    ))
  }
  warning(sprintf(
    "%s could not be inverted; affected MSE terms are reported as unavailable (condition number: %s).",
    label, format(condition_number, scientific = TRUE)
  ), call. = FALSE)
  list(inverse = NULL, method = "unavailable",
       condition_number = condition_number,
       condition_number_method = "exact_kappa",
       available = FALSE)
}

#' Construct the full fit object given converged (sigma2_u, rho_u).
#'
#' Mirrors msae::eblupMFH2()'s post-iteration block exactly, so the
#' returned list has the same shape (eblup, MSE, randomEffect, Rmatrix,
#' fit$method/convergence/iterations/estcoef/refvar/rho/informationFisher).
.eblupMFH2_finalize <- function(sigma2_u, rho_u, y.matrix, x.matrix, R,
                                r, n, y.var, convergence, iterations) {
  I_n <- diag(n)
  Id  <- diag(r)
  bg  <- .build_G_GI(sigma2_u, rho_u, r, n, I_n)
  Omega_AR <- bg$Omega_AR
  GI <- bg$GI
  v_inverse <- .safe_sym_inverse(GI + R, "MFH2 marginal covariance V")
  if (!isTRUE(v_inverse$available) || !identical(v_inverse$method, "chol2inv")) {
    stop("MFH2 finalization failed: marginal covariance V is not invertible.", call. = FALSE)
  }
  Omega <- v_inverse$inverse           # = V_inv
  Xto   <- t(Omega %*% x.matrix)
  xtvx_inverse <- .safe_sym_inverse(Xto %*% x.matrix, "MFH2 X'V^-1X")
  if (!isTRUE(xtvx_inverse$available) || !identical(xtvx_inverse$method, "chol2inv")) {
    stop("MFH2 finalization failed: X'V^-1X is not invertible.", call. = FALSE)
  }
  Qh    <- xtvx_inverse$inverse         # = (X'V_inv X)_inv
  P     <- Omega - t(Xto) %*% Qh %*% Xto

  # Use marginal variance and rho for derivatives: unlike innovation-variance
  # coordinates these remain well conditioned near |rho| = 1. The g3 quadratic
  # form is invariant to this smooth reparameterization in the interior.
  marginal_variance <- sigma2_u / (1 - rho_u^2)
  d.Omega <- list()
  correlation <- outer(seq_len(r), seq_len(r), function(i, j) rho_u^abs(i - j))
  d.Omega[[1]] <- kronecker(correlation, I_n)
  d.Omega[[2]] <- matrix(NA, r, r)
  for (i in 1:r) for (j in 1:r) {
    k <- abs(i - j)
    # Explicit k=0 avoids 0 * 0^(-1) when rho is exactly zero.
    d.Omega[[2]][i, j] <- if (k == 0L) 0 else marginal_variance * k * rho_u^(k - 1L)
  }
  d.Omega[[2]] <- kronecker(d.Omega[[2]], I_n)

  # Fisher information (expected) at converged (sigma2_u, rho_u)
  iF <- matrix(unlist(lapply(d.Omega, function(x)
    lapply(d.Omega, function(y) 0.5 * sum(diag(P %*% x %*% P %*% y))))), 2)
  dimnames(iF) <- list(c("marginal_variance", "rho"), c("marginal_variance", "rho"))
  fisher_inverse <- .safe_sym_inverse(iF, "MFH2 Fisher information")
  FI <- fisher_inverse$inverse

  # Coefficients
  beta <- Qh %*% Xto %*% y.matrix
  res  <- y.matrix - x.matrix %*% beta
  eblup <- x.matrix %*% beta + GI %*% Omega %*% res

  eblup.df <- data.frame(matrix(eblup, n, r))
  names(eblup.df) <- y.var

  se.b  <- sqrt(diag(Qh))
  t.val <- beta / se.b
  pv    <- 2 * pnorm(abs(t.val), lower.tail = FALSE)
  coef  <- cbind(beta, se.b, t.val, pv)
  colnames(coef) <- c("beta", "std.error", "t.statistics", "p.value")
  # msae::eblupMFH2() obtains Qh with solve(), which keeps the design-matrix
  # column names, so its estcoef rows are labelled "(Intercept)", "x1", ...
  # chol2inv()/MASS::ginv() drop dimnames, so restore the labels explicitly:
  # 03_comparison.R reads rownames(estcoef) as the coefficient-table terms.
  .term_names <- colnames(x.matrix)
  if (!is.null(.term_names) && length(.term_names) == nrow(coef)) {
    rownames(coef) <- .term_names
  }

  # MSE: g1 + g2 + 2*g3
  d_proj <- kronecker(Id, I_n) - GI %*% Omega
  gg1 <- diag(GI %*% Omega %*% R)
  gg2 <- diag(d_proj %*% x.matrix %*% Qh %*% t(x.matrix) %*% t(d_proj))
  dg  <- lapply(d.Omega, function(x) x %*% Omega - GI %*% Omega %*% x %*% Omega)
  if (isTRUE(fisher_inverse$available) && all(is.finite(FI))) {
    g3  <- list()
    for (i in 1:2) for (j in 1:2) {
      g3[[(i - 1) * 2 + j]] <-
        FI[i, j] * (dg[[i]] %*% (GI + R) %*% t(dg[[j]]))
    }
    gg3 <- diag(Reduce("+", g3))
    g3_available <- TRUE
  } else {
    warning(
      "MFH2 g3 is unavailable because the Fisher information could not be inverted; MSE is returned as NA rather than understated as g1 + g2.",
      call. = FALSE
    )
    gg3 <- rep(NA_real_, length(gg1))
    g3_available <- FALSE
  }
  mse <- gg1 + gg2 + 2 * gg3

  mse.df <- data.frame(matrix(0, n, r))
  names(mse.df) <- y.var
  for (i in 1:r) mse.df[, i] <- mse[((i - 1) * n + 1):(i * n)]

  u.cap <- GI %*% Omega %*% res
  u.cap.df <- as.data.frame(matrix(u.cap, n, r))
  names(u.cap.df) <- y.var

  T.test <- if (isTRUE(g3_available) && is.finite(FI[2, 2]) && FI[2, 2] > 0) {
    rho_u / sqrt(FI[2, 2])
  } else NA_real_
  p.val  <- if (is.finite(T.test)) 2 * pnorm(abs(T.test), lower.tail = FALSE) else NA_real_
  rho.df <- data.frame(rho = rho_u,
                       T.test = signif(T.test, 5),
                       `p-value` = signif(p.val, 5),
                       check.names = FALSE)

  list(
    eblup        = eblup.df,
    MSE          = mse.df,
    randomEffect = u.cap.df,
    Rmatrix      = R,
    fit = list(
      method            = "REML (constrained marginal variance and AR1 correlation)",
      convergence       = convergence,
      iterations        = iterations,
      estcoef           = coef,
      refvar            = sigma2_u,
      rho               = rho.df,
      informationFisher = {
        jacobian <- matrix(c(1 / (1 - rho_u^2), 0,
                             2 * rho_u * sigma2_u / (1 - rho_u^2)^2, 1), 2, 2)
        reported <- t(jacobian) %*% iF %*% jacobian
        dimnames(reported) <- list(c("sigma2_u", "rho"), c("sigma2_u", "rho"))
        reported
      },
      informationFisher_working = iF,
      mse_method = "second_order_interior_approximation",
      variance_boundary = marginal_variance == 0 || abs(rho_u) >= 1 - 1.01e-6,
      numerical_diagnostics = list(
        marginal_covariance = v_inverse[c("method", "condition_number", "available")],
        fixed_effect_information = xtvx_inverse[c("method", "condition_number", "available")],
        fisher_information = fisher_inverse[c("method", "condition_number", "available")],
        g3_available = g3_available
      )
    )
  )
}

# Refit on a dimensionless marginal-variance scale with analytic REML score.
# The correlation bound is a numerical approximation of the stationary limit.
.eblupMFH2_optim_refit <- function(formula, vardir, data, initial_model = NULL) {
  if (!exists("sae_mfh_reml_evaluate", mode = "function")) {
    source(file.path("R", "mfh_convergence_check.R"))
  }
  r <- length(formula)
  if (r != 2L) stop("The validated robust MFH2 refit supports two periods.")
  design <- sae_mfh_design(formula, vardir, data)
  if (design$n < 3L) return(NULL)
  ols <- stats::lm.fit(design$X, design$y)
  base_var <- max(mean(diag(design$R)), mean(ols$residuals^2), .Machine$double.eps)
  rho_limit <- 1 - 1e-6
  last_par <- last_value <- NULL
  evaluate <- function(par) {
    if (identical(par, last_par)) return(last_value)
    q <- par[1] * base_var
    rho <- par[2]
    if (!all(is.finite(par)) || q < 0 || abs(rho) >= 1) {
      return(list(value = Inf, gradient = rep(NA_real_, 2)))
    }
    C <- matrix(c(1, rho, rho, 1), 2, 2)
    ans <- tryCatch(sae_mfh_reml_evaluate(design, q * C,
      list(C, q * matrix(c(0, 1, 1, 0), 2, 2))), error = function(e) NULL)
    out <- if (is.null(ans) || !is.finite(ans$loglik)) {
      list(value = Inf, gradient = rep(NA_real_, 2))
    } else list(value = -ans$loglik, gradient = -ans$score * c(base_var, 1))
    last_par <<- par
    last_value <<- out
    out
  }
  starts <- list(c(.05, .30), c(.20, 0), c(.50, .50), c(.01, .90),
                 c(1, -.30), c(1, -.90), c(1, rho_limit), c(1, -rho_limit))
  if (!is.null(initial_model)) {
    theta <- tryCatch(sae_mfh_theta(initial_model, "MFH2"), error = function(e) c(NA, NA))
    if (all(is.finite(theta)) && theta[1] >= 0 && abs(theta[2]) < 1) {
      starts <- c(list(c(theta[1] / (1 - theta[2]^2) / base_var,
                        max(-rho_limit, min(rho_limit, theta[2])))), starts)
    }
  }
  zero <- evaluate(c(0, 0))
  best <- if (is.finite(zero$value)) {
    list(par = c(0, 0), value = zero$value, convergence = 0L,
         counts = c("function" = 1L))
  } else NULL
  for (start in starts) {
    opt <- tryCatch(stats::optim(start, function(x) evaluate(x)$value,
      gr = function(x) evaluate(x)$gradient, method = "L-BFGS-B",
      lower = c(0, -rho_limit), upper = c(Inf, rho_limit),
      control = list(maxit = 500, factr = 1e4, pgtol = 1e-8)), error = function(e) NULL)
    if (is.null(opt) || opt$convergence != 0L || !is.finite(opt$value)) next
    if (is.null(best) || opt$value < best$value) best <- opt
  }
  if (is.null(best)) return(NULL)
  q <- best$par[1] * base_var
  rho <- if (q == 0) 0 else best$par[2]
  result <- .eblupMFH2_finalize(
    sigma2_u = q * (1 - rho^2), rho_u = rho,
    y.matrix = design$y, x.matrix = design$X, R = design$R,
    r = r, n = design$n,
    y.var = vapply(formula, function(f) as.character(f[[2]]), character(1)),
    convergence = TRUE, iterations = best$counts[["function"]])
  result$fit$optimization <- list(reml_loglik = -best$value,
                                  marginal_variance = q, rho_limit = rho_limit,
                                  starts = length(starts), exact_zero_candidate = TRUE)
  result
}

#' Public wrapper. Drop-in replacement for eblupMFH2().
#'
#' `.orig_fn` MUST be the underlying (non-wrapped) eblupMFH2() -- typically
#' the AST-patched copy stashed at `.eblupMFH2_patched` by the patch-msae
#' chunk. This is required because callers usually invoke `eblupMFH2(...)`
#' which has been globally replaced by this wrapper, so passing the
#' wrapper itself as `.orig_fn` would loop forever.
eblupMFH2_robust <- function(formula, vardir, MAXITER = 100, PRECISION = 1e-04,
                              data, .orig_fn = NULL) {
  if (!exists("sae_mfh_reml_endpoint", mode = "function")) {
    source(file.path("R", "mfh_convergence_check.R"))
  }
  if (is.null(.orig_fn)) {
    if (exists(".eblupMFH2_patched", envir = globalenv()) &&
        is.function(get(".eblupMFH2_patched", envir = globalenv()))) {
      .orig_fn <- get(".eblupMFH2_patched", envir = globalenv())
    } else {
      .orig_fn <- getFromNamespace("eblupMFH2", "msae")
    }
  }

  base_fit <- tryCatch(
    .orig_fn(formula = formula, vardir = vardir, MAXITER = MAXITER,
             PRECISION = PRECISION, data = data),
    error = function(e) NULL
  )

  if (!is.null(base_fit)) {
    attr(base_fit, ".reml_endpoint") <- sae_mfh_reml_endpoint(
      base_fit, "MFH2", formula, vardir, data)
    if (sae_mfh_fit_usable(base_fit, "MFH2", formula, vardir, data)) return(base_fit)
  }

  # Refit failed convergence/endpoint checks, including positive-variance fits.
  refit <- tryCatch(
    .eblupMFH2_optim_refit(formula = formula, vardir = vardir, data = data,
                           initial_model = base_fit),
    error = function(e) NULL
  )
  if (is.null(refit)) {
    if (!is.null(base_fit)) attr(base_fit, ".robust_refit_failed") <- TRUE
    return(base_fit)
  }
  attr(refit, ".robust_refit_used") <- TRUE
  attr(refit, ".reml_endpoint") <- sae_mfh_reml_endpoint(refit, "MFH2", formula, vardir, data)
  base_check <- if (is.null(base_fit)) NULL else attr(base_fit, ".reml_endpoint")
  refit_check <- attr(refit, ".reml_endpoint")
  if (!is.null(base_check) && is.finite(base_check$reml_loglik) &&
      is.finite(refit_check$reml_loglik) &&
      refit_check$reml_loglik < base_check$reml_loglik -
        1e-8 * max(1, abs(base_check$reml_loglik))) {
    attr(base_fit, ".robust_refit_failed") <- TRUE
    attr(base_fit, ".robust_refit_failure_reason") <- "The refit had an inferior restricted likelihood."
    return(base_fit)
  }
  if (!sae_mfh_fit_usable(refit, "MFH2", formula, vardir, data)) {
    attr(refit, ".robust_refit_failed") <- TRUE
    refit$fit$convergence <- FALSE
  }
  refit
}
