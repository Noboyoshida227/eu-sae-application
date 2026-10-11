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
# The package checks fitted parameters before inference and refits MFH2
# when msae stops at an unsatisfactory endpoint. It evaluates the REML
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

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x
}

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
  colnames(X) <- unlist(lapply(Xs, colnames), use.names = FALSE)
  v <- lapply(vardir, function(cn) as.numeric(data[[cn]]))
  R <- rbind(cbind(diag(v[[1]], n), diag(v[[3]], n)),
             cbind(diag(v[[3]], n), diag(v[[2]], n)))
  rows <- lapply(seq_len(n), function(i) i + (seq_len(r) - 1L) * n)
  list(y = as.numeric(y), X = X, R = R, n = n, r = r,
       X_blocks = lapply(rows, function(i) X[i, , drop = FALSE]),
       y_blocks = lapply(rows, function(i) as.numeric(y[i])),
       R_blocks = lapply(rows, function(i) R[i, i, drop = FALSE]))
}

# Exact REML block algebra. This is algebraically the dense P calculation,
# but only inverts the small period matrices and the fixed-effect information.
# It makes independent endpoint validation feasible in every bootstrap refit.
sae_mfh_reml_evaluate <- function(design, G, derivatives = NULL) {
  p <- ncol(design$X)
  W <- lapply(design$R_blocks, function(Rd) chol2inv(chol(G + Rd)))
  logdetV <- sum(vapply(design$R_blocks, function(Rd) {
    2 * sum(log(diag(chol(G + Rd))))
  }, numeric(1)))
  M <- matrix(0, p, p)
  rhs <- numeric(p)
  for (d in seq_len(design$n)) {
    Xd <- design$X_blocks[[d]]
    M <- M + crossprod(Xd, W[[d]] %*% Xd)
    rhs <- rhs + as.numeric(crossprod(Xd, W[[d]] %*% design$y_blocks[[d]]))
  }
  if (p) {
    scaled_M <- M / sqrt(outer(diag(M), diag(M)))
    if (!all(is.finite(scaled_M)) || rcond(scaled_M) < 1e-12) {
      stop("fixed-effect information is rank deficient or ill-conditioned")
    }
    Mc <- chol(M)
    Minv <- chol2inv(Mc)
    beta <- as.numeric(Minv %*% rhs)
    logdetM <- 2 * sum(log(diag(Mc)))
  } else {
    Minv <- M
    beta <- numeric()
    logdetM <- 0
  }
  residuals <- lapply(seq_len(design$n), function(d) {
    design$y_blocks[[d]] - as.numeric(design$X_blocks[[d]] %*% beta)
  })
  Py <- lapply(seq_len(design$n), function(d) as.numeric(W[[d]] %*% residuals[[d]]))
  yPy <- sum(vapply(seq_len(design$n), function(d) sum(residuals[[d]] * Py[[d]]), numeric(1)))
  out <- list(loglik = -.5 * (logdetV + logdetM + yPy), beta = beta,
              fixed_effect_covariance = Minv, inverse_blocks = W)
  if (is.null(derivatives)) return(out)
  trace <- function(x) sum(diag(x))
  k <- length(derivatives)
  B <- lapply(seq_len(k), function(i) matrix(0, p, p))
  score <- numeric(k)
  for (i in seq_len(k)) {
    tr_WD <- quadratic <- 0
    for (d in seq_len(design$n)) {
      Xd <- design$X_blocks[[d]]
      WD <- W[[d]] %*% derivatives[[i]]
      tr_WD <- tr_WD + trace(WD)
      quadratic <- quadratic + sum(Py[[d]] * as.numeric(derivatives[[i]] %*% Py[[d]]))
      B[[i]] <- B[[i]] + crossprod(Xd, WD %*% W[[d]] %*% Xd)
    }
    score[i] <- .5 * (quadratic - tr_WD + trace(Minv %*% B[[i]]))
  }
  information <- matrix(0, k, k)
  for (i in seq_len(k)) for (j in seq.int(i, k)) {
    trace0 <- trace1 <- 0
    for (d in seq_len(design$n)) {
      Xd <- design$X_blocks[[d]]
      chain <- W[[d]] %*% derivatives[[i]] %*% W[[d]] %*% derivatives[[j]]
      trace0 <- trace0 + trace(chain)
      trace1 <- trace1 + trace(Minv %*% crossprod(Xd, chain %*% W[[d]] %*% Xd))
    }
    information[i, j] <- information[j, i] <- .5 *
      (trace0 - 2 * trace1 + trace(Minv %*% B[[i]] %*% Minv %*% B[[j]]))
  }
  out$score <- score
  out$information <- (information + t(information)) / 2
  out
}

