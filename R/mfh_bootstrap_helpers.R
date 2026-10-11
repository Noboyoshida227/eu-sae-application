# Random-effect simulation helpers used by the MFH parametric bootstrap.
# Keeping the data-generating process in one place makes it possible to test
# its implied covariance independently of the msae refitting routines.

sae_mfh_rho_scalar <- function(rho) {
  if (is.null(rho)) stop("The fitted model does not contain rho.", call. = FALSE)
  value <- if (is.matrix(rho) || is.data.frame(rho)) {
    suppressWarnings(as.numeric(rho[, 1L])[1L])
  } else {
    suppressWarnings(as.numeric(rho)[1L])
  }
  if (!is.finite(value) || abs(value) >= 1) {
    stop("rho must be finite and strictly between -1 and 1.", call. = FALSE)
  }
  value
}

sae_mfh_refvar_vector <- function(refvar, nT, model) {
  value <- suppressWarnings(as.numeric(refvar))
  if (!length(value) || any(!is.finite(value)) || any(value < 0)) {
    stop(model, " random-effect variance estimates must be finite and non-negative.",
         call. = FALSE)
  }
  if (length(value) == 1L && model == "MFH2") return(value)
  if (length(value) == 1L) value <- rep(value, nT)
  if (length(value) != nT) {
    stop(model, " refvar length ", length(value),
         " is incompatible with nT = ", nT, ".", call. = FALSE)
  }
  value
}

# Inferential sensitivity is distinct from numerical fit validity. Use the
# covariance parameter space and the same correlation-bound tolerance as the
# independent REML endpoint check, not a cutoff calibrated to coverage results.
sae_mfh_covariance_boundary <- function(model, model_type) {
  model_type <- match.arg(toupper(model_type), c("MFH1", "MFH2", "MFH3"))
  refvar <- suppressWarnings(as.numeric(model$fit$refvar))
  if (!length(refvar) || any(!is.finite(refvar)) || any(refvar < 0)) {
    stop("Boundary diagnostics require finite non-negative covariance parameters.", call. = FALSE)
  }
  variance_zero <- any(refvar == 0)
  rho <- if (model_type == "MFH1") NA_real_ else sae_mfh_rho_scalar(model$fit$rho)
  rho_limit <- 1 - 1e-6
  correlation_limit <- model_type != "MFH1" && abs(rho) >= 1 - 1.01e-6
  boundary <- variance_zero || correlation_limit
  reason <- paste(c(if (variance_zero) "zero_variance_parameter",
                    if (correlation_limit) "correlation_at_numerical_limit"), collapse = ";")
  list(boundary = boundary, variance_zero = variance_zero,
       correlation_limit = correlation_limit, rho = rho, rho_limit = rho_limit,
       reason = if (boundary) reason else "interior_covariance_parameters",
       inference_status = if (boundary) "boundary_sensitive" else "regular")
}

sae_mfh_boundary_warning <- function() {
  paste("The fitted random-effect covariance is on a boundary (zero variance or correlation at its numerical limit).",
        "Estimates remain available, but normal/delta intervals and p-values can substantially understate uncertainty about change.",
        "Treat significance as provisional; compare Direct results and alternative admissible models before external conclusions.",
        "Increasing bootstrap draws alone does not resolve this limitation.")
}

