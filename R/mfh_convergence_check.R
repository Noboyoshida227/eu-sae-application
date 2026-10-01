# ============================================================
# mfh_convergence_check.R -- REML check at msae's end point
# ============================================================
#
# msae's eblupMFH1/2/3 estimate the variance parameters by Fisher scoring
# and stop when the relative change of the parameters is below PRECISION.
# That rule can stop at a point that is not a REML maximum: on the Spain
# example, eblupMFH2 reports convergence while its own REML score is far
# from zero, because the rho part of every late step is rejected (it would
# exceed 1) while the sigma2 part is kept (see the project note "MFH2 in
# msae: limits of the variance-parameter search").
#
# The package keeps msae's estimates (owner's decision, 30 Sep 2026) and
# checks them: at msae's reported parameters it evaluates the REML
# log-likelihood, the REML score s and the expected (Fisher) information I,
# with the same formulas msae uses, and the Newton decrement
#   lambda2 = s' I^-1 s,
# which is zero at a maximum. lambda2 / 2 approximates how much the REML
# log-likelihood could still rise. Parameters on a bound (a variance at 0,
# |rho| at 1) whose score points outwards are left out, so a maximum on the
# boundary passes.
#
# Model parameterisations (r = 2 years), as in msae 0.1.5:
#   MFH1: theta = (sigma2_1, sigma2_2);  G = diag(theta)
#   MFH2: theta = (sigma2, rho);         G = sigma2 / (1 - rho^2) * [rho^|i-j|]
#   MFH3: theta = (sigma2_1, sigma2_2, rho), G from msae's recursion with
#         Var(u_0) = 1: G11 = s1 + rho^2, G12 = rho s1 + rho^3,
#         G22 = s2 + rho^2 s1 + rho^4.
# msae reports its parameters rounded to 5 significant digits; the check is
# evaluated there, which changes lambda2 negligibly for a converged fit.

sae_mfh_G <- function(model, theta, r = 2L) {
  model <- toupper(model)
  if (identical(model, "MFH1")) {
    return(diag(theta[seq_len(r)], r, r))
  }
  if (identical(model, "MFH2")) {
    rho <- theta[2]
    return(theta[1] / (1 - rho^2) * outer(seq_len(r), seq_len(r),
                                          function(i, j) rho^abs(i - j)))
  }
  if (identical(model, "MFH3")) {
    s <- theta[seq_len(r)]
    rho <- theta[r + 1]
    G <- matrix(NA_real_, r, r)
    for (i in seq_len(r)) for (j in seq_len(r)) {
      if (i == j) {
        G[i, j] <- s[i]
        for (l in seq_len(i)) {
          G[i, j] <- G[i, j] + rho^(2 * l) * (if (l == i) 1 else s[i - l])
        }
      } else {
        k <- abs(i - j)
        G[i, j] <- s[k] * rho^k
        for (l in seq_len(k)) {
          G[i, j] <- G[i, j] + rho^(2 * l + k) * (if (l == k) 1 else s[k - l])
        }
      }
    }
    return(G)
  }
  stop("Unknown MFH model: ", model)
}

# Variance parameters reported by an msae (or robust-refit) fit.
sae_mfh_theta <- function(fit_obj, model) {
  model <- toupper(model)
  refvar <- suppressWarnings(as.numeric(unlist(fit_obj$fit$refvar)))
  rho <- fit_obj$fit$rho
  rho <- if (is.data.frame(rho) || is.list(rho)) rho[["rho"]] else rho
  rho <- suppressWarnings(as.numeric(unlist(rho))[1])
  theta <- switch(model,
    MFH1 = refvar[1:2],
    MFH2 = c(refvar[1], rho),
    MFH3 = c(refvar[1:2], rho),
    stop("Unknown MFH model: ", model)
  )
  names(theta) <- switch(model,
    MFH1 = c("sigma2_1", "sigma2_2"),
    MFH2 = c("sigma2", "rho"),
    MFH3 = c("sigma2_1", "sigma2_2", "rho")
  )
  theta
}

# Response vector, block-diagonal design and sampling covariance (r = 2),
# laid out as msae lays them out.
sae_mfh_design <- function(formula, vardir, data) {
  r <- length(formula)
  if (r != 2L || length(vardir) != 3L) {
    stop("The convergence check supports two periods (three vardir columns).")
  }
  frames <- lapply(formula, function(f) stats::model.frame(f, data, na.action = stats::na.fail))
  y <- unlist(lapply(frames, stats::model.response), use.names = FALSE)
  Xs <- lapply(seq_len(r), function(i) stats::model.matrix(formula[[i]], frames[[i]]))
  n <- nrow(Xs[[1]])
  X <- matrix(0, r * n, sum(vapply(Xs, ncol, integer(1))))
  col0 <- 0L
  for (i in seq_len(r)) {
    X[(i - 1) * n + seq_len(n), col0 + seq_len(ncol(Xs[[i]]))] <- Xs[[i]]
    col0 <- col0 + ncol(Xs[[i]])
  }
  v <- lapply(vardir, function(cn) as.numeric(data[[cn]]))
  R <- rbind(cbind(diag(v[[1]], n), diag(v[[3]], n)),
             cbind(diag(v[[3]], n), diag(v[[2]], n)))
  list(y = as.numeric(y), X = X, R = R, n = n, r = r)
}