sae_mfh_endpoint_signature <- function(fit_obj, model, formula, vardir, data) {
  used <- unique(c(unlist(lapply(formula, all.vars)), vardir))
  list(model = toupper(model), theta = sae_mfh_theta(fit_obj, model),
       convergence = isTRUE(fit_obj$fit$convergence),
       formula = lapply(formula, function(f) paste(deparse(f), collapse = "")),
       data = as.data.frame(data[, used, drop = FALSE]))
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
              curvature_max = NA_real_, message = NA_character_)
  res <- tryCatch({
    d <- sae_mfh_design(formula, vardir, data)
    theta <- sae_mfh_theta(fit_obj, model)
    if (any(!is.finite(theta))) stop("non-finite variance parameters")
    if (any(theta[!grepl("^rho", names(theta))] < 0) ||
        ("rho" %in% names(theta) && abs(theta[["rho"]]) >= 1)) {
      stop("variance parameters are outside the model parameter space")
    }
    working <- theta
    if (model == "MFH2") {
      working[1] <- theta[1] / (1 - theta[2]^2)
      names(working)[1] <- "marginal_variance"
      Gfun <- function(th) th[1] * matrix(c(1, th[2], th[2], 1), 2, 2)
      derivatives <- function(th) list(matrix(c(1, th[2], th[2], 1), 2, 2),
                                      th[1] * matrix(c(0, 1, 1, 0), 2, 2))
    } else if (model == "MFH1") {
      Gfun <- function(th) diag(th, 2, 2)
      derivatives <- function(th) list(diag(c(1, 0)), diag(c(0, 1)))
    } else {
      Gfun <- function(th) sae_mfh_G(model, th, 2L)
      derivatives <- function(th) {
        rho <- th[3]
        list(matrix(c(1, rho, rho, rho^2), 2, 2), diag(c(0, 1)),
             matrix(c(2 * rho, th[1] + 3 * rho^2,
                      th[1] + 3 * rho^2, 2 * rho * th[1] + 4 * rho^3), 2, 2))
      }
    }
    evaluate <- function(th) sae_mfh_reml_evaluate(d, Gfun(th), derivatives(th))
    evaluated <- evaluate(working)
    score <- evaluated$score
    info <- evaluated$information
    names(score) <- names(working)
    is_rho <- grepl("^rho", names(working))
    variance_scale <- max(mean(diag(d$R)), max(abs(working[!is_rho])), 1e-12)
    zero_threshold <- 1e-10 * variance_scale
    at_zero <- !is_rho & working <= zero_threshold
    # At zero marginal variance rho is unidentified. Check the two extreme
    # feasible correlation directions, not merely the arbitrary reported rho.
    # For two periods the variance-direction score is affine in rho, so these
    # endpoints exhaust the feasible first-order directions.
    zero_direction_ok <- TRUE
    if (model == "MFH2" && working[1] <= zero_threshold) {
      direction_scores <- vapply(c(-1 + 1e-6, 1 - 1e-6), function(rho) {
        q <- evaluate(c(working[1], rho))
        if (q$score[1] <= 0) 0 else q$score[1]^2 / q$information[1, 1]
      }, numeric(1))
      zero_direction_ok <- all(is.finite(direction_scores)) && max(direction_scores) <= tol
    }
    at_lower <- at_zero & score <= 0
    at_rho_bound <- is_rho & ((working >= 1 - 1.01e-6 & score > 0) |
                              (working <= -1 + 1.01e-6 & score < 0))
    unidentified_rho <- is_rho & model == "MFH2" & working[1] <= zero_threshold
    free <- !(at_lower | at_rho_bound | unidentified_rho)
    information_condition <- 1
    nd <- 0
    curvature_max <- NA_real_
    if (any(free)) {
      information <- info[free, free, drop = FALSE]
      scale <- sqrt(diag(information))
      if (any(!is.finite(scale)) || any(scale <= 0)) stop("non-positive variance-parameter information")
      scaled_information <- information / outer(scale, scale)
      information_condition <- rcond(scaled_information)
      if (!is.finite(information_condition) || information_condition < 1e-10) {
        stop("variance-parameter information is singular or ill-conditioned")
      }
      nd <- as.numeric(crossprod(score[free], solve(information, score[free])))
      # A first-order stationary root can also be a minimum or a saddle.
      # Check observed curvature on the feasible free-parameter subspace.
      if (is.finite(nd) && nd >= 0 && nd <= tol) {
        indices <- which(free)
        H <- matrix(0, length(indices), length(indices))
        for (j in seq_along(indices)) {
          i <- indices[j]
          h <- max(1e-6 * abs(working[i]), 1e-4 / scale[j], .Machine$double.eps)
          up <- down <- working
          up[i] <- up[i] + h
          down[i] <- down[i] - h
          H[, j] <- (evaluate(up)$score[free] - evaluate(down)$score[free]) / (2 * h)
        }
        H <- (H + t(H)) / 2 / outer(scale, scale)
        curvature_max <- max(eigen(H, symmetric = TRUE, only.values = TRUE)$values)
      }
    }
    step_full <- tryCatch(solve(info, score), error = function(e) rep(NA_real_, length(theta)))
    list(theta = theta, reml_loglik = evaluated$loglik, score = score,
         newton_decrement = nd, proposed = working + step_full, free = free,
         zero_direction_ok = zero_direction_ok, curvature_max = curvature_max,
         information_condition = information_condition,
         validation_signature = sae_mfh_endpoint_signature(fit_obj, model, formula, vardir, data))
  }, error = function(e) e)
  if (inherits(res, "error")) {
    out$status <- "check_failed"
    out$message <- paste("The REML check could not be computed:", conditionMessage(res))
    return(out)
  }
  out[names(res)] <- res
  out$loglik_gain <- res$newton_decrement / 2
  stationary <- is.finite(res$newton_decrement) && res$newton_decrement >= -1e-10 &&
    res$newton_decrement <= tol && isTRUE(res$zero_direction_ok)
  curvature_ok <- !any(res$free) || (is.finite(res$curvature_max) && res$curvature_max < -1e-7)
  out$status <- if (!out$msae_converged) {
    "not_converged"
  } else if (!stationary) {
    "not_at_maximum"
  } else if (!curvature_ok) {
    "invalid_curvature"
  } else "ok"
  out$message <- switch(out$status,
    ok = "The fitted parameters pass the REML score, active-bound, information, and observed-curvature checks.",
    not_converged = sprintf("The estimator did not converge (%s iterations); its results are the last iterate.", format(out$iterations)),
    not_at_maximum = sprintf("The fitted parameters fail the REML score or boundary-direction check (Newton decrement %.3g); inference is withheld.", res$newton_decrement),
    invalid_curvature = "The REML stationary point lacks strictly negative observed curvature on its free parameter subspace; inference is withheld.")
  out
}