sae_mfh_random_effect_covariance <- function(model, refvar, rho = NULL, nT) {
  model <- toupper(as.character(model)[1L])
  nT <- as.integer(nT)[1L]
  if (!is.finite(nT) || nT < 1L) stop("nT must be at least one.", call. = FALSE)

  if (model == "MFH1") {
    variances <- sae_mfh_refvar_vector(refvar, nT, model)
    return(diag(variances, nT, nT))
  }

  rho <- sae_mfh_rho_scalar(rho)
  if (model == "MFH2") {
    innovation_variance <- sae_mfh_refvar_vector(refvar, nT, model)[1L]
    idx <- seq_len(nT)
    return(innovation_variance * outer(idx, idx, function(i, j) {
      rho^abs(i - j) / (1 - rho^2)
    }))
  }

  if (model == "MFH3") {
    innovation_variances <- sae_mfh_refvar_vector(refvar, nT, model)
    # Molina-Romero/Benavent-Morales specification:
    # u_0 ~ N(0, 1), u_t = rho * u_{t-1} + a_t,
    # a_t ~ N(0, sigma_t^2).
    loading <- matrix(0, nT, nT + 1L)
    for (tt in seq_len(nT)) {
      loading[tt, 1L] <- rho^tt
      for (jj in seq_len(tt)) loading[tt, jj + 1L] <- rho^(tt - jj)
    }
    innovation_cov <- diag(c(1, innovation_variances), nT + 1L)
    return(loading %*% innovation_cov %*% t(loading))
  }

  stop("Unsupported MFH model: ", model, call. = FALSE)
}

sae_simulate_mfh_random_effects <- function(model, nD, nT, refvar,
                                            rho = NULL) {
  model <- toupper(as.character(model)[1L])
  nD <- as.integer(nD)[1L]
  nT <- as.integer(nT)[1L]
  if (!is.finite(nD) || nD < 1L) stop("nD must be at least one.", call. = FALSE)

  if (model == "MFH1") {
    variances <- sae_mfh_refvar_vector(refvar, nT, model)
    draws <- matrix(
      stats::rnorm(nD * nT,
                   sd = rep(sqrt(variances), times = nD)),
      nrow = nD, ncol = nT, byrow = TRUE
    )
    return(draws)
  }

  rho <- sae_mfh_rho_scalar(rho)
  if (model == "MFH2") {
    innovation_variance <- sae_mfh_refvar_vector(refvar, nT, model)[1L]
    innovations <- matrix(
      stats::rnorm(nD * nT, sd = sqrt(innovation_variance)),
      nrow = nD, ncol = nT, byrow = TRUE
    )
    draws <- matrix(0, nD, nT)
    draws[, 1L] <- innovations[, 1L] / sqrt(1 - rho^2)
    if (nT > 1L) {
      for (tt in 2:nT) draws[, tt] <- rho * draws[, tt - 1L] + innovations[, tt]
    }
    return(draws)
  }

  if (model == "MFH3") {
    innovation_variances <- sae_mfh_refvar_vector(refvar, nT, model)
    innovations <- matrix(
      stats::rnorm(nD * nT,
                   sd = rep(sqrt(innovation_variances), times = nD)),
      nrow = nD, ncol = nT, byrow = TRUE
    )
    u0 <- stats::rnorm(nD, sd = 1)
    draws <- matrix(0, nD, nT)
    draws[, 1L] <- rho * u0 + innovations[, 1L]
    if (nT > 1L) {
      for (tt in 2:nT) draws[, tt] <- rho * draws[, tt - 1L] + innovations[, tt]
    }
    return(draws)
  }

  stop("Unsupported MFH model: ", model, call. = FALSE)
}

sae_bootstrap_mcse <- function(sum_values, sum_squares, n) {
  if (n <= 1L) return(matrix(NA_real_, nrow(sum_values), ncol(sum_values)))
  means <- sum_values / n
  variances <- (sum_squares - n * means^2) / (n - 1L)
  sqrt(pmax(variances, 0) / n)
}

