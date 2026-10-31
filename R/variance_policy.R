# Shared variance-selection policy for UFH and MFH.
#
# Under sm_out, the direct sampling variance is retained unless it is
# missing/non-finite or below the fixed threshold. This intentionally does
# not replace large direct variances.
#
# sm_all replaces every variance with a GVF prediction from sample size
# alone. For poverty rates it gives areas of similar size similar variances
# whatever their rate, overstating the variance of low-poverty areas.

SAE_SM_OUT_VARIANCE_THRESHOLD <- 0.001

# New or omitted settings use selective smoothing (sm_out). Explicit saved
# alternatives remain unchanged; a missing covariance follows the effective
# variance.
.sae_variance_setting_missing <- function(x) {
  is.null(x) || length(x) == 0L ||
    (is.atomic(x) && length(x) == 1L &&
       (is.na(x) || !nzchar(trimws(as.character(x)))))
}

sae_variance_choice <- function(x = NULL) {
  if (.sae_variance_setting_missing(x)) "sm_out" else x
}

sae_covariance_choice <- function(x = NULL, var_choice = NULL) {
  if (.sae_variance_setting_missing(x)) {
    return(switch(as.character(sae_variance_choice(var_choice)),
                  sm_out = "rho_sm_out", direct = "rho_dir", "rho_sm_all"))
  }
  # Legacy saved-browser alias denotes selective smoothing, not the default.
  if (identical(x, "rho_sm")) "rho_sm_out" else x
}

sae_setup_variance_inputs <- function(inputs = NULL) {
  if (is.null(inputs)) inputs <- list()
  inputs$ufh_var_choice <- sae_variance_choice(inputs$ufh_var_choice)
  inputs$mfh_var_choice <- sae_variance_choice(inputs$mfh_var_choice)
  inputs$mfh_cov_choice <- sae_covariance_choice(inputs$mfh_cov_choice,
                                                inputs$mfh_var_choice)
  inputs
}

sae_sm_out_variance <- function(direct_variance,
                                smoothed_variance,
                                threshold = SAE_SM_OUT_VARIANCE_THRESHOLD) {
  direct_variance <- as.numeric(direct_variance)
  smoothed_variance <- as.numeric(smoothed_variance)

  target_length <- max(length(direct_variance), length(smoothed_variance))
  if (!length(direct_variance) || !length(smoothed_variance) ||
      target_length %% length(direct_variance) != 0L ||
      target_length %% length(smoothed_variance) != 0L) {
    stop("Direct and smoothed variance vectors must have compatible lengths.",
         call. = FALSE)
  }

  direct_variance <- rep(direct_variance, length.out = target_length)
  smoothed_variance <- rep(smoothed_variance, length.out = target_length)

  threshold <- suppressWarnings(as.numeric(threshold)[1])
  if (!is.finite(threshold) || threshold < 0) {
    stop("The sm_out variance threshold must be a finite non-negative number.",
         call. = FALSE)
  }

  replace <- !is.finite(direct_variance) | direct_variance < threshold
  direct_variance[replace] <- smoothed_variance[replace]
  direct_variance
}

# Domain-year cells whose modeled variance is not the direct variance.
sae_replaced_variance_label <- function(direct_variance, used_variance) {
  direct_variance <- as.numeric(direct_variance)
  used_variance <- as.numeric(used_variance)
  replaced <- !is.finite(direct_variance) | !is.finite(used_variance) |
    direct_variance != used_variance
  sprintf("%d of %d", sum(replaced), length(replaced))
}

