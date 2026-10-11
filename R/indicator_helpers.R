# ============================================================
# indicator_helpers.R
#
# Single source of truth for the "indicator" the FH/MFH model
# is fitted on. Two indicator families are supported:
#
#   * "poverty"      -- FGT(0/1/2) computed from welfare + povline.
#                      LHS lives on [0, 1]; arcsin transform is
#                      available; benchmarking ratios stay on the
#                      original scale.
#   * "mean_welfare" -- population-weighted mean of the welfare
#                      variable. The optional log model transforms
#                      the direct arithmetic area mean, then uses
#                      the model-specific original-scale predictor
#                      for display, benchmarking, and changes.
#
# All UFH/MFH/Comparison code should call these helpers rather
# than hard-coding indicator-specific behaviour or labels.
# ============================================================

# ----- compatibility shim for fgt_label() ----------------------------------
# Some callers (notably the Quarto reports) use fgt_label() directly. Keep
# that exported symbol but route everything through indicator_label() so the
# label table lives in one place.
if (!exists("fgt_label", mode = "function")) {
  fgt_label <- function(alpha) {
    alpha <- as.integer(alpha %||% 0L)
    switch(as.character(alpha),
      "0" = list(fgt = "FGT(0)", short = "Headcount ratio",
                 noun_singular = "poverty rate",
                 noun_plural   = "poverty rates",
                 axis_label    = "Poverty rate"),
      "1" = list(fgt = "FGT(1)", short = "Poverty gap",
                 noun_singular = "poverty gap",
                 noun_plural   = "poverty gaps",
                 axis_label    = "Poverty gap"),
      "2" = list(fgt = "FGT(2)", short = "Poverty severity",
                 noun_singular = "poverty severity",
                 noun_plural   = "poverty severity values",
                 axis_label    = "Poverty severity"),
      list(fgt = "FGT(0)", short = "Headcount ratio",
           noun_singular = "poverty rate",
           noun_plural   = "poverty rates",
           axis_label    = "Poverty rate")
    )
  }
}

#' Label and metadata for the chosen indicator
#'
#' Returns a list with display names and units used everywhere
#' downstream (axis labels, table headers, LLM prompts, file
#' naming).
#'
#' @param indicator_type "poverty" or "mean_welfare"
#' @param fgt_alpha integer 0/1/2; only used for the poverty branch
#' @param log_transform logical; only used for the mean_welfare branch
#' @param currency_symbol short currency unit shown next to numbers
indicator_label <- function(indicator_type = "poverty",
                            fgt_alpha = 0L,
                            log_transform = FALSE,
                            currency_symbol = "EUR") {
  indicator_type <- match.arg(indicator_type, c("poverty", "mean_welfare"))
  if (indicator_type == "poverty") {
    out <- fgt_label(fgt_alpha)
    out$indicator_type   <- "poverty"
    out$is_rate          <- TRUE
    out$units            <- ""
    out$short_indicator  <- "pov"
    out$value_format_fn  <- function(x) format(round(x, 4), nsmall = 4, trim = TRUE)
    return(out)
  }
  # mean_welfare
  unit_suffix <- if (nzchar(currency_symbol)) paste0(" (", currency_symbol, ")") else ""
  list(
    fgt              = NA_character_,
    short            = if (log_transform) "Mean welfare (log-fit, back-transformed)" else "Mean welfare",
    noun_singular    = "mean welfare",
    noun_plural      = "mean welfare values",
    axis_label       = paste0("Mean welfare", unit_suffix),
    indicator_type   = "mean_welfare",
    is_rate          = FALSE,
    units            = currency_symbol,
    short_indicator  = "mean",
    log_transform    = isTRUE(log_transform),
    value_format_fn  = function(x) format(round(x, 1), nsmall = 1, big.mark = ",", trim = TRUE)
  )
}

#' Build the per-observation target for direct estimation
#'
#' For "poverty" this returns the FGT(α) indicator. For
#' "mean_welfare" it always returns welfare, including zero/negative
#' values. When requested, log transformation is applied to the
#' arithmetic direct area mean after aggregation, never to microdata.
#'
#' @param survey_dt Data frame with at least `welfare` and (for
#'   poverty) `povline`.
#' @param indicator_type "poverty" or "mean_welfare"
#' @param fgt_alpha integer 0/1/2 for poverty
#' @param log_transform retained for compatibility; the per-observation
#'   target is unchanged because logging occurs after direct estimation.
#' @param compute_fgt FGT helper from ufh_functions.R; passed in to
#'   avoid an order-of-source dependency.
#' @return Numeric vector aligned with `survey_dt`.
build_target_column <- function(survey_dt,
                                indicator_type = "poverty",
                                fgt_alpha = 0L,
                                log_transform = FALSE,
                                compute_fgt_fn = NULL) {
  indicator_type <- match.arg(indicator_type, c("poverty", "mean_welfare"))
  if (indicator_type == "poverty") {
    if (is.null(compute_fgt_fn)) {
      if (exists("compute_fgt", mode = "function")) {
        compute_fgt_fn <- get("compute_fgt", mode = "function")
      } else {
        stop("build_target_column: compute_fgt() not available; pass compute_fgt_fn explicitly.")
      }
    }
    return(compute_fgt_fn(survey_dt$welfare, survey_dt$povline, fgt_alpha))
  }
  as.numeric(survey_dt$welfare)
}

#' Whether arcsin transformation is sensible for the chosen indicator
#'
#' Arcsin is only valid on [0, 1]. This is used to gate the UFH
#' transformation option.
indicator_supports_arcsin <- function(indicator_type = "poverty") {
  identical(indicator_type, "poverty")
}

#' MSE / variance of the difference between two estimates
#'
#' For UFH (univariate FH) the cross-time covariance is taken to be 0
#' (independent fits per year). For MFH the bootstrap MCPE between
#' time pairs is available and should be passed in.
#'
#' Used to test "significant change" in any indicator (rate, mean,
#' or back-transformed mean) without duplicating logic across the
#' pipeline.
mse_of_change <- function(mse_t1, mse_t2, mcpe_t1_t2 = 0) {
  pmax(mse_t1 + mse_t2 - 2 * mcpe_t1_t2, 0)
}

#' Build a friendly indicator-aware filename suffix
#'
#' Used so that running the package twice with different indicators
#' does not silently overwrite results in output/.
indicator_filename_tag <- function(indicator_type = "poverty",
                                   fgt_alpha = 0L,
                                   log_transform = FALSE) {
  if (identical(indicator_type, "poverty")) {
    return(paste0("pov_fgt", as.integer(fgt_alpha %||% 0L)))
  }
  if (isTRUE(log_transform)) "mean_log" else "mean"
}