# Validate once before the original fit. Repairs preserve the sampling
# variances and project an invalid correlation matrix to a positive-definite
# correlation matrix. The returned vardir values, not a second approximation,
# must be used for fitting, simulation, and bootstrap refitting.
sae_mfh_prepare_sampling_covariance <- function(data, vardir, nT,
                                                 repair = TRUE, tol = 1e-10) {
  nT <- as.integer(nT)
  if (length(nT) != 1L || is.na(nT) || nT < 1L ||
      length(vardir) != nT * (nT + 1L) / 2L) {
    stop("vardir must contain nT variances followed by the pairwise covariances.", call. = FALSE)
  }
  if (!all(vardir %in% names(data))) stop("Missing sampling-covariance columns.", call. = FALSE)
  values <- as.matrix(data[, vardir, drop = FALSE])
  storage.mode(values) <- "double"
  if (!all(is.finite(values))) stop("Sampling covariances must be finite.", call. = FALSE)
  if (any(values[, seq_len(nT), drop = FALSE] < 0)) {
    stop("Sampling variances must be non-negative.", call. = FALSE)
  }
  pairs <- if (nT > 1L) utils::combn(nT, 2L) else matrix(integer(), 2L, 0L)
  Sigma <- array(0, c(nT, nT, nrow(data)))
  diagnostics <- vector("list", nrow(data))
  for (d in seq_len(nrow(data))) {
    S <- diag(values[d, seq_len(nT)], nT, nT)
    if (ncol(pairs)) for (j in seq_len(ncol(pairs))) {
      S[pairs[1L, j], pairs[2L, j]] <- S[pairs[2L, j], pairs[1L, j]] <- values[d, nT + j]
    }
    before <- S
    eigen_before <- min(eigen(S, symmetric = TRUE, only.values = TRUE)$values)
    scale <- max(diag(S), .Machine$double.eps)
    zero <- diag(S) == 0
    invalid_zero <- any(S[zero, , drop = FALSE] != 0)
    needs_repair <- eigen_before < -tol * scale || invalid_zero
    if (needs_repair && !isTRUE(repair)) {
      stop(sprintf("Sampling covariance for row %d is not positive semidefinite; prepare the covariance and refit the original model before bootstrapping.", d), call. = FALSE)
    }
    if (needs_repair) {
      S[zero, ] <- 0
      S[, zero] <- 0
      pos <- which(!zero)
      if (length(pos)) {
        sd_pos <- sqrt(diag(before)[pos])
        C <- S[pos, pos, drop = FALSE] / outer(sd_pos, sd_pos)
        eig <- eigen(C, symmetric = TRUE)
        C <- eig$vectors %*% (pmax(eig$values, 1e-8) * t(eig$vectors))
        C <- C / sqrt(outer(diag(C), diag(C)))
        S[pos, pos] <- C * outer(sd_pos, sd_pos)
        diag(S)[pos] <- diag(before)[pos]
      }
    }
    Sigma[, , d] <- S
    if (ncol(pairs)) for (j in seq_len(ncol(pairs))) {
      values[d, nT + j] <- S[pairs[1L, j], pairs[2L, j]]
    }
    diagnostics[[d]] <- data.frame(
      row = d, repaired = needs_repair,
      min_eigen_before = eigen_before,
      min_eigen_after = min(eigen(S, symmetric = TRUE, only.values = TRUE)$values),
      max_abs_change = max(abs(S - before)),
      method = if (needs_repair) "correlation_eigen_projection" else "unchanged"
    )
  }
  data[, vardir] <- values
  list(data = data, Sigma = Sigma, diagnostics = do.call(rbind, diagnostics))
}

# Replace only the response expression. This preserves ~1, ~0, offsets,
# interactions, transformations, and the formula's evaluation environment.
sae_mfh_bootstrap_formulas <- function(formula, response_names) {
  stopifnot(length(formula) == length(response_names))
  Map(function(f, nm) {
    f[[2L]] <- as.name(nm)
    f
  }, formula, response_names)
}