# Shared inference gate. A package convergence flag alone is insufficient.
sae_mfh_fit_usable <- function(model_obj, model_type, formula, vardir, data) {
  if (is.null(model_obj) || !isTRUE(model_obj$fit$convergence) ||
      is.null(model_obj$eblup) || any(!is.finite(as.matrix(model_obj$eblup)))) return(FALSE)
  chk <- attr(model_obj, ".reml_endpoint")
  signature <- tryCatch(sae_mfh_endpoint_signature(model_obj, model_type, formula, vardir, data),
                        error = function(e) NULL)
  if (is.null(chk) || is.null(signature) || !identical(chk$validation_signature, signature)) {
    chk <- sae_mfh_reml_endpoint(model_obj, model_type, formula, vardir, data)
  }
  identical(chk$status, "ok")
}

# Marginal standardization of y - EBLUP using diag(R P R), including the
# fitted fixed-effect uncertainty and both periods' sampling covariance.
# These standardized residuals remain correlated; QQ plots are diagnostics,
# not independent observations for an exact iid-normality hypothesis test.
sae_mfh_standardized_residuals <- function(model_obj, model_type, formula, vardir, data) {
  d <- sae_mfh_design(formula, vardir, data)
  G <- sae_mfh_G(model_type, sae_mfh_theta(model_obj, model_type), d$r)
  evaluated <- sae_mfh_reml_evaluate(d, G)
  estimates <- as.matrix(model_obj$eblup)
  if (!identical(dim(estimates), c(d$n, d$r)) || !all(is.finite(estimates))) {
    stop("MFH residual diagnostics require finite, aligned estimates.", call. = FALSE)
  }
  raw <- matrix(d$y, d$n, d$r) - estimates
  variance <- matrix(NA_real_, d$n, d$r, dimnames = dimnames(estimates))
  for (i in seq_len(d$n)) {
    W <- evaluated$inverse_blocks[[i]]
    X <- d$X_blocks[[i]]
    Rd <- d$R_blocks[[i]]
    Pii <- W - W %*% X %*% evaluated$fixed_effect_covariance %*% t(X) %*% W
    residual_covariance <- Rd %*% Pii %*% Rd
    v <- diag((residual_covariance + t(residual_covariance)) / 2)
    if (any(v < -1e-8 * max(diag(Rd), .Machine$double.eps))) {
      stop("Invalid model-based residual variance.", call. = FALSE)
    }
    variance[i, ] <- pmax(v, 0)
  }
  standardized <- raw / sqrt(variance)
  standardized[variance <= 0 | !is.finite(standardized)] <- NA_real_
  list(raw = raw, standardized = standardized, variance = variance,
       method = "marginal standardization by diag(R P R)")
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
