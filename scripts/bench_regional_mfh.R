# Ratio benchmarking and bootstrap uncertainty for the final MFH estimator.
# Inputs eblup_mat/direct_mat are on the model scale; uploaded targets are on
# the requested output scale. Every replicate back-transforms first, then
# benchmarks, before measuring errors against the unbenchmarked true target.
if (!exists("sae_mfh_bootstrap", mode = "function")) {
  .mfh_helper <- if (requireNamespace("here", quietly = TRUE)) {
    here::here("R", "mfh_bootstrap_helpers.R")
  } else file.path("R", "mfh_bootstrap_helpers.R")
  source(.mfh_helper)
  rm(.mfh_helper)
}

bench_regional_mfh <- function(eblup_mat, mse_mat = NULL, mcpe_mat = NULL,
                                 domain_vec, region_vec, Nd_vec, Nd_mat = NULL,
                                 direct_mat, regional_benchmark_mat = NULL,
                                 model_obj = NULL, model_type = "MFH2",
                                 formula = NULL, vardir = NULL, data = NULL,
                                 MSE = FALSE, nB = 200, seed = 123,
                                 max_attempts = NULL,
                                 back_transform = c("none", "log"),
                                 bias_correction = TRUE, fit_validator = NULL,
                                 ...) {
  model_type <- match.arg(toupper(model_type), c("MFH1", "MFH2", "MFH3"))
  back_transform <- match.arg(back_transform)
  eblup_mat <- as.matrix(eblup_mat)
  direct_mat <- as.matrix(direct_mat)
  nD <- nrow(eblup_mat)
  nT <- ncol(eblup_mat)
  stopifnot(length(domain_vec) == nD, length(region_vec) == nD,
            length(Nd_vec) == nD, identical(dim(direct_mat), dim(eblup_mat)))
  if (anyNA(domain_vec) || anyDuplicated(domain_vec) || anyNA(region_vec)) {
    stop("Benchmark domains must be unique and every domain must have a group.", call. = FALSE)
  }
  check_order <- function(mat, label) {
    if (!is.null(rownames(mat)) &&
        !identical(as.character(rownames(mat)), as.character(domain_vec))) {
      stop(label, " row names do not match domain_vec order.", call. = FALSE)
    }
    if (!is.null(colnames(mat)) && !is.null(colnames(eblup_mat)) &&
        !identical(colnames(mat), colnames(eblup_mat))) {
      stop(label, " time columns do not match eblup_mat.", call. = FALSE)
    }
  }
  check_order(eblup_mat, "eblup_mat")
  check_order(direct_mat, "direct_mat")
  if (is.null(Nd_mat)) Nd_mat <- matrix(Nd_vec, nD, nT)
  Nd_mat <- as.matrix(Nd_mat)
  stopifnot(identical(dim(Nd_mat), dim(eblup_mat)))
  check_order(Nd_mat, "Nd_mat")
  if (any(!is.finite(Nd_mat)) || any(Nd_mat < 0)) {
    stop("Benchmark population weights must be finite and non-negative.", call. = FALSE)
  }
  groups <- unique(as.character(region_vec))
  if (!is.null(regional_benchmark_mat)) {
    regional_benchmark_mat <- as.matrix(regional_benchmark_mat)
    if (ncol(regional_benchmark_mat) != nT ||
        !all(groups %in% rownames(regional_benchmark_mat)) ||
        any(!is.finite(regional_benchmark_mat))) {
      stop("Benchmark targets must be finite and cover every group and time period.", call. = FALSE)
    }
    if (!is.null(colnames(regional_benchmark_mat)) && !is.null(colnames(eblup_mat)) &&
        !identical(colnames(regional_benchmark_mat), colnames(eblup_mat))) {
      stop("Benchmark target time columns do not match eblup_mat.", call. = FALSE)
    }
  }
  apply_bench <- function(estimates, direct) {
    estimates <- as.matrix(estimates)
    direct <- as.matrix(direct)
    if (!all(is.finite(estimates)) || !all(is.finite(direct))) {
      stop("Benchmark estimates and direct targets must be finite.", call. = FALSE)
    }
    result <- estimates
    lambda <- matrix(1, nD, nT, dimnames = dimnames(estimates))
    for (tt in seq_len(nT)) for (group in groups) {
      rows <- which(as.character(region_vec) == group)
      weights <- Nd_mat[rows, tt]
      if (sum(weights) <= 0) stop("A benchmark group has zero total population.", call. = FALSE)
      target <- if (is.null(regional_benchmark_mat)) {
        stats::weighted.mean(direct[rows, tt], weights)
      } else regional_benchmark_mat[group, tt]
      fitted_mean <- stats::weighted.mean(estimates[rows, tt], weights)
      if (abs(fitted_mean) <= 1e-12) {
        if (abs(target) > 1e-12) stop("Cannot ratio-benchmark a zero model mean to a nonzero target.", call. = FALSE)
        factor <- 1
      } else factor <- target / fitted_mean
      result[rows, tt] <- estimates[rows, tt] * factor
      lambda[rows, tt] <- factor
    }
    list(bench = result, lambda = lambda)
  }
  point <- eblup_mat
  direct_output <- direct_mat
  if (back_transform == "log") {
    if (is.null(model_obj) || is.null(data) || is.null(vardir)) {
      stop("Log benchmarking requires model_obj, data, and vardir.", call. = FALSE)
    }
    point <- sae_mfh_estimate_matrix(model_obj, model_type, data, vardir,
                                       back_transform, bias_correction)
    direct_output <- exp(direct_mat)
    dimnames(point) <- dimnames(eblup_mat)
  }
  point_result <- apply_bench(point, direct_output)
  boot <- NULL
  if (isTRUE(MSE)) {
    if (is.null(model_obj) || is.null(formula) || is.null(vardir) || is.null(data)) {
      stop("Bootstrap benchmarking requires model_obj, formula, vardir, and data.", call. = FALSE)
    }
    observed <- vapply(formula, function(f) {
      as.numeric(stats::model.response(stats::model.frame(f, data, na.action = stats::na.fail)))
    }, numeric(nD))
    if (!isTRUE(all.equal(as.numeric(observed), as.numeric(direct_mat), tolerance = 1e-10))) {
      stop("direct_mat must be the model-scale response used to fit the model.", call. = FALSE)
    }
    bootstrap_data <- data
    id_column <- ".sae_benchmark_domain"
    while (id_column %in% names(bootstrap_data)) id_column <- paste0(".", id_column)
    bootstrap_data[[id_column]] <- domain_vec
    boot <- sae_mfh_bootstrap(
      model_type = model_type, formula = formula, vardir = vardir,
      domain_var = id_column, existing_model = model_obj, nB = nB,
      data = bootstrap_data, max_attempts = max_attempts, seed = seed,
      back_transform = back_transform, bias_correction = bias_correction,
      fit_validator = fit_validator,
      postprocess = function(estimates, direct) apply_bench(estimates, direct)$bench,
      ...
    )
  }
  list(eblup_bench = point_result$bench,
       mse_bench = if (is.null(boot)) NULL else boot$mse,
       mcpe_bench = if (is.null(boot)) NULL else boot$mcpe,
       mse_mcse = if (is.null(boot)) NULL else boot$mse_mcse,
       mcpe_mcse = if (is.null(boot)) NULL else boot$mcpe_mcse,
       error_second_moment = if (is.null(boot)) NULL else boot$error_second_moment,
       lambda = point_result$lambda,
       fails = if (is.null(boot)) NA_integer_ else boot$fails,
       n_success = if (is.null(boot)) 0L else boot$n_success,
       attempts = if (is.null(boot)) NA_integer_ else boot$attempts,
       covariance_boundary_count = if (is.null(boot)) NA_integer_ else boot$covariance_boundary_count,
       covariance_boundary_fraction = if (is.null(boot)) NA_real_ else boot$covariance_boundary_fraction,
       variance_zero_count = if (is.null(boot)) NA_integer_ else boot$variance_zero_count,
       correlation_limit_count = if (is.null(boot)) NA_integer_ else boot$correlation_limit_count,
       inference_status = if (is.null(boot)) "unavailable" else boot$inference_status,
       covariance_boundary = if (is.null(boot)) NULL else boot$covariance_boundary,
       output_scale = if (back_transform == "log") "original" else "model",
       back_transform = back_transform,
       bias_correction = isTRUE(bias_correction))
}