# Empirical conditional lognormal expectation for a model of log(area mean).
# beta and covariance parameters are plugged in here; the parametric bootstrap
# refits them in every draw to measure their contribution to prediction error.
sae_mfh_estimate_matrix <- function(model, model_type, data, vardir,
                                      back_transform = c("none", "log"),
                                      bias_correction = TRUE) {
  back_transform <- match.arg(back_transform)
  eta <- as.matrix(model$eblup)
  storage.mode(eta) <- "double"
  if (nrow(eta) != nrow(data) || !all(is.finite(eta))) {
    stop("MFH estimates are missing, non-finite, or not aligned with the fitting data.", call. = FALSE)
  }
  if (back_transform == "none") return(eta)
  conditional_variance <- matrix(0, nrow(eta), ncol(eta))
  if (isTRUE(bias_correction)) {
    prepared <- sae_mfh_prepare_sampling_covariance(data, vardir, ncol(eta), repair = FALSE)
    G <- sae_mfh_random_effect_covariance(model_type, model$fit$refvar,
                                          model$fit$rho, nT = ncol(eta))
    for (d in seq_len(nrow(eta))) {
      if (all(G == 0)) next
      S <- matrix(prepared$Sigma[, , d], ncol(eta), ncol(eta))
      V <- G + S
      Q <- G - G %*% solve(V, G)
      v <- diag((Q + t(Q)) / 2)
      if (any(!is.finite(v)) || any(v < -1e-8 * max(1, max(diag(G))))) {
        stop("Invalid conditional random-effect variance for log back-transformation.", call. = FALSE)
      }
      conditional_variance[d, ] <- pmax(v, 0)
    }
  }
  result <- exp(eta + conditional_variance / 2)
  if (!all(is.finite(result))) stop("Non-finite lognormal back-transformed estimates.", call. = FALSE)
  result
}

sae_mfh_error_products <- function(errors) {
  errors <- as.matrix(errors)
  nT <- ncol(errors)
  pairs <- if (nT > 1L) utils::combn(nT, 2L) else matrix(integer(), 2L, 0L)
  products <- errors^2
  if (ncol(pairs)) {
    cross <- vapply(seq_len(ncol(pairs)), function(j) {
      errors[, pairs[1L, j]] * errors[, pairs[2L, j]]
    }, numeric(nrow(errors)))
    products <- cbind(products, matrix(cross, nrow(errors), ncol(pairs)))
  }
  products
}