sae_mfh_reml_endpoint <- function(fit_obj, model, formula, vardir, data,
                                  tol = 0.01) {
  model <- toupper(model)
  out <- list(model = model,
              msae_converged = isTRUE(fit_obj$fit$convergence),
              iterations = suppressWarnings(as.numeric(fit_obj$fit$iterations %||% NA)),
              robust_refit = isTRUE(attr(fit_obj, ".robust_refit_used")),
              theta = NULL, reml_loglik = NA_real_, score = NULL,
              newton_decrement = NA_real_, loglik_gain = NA_real_,
              proposed = NULL, free = NULL, status = NA_character_,
              message = NA_character_)
  res <- tryCatch({
    d <- sae_mfh_design(formula, vardir, data)
    theta <- sae_mfh_theta(fit_obj, model)
    if (any(!is.finite(theta))) stop("non-finite variance parameters")
    In <- diag(d$n)
    Gfun <- function(th) sae_mfh_G(model, th, d$r)
    V <- kronecker(Gfun(theta), In) + d$R
    Vc <- chol(V)
    Vi <- chol2inv(Vc)
    XtVi <- crossprod(d$X, Vi)
    M <- XtVi %*% d$X
    P <- Vi - t(XtVi) %*% solve(M, XtVi)
    Py <- as.numeric(P %*% d$y)
    ll <- -0.5 * (2 * sum(log(diag(Vc))) +
                    as.numeric(determinant(M, logarithm = TRUE)$modulus) +
                    sum(d$y * Py))
    k <- length(theta)
    PV <- vector("list", k)
    s <- numeric(k)
    for (i in seq_len(k)) {
      h <- 1e-6 * max(abs(theta[i]), 1e-4)
      tp <- tm <- theta
      tp[i] <- theta[i] + h
      tm[i] <- theta[i] - h
      dG <- (Gfun(tp) - Gfun(tm)) / (2 * h)
      Vd <- kronecker(dG, In)
      PV[[i]] <- P %*% Vd
      s[i] <- -0.5 * sum(diag(PV[[i]])) + 0.5 * sum(Py * as.numeric(Vd %*% Py))
    }
    info <- matrix(0, k, k)
    for (i in seq_len(k)) for (j in i:k) {
      info[i, j] <- info[j, i] <- 0.5 * sum(PV[[i]] * t(PV[[j]]))
    }
    names(s) <- names(theta)
    # A bound is active when the parameter sits on it and the score points
    # outwards; such parameters are left out of the decrement.
    is_rho <- grepl("^rho", names(theta))
    at_lower <- !is_rho & theta <= 1e-10 & s < 0
    at_rho_bound <- is_rho & ((theta >= 1 - 1e-6 & s > 0) | (theta <= -1 + 1e-6 & s < 0))
    free <- !(at_lower | at_rho_bound)
    nd <- if (any(free)) {
      step <- tryCatch(solve(info[free, free, drop = FALSE], s[free]),
                       error = function(e) qr.solve(info[free, free, drop = FALSE], s[free]))
      sum(s[free] * step)
    } else 0
    step_full <- tryCatch(solve(info, s), error = function(e) rep(NA_real_, k))
    list(theta = theta, reml_loglik = ll, score = s, newton_decrement = nd,
         proposed = theta + step_full, free = free)
  }, error = function(e) e)

  if (inherits(res, "error")) {
    out$status <- "check_failed"
    out$message <- paste("The REML check could not be computed:", conditionMessage(res))
    return(out)
  }
  out[names(res)] <- res
  out$loglik_gain <- res$newton_decrement / 2
  stationary <- is.finite(res$newton_decrement) && res$newton_decrement <= tol
  rho_beyond <- "rho" %in% names(res$theta) &&
    is.finite(res$proposed[["rho"]]) && abs(res$proposed[["rho"]]) >= 1
  out$status <- if (!out$msae_converged && !out$robust_refit) {
    "not_converged"
  } else if (stationary) {
    "ok"
  } else {
    "not_at_maximum"
  }
  out$message <- switch(out$status,
    ok = "The REML score at msae's end point is zero within tolerance: a REML maximum (or a maximum on a bound).",
    not_converged = sprintf(paste(
      "msae did not converge (%s iterations); its results are those of the last iterate.",
      "Newton decrement at that point: %.3g."), format(out$iterations), res$newton_decrement),
    not_at_maximum = paste0(
      sprintf(paste(
        "msae reports convergence, but its end point is not a REML maximum: Newton decrement %.3g,",
        "so the REML log-likelihood could rise by about %.2g."), res$newton_decrement, out$loglik_gain),
      if (rho_beyond) " A Fisher-scoring step from this point puts rho outside (-1, 1), so the maximum is probably on the boundary |rho| = 1 (domain effects that do not change between the two years)." else "")
  )
  out
}

# One row per checked model for the CSV table and the report.
sae_mfh_check_row <- function(chk, selected_model) {
  th <- chk$theta %||% numeric(0)
  sc <- chk$score %||% numeric(0)
  pick <- function(x, nm) if (nm %in% names(x)) unname(x[[nm]]) else NA_real_
  data.frame(
    model = chk$model,
    selected = identical(chk$model, selected_model),
    msae_converged = chk$msae_converged,
    iterations = chk$iterations,
    robust_refit = chk$robust_refit,
    sigma2 = pick(th, "sigma2"),
    sigma2_1 = pick(th, "sigma2_1"),
    sigma2_2 = pick(th, "sigma2_2"),
    rho = pick(th, "rho"),
    reml_loglik = chk$reml_loglik,
    score = if (length(sc)) paste(sprintf("%s=%.4g", names(sc), sc), collapse = "; ") else NA_character_,
    newton_decrement = chk$newton_decrement,
    loglik_gain_approx = chk$loglik_gain,
    status = chk$status,
    message = chk$message,
    stringsAsFactors = FALSE
  )
}