# Common engine: all diagonal and off-diagonal moments use the very same
# successful, finite prediction-error vectors. postprocess implements any
# final benchmarking on the requested output scale, both here and per draw.
sae_mfh_bootstrap <- function(model_type, formula, vardir, domain_var,
                                existing_model, nB = 200L, data,
                                max_attempts = NULL, seed = 123L,
                                back_transform = c("none", "log"),
                                bias_correction = TRUE, fit_validator = NULL,
                                postprocess = NULL, refit_fn = NULL, ...) {
  model_type <- match.arg(toupper(model_type), c("MFH1", "MFH2", "MFH3"))
  back_transform <- match.arg(back_transform)
  nB <- as.integer(nB)
  if (length(nB) != 1L || is.na(nB) || nB < 1L) stop("nB must be positive.", call. = FALSE)
  if (is.null(max_attempts)) max_attempts <- 5L * nB
  if (!is.finite(max_attempts) || max_attempts < nB) stop("max_attempts must be at least nB.", call. = FALSE)
  if (!is.null(seed)) set.seed(seed)
  nD <- nrow(data)
  nT <- length(formula)
  if (nD < 1L || nT < 1L) stop("Bootstrap needs nonempty fitting data and formulas.", call. = FALSE)
  domain <- data[[domain_var]]
  if (is.null(domain) || anyNA(domain) || anyDuplicated(domain)) {
    stop("Bootstrap domain identifiers must be present, nonmissing, and unique.", call. = FALSE)
  }
  if (!isTRUE(existing_model$fit$convergence)) stop("Existing MFH model did not converge.", call. = FALSE)
  if (is.null(fit_validator) && exists("sae_mfh_fit_usable", mode = "function")) {
    fit_validator <- get("sae_mfh_fit_usable", mode = "function")
  }
  if (!is.null(fit_validator) && !isTRUE(fit_validator(existing_model, model_type, formula, vardir, data))) {
    stop("Existing MFH model failed its numerical validation.", call. = FALSE)
  }
  prepared <- sae_mfh_prepare_sampling_covariance(data, vardir, nT, repair = FALSE)
  data <- prepared$data
  X <- lapply(formula, function(f) stats::model.matrix(f, data))
  if (any(vapply(X, nrow, integer(1L)) != nD)) stop("Incomplete covariates in bootstrap data.", call. = FALSE)
  p <- vapply(X, ncol, integer(1L))
  beta <- as.numeric(existing_model$fit$estcoef[, 1L])
  if (length(beta) != sum(p) || !all(is.finite(beta))) stop("Invalid fitted MFH coefficients.", call. = FALSE)
  ends <- cumsum(p)
  starts <- c(0L, utils::head(ends, -1L))
  means <- vapply(seq_len(nT), function(tt) {
    index <- if (p[tt]) seq.int(starts[tt] + 1L, ends[tt]) else integer()
    as.numeric(X[[tt]] %*% beta[index])
  }, numeric(nD))
  means <- matrix(means, nD, nT)
  # Check fitted G before any simulation, including legitimate zero G.
  sae_mfh_random_effect_covariance(model_type, existing_model$fit$refvar,
                                    existing_model$fit$rho, nT = nT)
  original_boundary <- sae_mfh_covariance_boundary(existing_model, model_type)
  sampling_factors <- lapply(seq_len(nD), function(d) {
    S <- matrix(prepared$Sigma[, , d], nT, nT)
    eig <- eigen(S, symmetric = TRUE)
    eig$vectors %*% diag(sqrt(pmax(eig$values, 0)), nT, nT)
  })
  observed <- vapply(formula, function(f) {
    as.numeric(stats::model.response(stats::model.frame(f, data, na.action = stats::na.fail)))
  }, numeric(nD))
  observed <- matrix(observed, nD, nT)
  point <- sae_mfh_estimate_matrix(existing_model, model_type, data, vardir,
                                    back_transform, bias_correction)
  if (!identical(dim(point), c(nD, nT))) {
    stop("Existing MFH estimates do not match the number of model periods.", call. = FALSE)
  }
  direct_output <- if (back_transform == "log") exp(observed) else observed
  if (!is.null(postprocess)) point <- postprocess(point, direct_output)
  if (!all(is.finite(point))) stop("The final MFH point estimates are non-finite.", call. = FALSE)
  if (is.null(refit_fn)) refit_fn <- get(paste0("eblup", model_type), mode = "function")
  responses <- paste0(".sae_bootstrap_Y", seq_len(nT))
  while (any(responses %in% names(data))) responses <- paste0(".", responses)
  formulas_b <- sae_mfh_bootstrap_formulas(formula, responses)
  n_moments <- nT * (nT + 1L) / 2L
  sums <- sums_sq <- matrix(0, nD, n_moments)
  attempts <- failures <- successful <- 0L
  covariance_boundary_count <- variance_zero_count <- correlation_limit_count <- 0L
  while (successful < nB && attempts < max_attempts) {
    attempts <- attempts + 1L
    latent <- means + sae_simulate_mfh_random_effects(
      model_type, nD, nT, existing_model$fit$refvar, existing_model$fit$rho)
    sampling <- t(vapply(sampling_factors, function(L) as.numeric(L %*% stats::rnorm(nT)), numeric(nT)))
    y <- latent + matrix(sampling, nD, nT)
    data_b <- data
    data_b[, responses] <- y
    draw <- tryCatch({
      fitted <- refit_fn(formula = formulas_b, vardir = vardir, data = data_b, ...)
      if (!isTRUE(fitted$fit$convergence)) stop("Bootstrap refit did not converge.")
      fitted_beta <- as.numeric(fitted$fit$estcoef[, 1L])
      if (length(fitted_beta) != sum(p) || !all(is.finite(fitted_beta))) {
        stop("Bootstrap refit returned invalid coefficients.")
      }
      sae_mfh_random_effect_covariance(model_type, fitted$fit$refvar,
                                        fitted$fit$rho, nT = nT)
      if (!is.null(fit_validator) && !isTRUE(fit_validator(fitted, model_type, formulas_b, vardir, data_b))) {
        stop("Bootstrap refit failed its numerical validation.")
      }
      estimates <- sae_mfh_estimate_matrix(fitted, model_type, data_b, vardir,
                                            back_transform, bias_correction)
      truth <- if (back_transform == "log") exp(latent) else latent
      direct_b <- if (back_transform == "log") exp(y) else y
      if (!is.null(postprocess)) estimates <- postprocess(estimates, direct_b)
      if (!identical(dim(estimates), c(nD, nT)) ||
          !all(is.finite(estimates)) || !all(is.finite(truth))) stop("Invalid bootstrap estimate or truth.")
      products <- sae_mfh_error_products(estimates - truth)
      if (!all(is.finite(products)) || !all(is.finite(products^2))) stop("Non-finite bootstrap error moments.")
      list(products = products,
           boundary = sae_mfh_covariance_boundary(fitted, model_type))
    }, error = function(e) NULL)
    if (is.null(draw)) {
      failures <- failures + 1L
      next
    }
    moments <- draw$products
    sums <- sums + moments
    sums_sq <- sums_sq + moments^2
    successful <- successful + 1L
    covariance_boundary_count <- covariance_boundary_count + as.integer(draw$boundary$boundary)
    variance_zero_count <- variance_zero_count + as.integer(draw$boundary$variance_zero)
    correlation_limit_count <- correlation_limit_count + as.integer(draw$boundary$correlation_limit)
  }
  if (successful < nB) {
    warning(sprintf("%s bootstrap obtained only %d/%d valid draws in %d attempts; uncertainty is unavailable.", model_type, successful, nB, attempts), call. = FALSE)
    return(NULL)
  }
  if (failures > 0L) warning(sprintf("%s bootstrap rejected %d/%d refits or non-finite draws; inspect this failure rate before using inference.", model_type, failures, attempts), call. = FALSE)
  moments <- sums / successful
  mcse <- sae_bootstrap_mcse(sums, sums_sq, successful)
  off <- if (nT > 1L) seq.int(nT + 1L, n_moments) else integer()
  mse <- moments[, seq_len(nT), drop = FALSE]
  mcpe <- moments[, off, drop = FALSE]
  mse_mcse <- mcse[, seq_len(nT), drop = FALSE]
  mcpe_mcse <- mcse[, off, drop = FALSE]
  cn <- colnames(existing_model$eblup)
  colnames(point) <- colnames(mse) <- colnames(mse_mcse) <- cn
  covariance <- array(0, c(nT, nT, nD), dimnames = list(cn, cn, as.character(domain)))
  pairs <- if (nT > 1L) utils::combn(nT, 2L) else matrix(integer(), 2L, 0L)
  if (ncol(pairs)) colnames(mcpe) <- colnames(mcpe_mcse) <- apply(pairs, 2L, function(x) paste0("(", x[1L], ",", x[2L], ")"))
  for (d in seq_len(nD)) {
    covariance[, , d] <- diag(mse[d, ], nT, nT)
    if (ncol(pairs)) for (j in seq_len(ncol(pairs))) covariance[pairs[1L, j], pairs[2L, j], d] <- covariance[pairs[2L, j], pairs[1L, j], d] <- mcpe[d, j]
  }
  list(domain = domain, eblup = point, mse = mse, mse_mcse = mse_mcse,
       mcpe = mcpe, mcpe_mcse = mcpe_mcse, error_second_moment = covariance,
       fails = failures, n_success = successful, attempts = attempts,
       target_replicates = nB, near_pd_adjustments = 0L, seed = seed,
       covariance_boundary = original_boundary,
       inference_status = original_boundary$inference_status,
       covariance_boundary_count = covariance_boundary_count,
       covariance_boundary_fraction = covariance_boundary_count / successful,
       variance_zero_count = variance_zero_count,
       correlation_limit_count = correlation_limit_count,
       output_scale = if (back_transform == "log") "original" else "model",
       back_transform = back_transform, bias_correction = isTRUE(bias_correction))
}
