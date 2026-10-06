# Descriptive comparison of unbenchmarked changes, without refitting models.
sae_change_comparison <- function(significance, years, indicator_type = "poverty",
                                  currency_symbol = "EUR", fgt_alpha = 0L,
                                  change_unit = NULL) {
  required <- c("domain", "method", "diff")
  if (!all(required %in% names(significance))) stop("Change comparison lacks domain, method or diff.")
  if (length(years) != 2L || anyNA(years) || years[2] <= years[1]) stop("Changes require two ascending years.")
  multiplier <- if (identical(indicator_type, "poverty")) 100 else 1
  unit <- if (identical(indicator_type, "poverty")) "percentage points" else currency_symbol
  label <- if (!identical(indicator_type, "poverty")) "mean-welfare" else if (fgt_alpha == 0L) "poverty-rate" else sprintf("FGT(%s)", fgt_alpha)
  # Mean-welfare changes given as percentage changes of the mean.
  if (identical(change_unit, "%")) {
    multiplier <- 1
    unit <- "%"
    label <- "mean-welfare percentage"
  }
  extract <- function(method, prefix) {
    d <- as.data.frame(significance[as.character(significance$method) == method, , drop = FALSE])
    d$domain <- trimws(as.character(d$domain))
    if (anyNA(d$domain) || any(!nzchar(d$domain)) || anyDuplicated(d$domain)) stop("Each method must have one nonmissing row per domain.")
    out <- data.frame(domain = d$domain, change = as.numeric(d$diff) * multiplier)
    for (field in intersect(c("lb", "ub", "significant_unadjusted", "significant_bh", "significant_bonferroni"), names(d))) {
      out[[field]] <- if (field %in% c("lb", "ub")) as.numeric(d[[field]]) * multiplier else d[[field]]
    }
    names(out)[-1L] <- paste0(prefix, "_", names(out)[-1L])
    out
  }
  ufh <- extract("FH", "UFH"); mfh <- extract("MFH", "MFH")
  paired <- merge(ufh, mfh, by = "domain", sort = FALSE)
  matched <- nrow(paired)
  paired <- paired[is.finite(paired$UFH_change) & is.finite(paired$MFH_change), , drop = FALSE]
  ord <- suppressWarnings(as.numeric(paired$domain))
  paired <- paired[order(is.na(ord), ord, paired$domain), , drop = FALSE]
  paired$MFH_minus_UFH_change <- paired$MFH_change - paired$UFH_change
  paired$year_from <- rep(years[1], nrow(paired)); paired$year_to <- rep(years[2], nrow(paired))
  paired$unit <- rep(unit, nrow(paired)); paired$benchmark_status <- rep("Unbenchmarked", nrow(paired))
  long <- rbind(data.frame(domain = paired$domain, method = rep("UFH", nrow(paired)), change = paired$UFH_change),
                data.frame(domain = paired$domain, method = rep("MFH", nrow(paired)), change = paired$MFH_change))
  long$method <- factor(long$method, levels = c("UFH", "MFH"))
  summarise_values <- function(x, method) data.frame(
    method = method, domains = length(x),
    minimum = if (length(x)) min(x) else NA_real_,
    percentile_25 = if (length(x)) unname(quantile(x, .25)) else NA_real_,
    median = if (length(x)) median(x) else NA_real_,
    mean = if (length(x)) mean(x) else NA_real_,
    percentile_75 = if (length(x)) unname(quantile(x, .75)) else NA_real_,
    maximum = if (length(x)) max(x) else NA_real_, unit = unit)
  distribution <- rbind(summarise_values(paired$UFH_change, "UFH"), summarise_values(paired$MFH_change, "MFH"))
  gap <- paired$MFH_minus_UFH_change
  summary <- data.frame(
    year_from = years[1], year_to = years[2], matched_domains = matched,
    finite_paired_domains = nrow(paired), excluded_nonfinite_pairs = matched - nrow(paired),
    UFH_only_domains = sum(!ufh$domain %in% mfh$domain),
    MFH_only_domains = sum(!mfh$domain %in% ufh$domain),
    MFH_lower_domains = sum(gap < 0), MFH_higher_domains = sum(gap > 0), equal_domains = sum(gap == 0),
    median_MFH_minus_UFH_change = if (length(gap)) median(gap) else NA_real_,
    mean_MFH_minus_UFH_change = if (length(gap)) mean(gap) else NA_real_,
    # A difference between two percentage changes is in percentage points.
    unit = if (identical(unit, "%")) "percentage points" else unit)
  list(domain = paired, long = long, distribution = distribution, paired = summary,
       label = label, unit = unit, years = years)
}

# ---- Changes and their RMSEs for every method (box plots in the report) ----
# Colours of the five methods in the change/RMSE box plots, by method key:
# a neutral grey for the direct estimates, then the reference categorical
# order (validated for adjacent pairs on a light surface). The method names
# under each box carry the identity as well.
sae_method_colors <- function() {
  c(Direct = "#6b6a65", FH = "#2a78d6", FH_Bench = "#4a3aa7",
    MFH = "#eb6834", MFH_Bench = "#1baf7a")
}

# Domain-level change between the two years and the RMSE of that change, for
# Direct, UFH, UFH benchmarked, MFH and MFH benchmarked (methods whose inputs
# are missing are left out).
#   levels  domain-by-year table with the level estimates and MSEs (columns
#           Direct, Direct_MSE, FH, FH_MSE, ...), as comparison_dt in
#           scripts/03_comparison.R.
#   sig     named list of the steps' change tables (FH, FH_Bench, MFH,
#           MFH_Bench) with domain, diff and mse; for mean welfare, after
#           the conversion to percentage changes, with mse_eur (the MSE of
#           the change in currency units).
#   labels  named display labels, for example c(MFH = "MFH2").
# Poverty indicators: the change is the later minus the earlier rate in
# percentage points and the RMSE is the square root of the change MSE the
# step reports (UFH: years independent; MFH: with the covariance between the
# years). Mean welfare: the change is in ln mean welfare, log(m2 / m1), and the
# RMSE is the delta-method standard error of that log ratio
# (sae_percent_change(), R/pipeline_helpers.R), with the same covariance.
# Direct changes treat the two survey years as independent:
# MSE = MSE(year 1) + MSE(year 2).
sae_change_rmse_by_method <- function(levels, sig, years, indicator_type = "poverty",
                                      fgt_alpha = 0L, labels = NULL) {
  if (length(years) != 2L || anyNA(years)) stop("Changes require two years.")
  years <- sort(as.integer(years))
  is_mean <- identical(indicator_type, "mean_welfare")
  default_labels <- c(Direct = "Direct", FH = "UFH", FH_Bench = "UFH benchmarked",
                      MFH = "MFH", MFH_Bench = "MFH benchmarked")
  if (length(labels)) default_labels[names(labels)] <- labels
  labels <- default_labels
  lv <- as.data.frame(levels)
  lv$domain <- trimws(as.character(lv$domain))
  lv$year <- suppressWarnings(as.integer(lv$year))
  names_col <- intersect(c("geographic_name", "domain_name"), names(lv))
  level_pair <- function(col) {
    if (!all(c(col, paste0(col, "_MSE")) %in% names(lv))) return(NULL)
    y1 <- lv[lv$year == years[1], , drop = FALSE]
    y2 <- lv[lv$year == years[2], , drop = FALSE]
    dom <- intersect(y1$domain, y2$domain)
    if (!length(dom)) return(NULL)
    i1 <- match(dom, y1$domain); i2 <- match(dom, y2$domain)
    data.frame(domain = dom,
               m1 = suppressWarnings(as.numeric(y1[[col]][i1])),
               m2 = suppressWarnings(as.numeric(y2[[col]][i2])),
               s1 = suppressWarnings(as.numeric(y1[[paste0(col, "_MSE")]][i1])),
               s2 = suppressWarnings(as.numeric(y2[[paste0(col, "_MSE")]][i2])),
               stringsAsFactors = FALSE)
  }
  one_method <- function(key) {
    if (identical(key, "Direct")) {
      pr <- level_pair("Direct")
      if (is.null(pr)) return(NULL)
      mse_diff <- pr$s1 + pr$s2
      if (is_mean) {
        pc <- sae_percent_change(pr$m1, pr$m2, pr$s1, pr$s2, mse_diff)
        change <- pc$log_ratio; rmse <- sqrt(pc$log_ratio_var)
      } else {
        change <- 100 * (pr$m2 - pr$m1); rmse <- 100 * sqrt(mse_diff)
      }
      return(data.frame(domain = pr$domain, change = change, rmse = rmse,
                        stringsAsFactors = FALSE))
    }
    d <- sig[[key]]
    if (is.null(d) || !nrow(d) || !all(c("domain", "diff", "mse") %in% names(d))) return(NULL)
    d <- as.data.frame(d)
    d$domain <- trimws(as.character(d$domain))
    if (is_mean) {
      pr <- level_pair(key)
      if (is.null(pr)) return(NULL)
      mse_eur <- if ("mse_eur" %in% names(d)) d$mse_eur else d$mse
      mse_diff <- suppressWarnings(as.numeric(mse_eur))[match(pr$domain, d$domain)]
      # Rows flagged mse_fallback_used use independence, as in the
      # significance table (.to_percent_change() in 03_comparison.R): the
      # change MSE is the sum of the two level MSEs, so the RMSE here equals
      # the standard error behind the percentage-change inference.
      fb <- if ("mse_fallback_used" %in% names(d)) {
        as.logical(d$mse_fallback_used)[match(pr$domain, d$domain)] %in% TRUE
      } else {
        rep(FALSE, nrow(pr))
      }
      mse_diff <- ifelse(fb, pr$s1 + pr$s2, mse_diff)
      keep <- pr$domain %in% d$domain
      pr <- pr[keep, , drop = FALSE]; mse_diff <- mse_diff[keep]
      pc <- sae_percent_change(pr$m1, pr$m2, pr$s1, pr$s2, mse_diff)
      return(data.frame(domain = pr$domain, change = pc$log_ratio,
                        rmse = sqrt(pc$log_ratio_var), stringsAsFactors = FALSE))
    }
    mse <- suppressWarnings(as.numeric(d$mse))
    data.frame(domain = d$domain,
               change = 100 * suppressWarnings(as.numeric(d$diff)),
               rmse = ifelse(is.finite(mse) & mse >= 0, 100 * sqrt(mse), NA_real_),
               stringsAsFactors = FALSE)
  }
  keys <- c("Direct", "FH", "FH_Bench", "MFH", "MFH_Bench")
  parts <- lapply(seq_along(keys), function(k) {
    out <- one_method(keys[k])
    if (is.null(out) || !nrow(out)) return(NULL)
    out <- out[is.finite(out$change) | is.finite(out$rmse), , drop = FALSE]
    if (!nrow(out)) return(NULL)
    out$method_key <- keys[k]
    out$method <- unname(labels[keys[k]])
    out$method_order <- k
    out
  })
  long <- do.call(rbind, parts[!vapply(parts, is.null, logical(1))])
  if (is.null(long)) {
    long <- data.frame(domain = character(), change = numeric(), rmse = numeric(),
                       method_key = character(), method = character(),
                       method_order = integer(), stringsAsFactors = FALSE)
  }
  long$name <- if (length(names_col)) {
    nm <- lv[[names_col[1]]][match(long$domain, lv$domain)]
    ifelse(is.na(nm) | !nzchar(as.character(nm)), long$domain, as.character(nm))
  } else long$domain
  ord <- suppressWarnings(as.numeric(long$domain))
  long <- long[order(long$method_order, is.na(ord), ord, long$domain), , drop = FALSE]
  rownames(long) <- NULL
  noun <- if (is_mean) "ln mean welfare" else
    switch(as.character(fgt_alpha), "1" = "poverty gap", "2" = "poverty severity", "poverty rate")
  unit <- if (is_mean) "log points (ln mean welfare)" else "percentage points"
  change_label <- if (is_mean) sprintf("Change in ln mean welfare, %s to %s", years[1], years[2]) else
    sprintf("Change in %s, %s to %s (percentage points)", noun, years[1], years[2])
  rmse_label <- if (is_mean) "RMSE of the change in ln mean welfare" else
    sprintf("RMSE of the change in %s (percentage points)", noun)
  long$change_label <- rep(change_label, nrow(long))
  long$rmse_label <- rep(rmse_label, nrow(long))
  long$unit <- rep(unit, nrow(long))
  stat <- function(x, f) { x <- x[is.finite(x)]; if (length(x)) f(x) else NA_real_ }
  methods <- unique(long[, c("method_order", "method_key", "method")])
  summary <- do.call(rbind, lapply(seq_len(nrow(methods)), function(k) {
    d <- long[long$method_key == methods$method_key[k], , drop = FALSE]
    data.frame(
      method = methods$method[k],
      domains = sum(is.finite(d$change)),
      change_median = stat(d$change, stats::median),
      change_percentile_25 = stat(d$change, function(x) unname(stats::quantile(x, 0.25))),
      change_percentile_75 = stat(d$change, function(x) unname(stats::quantile(x, 0.75))),
      change_mean = stat(d$change, mean),
      rmse_median = stat(d$rmse, stats::median),
      rmse_percentile_25 = stat(d$rmse, function(x) unname(stats::quantile(x, 0.25))),
      rmse_percentile_75 = stat(d$rmse, function(x) unname(stats::quantile(x, 0.75))),
      rmse_mean = stat(d$rmse, mean),
      unit = unit, stringsAsFactors = FALSE)
  }))
  if (is.null(summary)) summary <- data.frame()
  list(long = long, summary = summary, years = years, change_label = change_label,
       rmse_label = rmse_label, unit = unit, indicator_type = indicator_type)
}

# Static version of the report's box plots (Word report and outputs folder):
# the change and its RMSE side by side in one row, one box per method.
sae_plot_change_rmse_boxplots <- function(x) {
  d <- x$long
  if (is.null(d) || !nrow(d)) return(NULL)
  meth <- unique(d[order(d$method_order), c("method_key", "method")])
  cols <- sae_method_colors()[meth$method_key]
  names(cols) <- meth$method
  panel_names <- c(x$change_label, x$rmse_label)
  long <- rbind(
    data.frame(method = d$method, panel = panel_names[1], value = d$change, stringsAsFactors = FALSE),
    data.frame(method = d$method, panel = panel_names[2], value = d$rmse, stringsAsFactors = FALSE))
  long <- long[is.finite(long$value), , drop = FALSE]
  long$method <- factor(long$method, levels = meth$method)
  long$panel <- factor(long$panel, levels = panel_names)
  zero <- data.frame(panel = factor(panel_names[1], levels = panel_names), y = 0)
  ggplot2::ggplot(long, ggplot2::aes(x = method, y = value, color = method, fill = method)) +
    ggplot2::geom_hline(data = zero, ggplot2::aes(yintercept = y), color = "#64748B",
                        linetype = "dashed", inherit.aes = FALSE) +
    ggplot2::geom_boxplot(width = .55, alpha = .12, outlier.shape = NA, linewidth = .7) +
    ggplot2::geom_point(position = ggplot2::position_jitter(width = .14, height = 0, seed = 123),
                        alpha = .55, size = 1.6) +
    ggplot2::facet_wrap(~panel, nrow = 1, scales = "free_y") +
    ggplot2::scale_color_manual(values = cols) +
    ggplot2::scale_fill_manual(values = cols) +
    ggplot2::scale_x_discrete(labels = function(v) sub(" benchmarked$", "\nbenchmarked", v)) +
    ggplot2::labs(x = NULL, y = NULL,
      title = "Estimated changes and their RMSEs by method",
      caption = paste("Each point is one domain. Boxes show the median and interquartile range;",
                      "whiskers extend to 1.5 times the interquartile range.")) +
    ggplot2::theme_minimal(base_size = 13) +
    ggplot2::theme(legend.position = "none", plot.title = ggplot2::element_text(face = "bold"),
                   strip.text = ggplot2::element_text(face = "bold", size = 12),
                   panel.grid.major.x = ggplot2::element_blank(),
                   panel.spacing = grid::unit(1.5, "lines"))
}

sae_plot_change_paired <- function(comparison) {
  d <- comparison$domain
  if (!nrow(d)) return(NULL)
  d$comparison <- ifelse(d$MFH_minus_UFH_change < 0, "MFH lower", "MFH higher or equal")
  label_rows <- head(order(abs(d$MFH_minus_UFH_change), decreasing = TRUE), 4)
  d$label <- ifelse(seq_len(nrow(d)) %in% label_rows, d$domain, "")
  limits <- range(c(0, d$UFH_change, d$MFH_change)); span <- diff(limits)
  if (!is.finite(span) || span == 0) span <- 1
  limits <- limits + c(-.10, .10) * span
  ggplot2::ggplot(d, ggplot2::aes(x = UFH_change, y = MFH_change)) +
    ggplot2::geom_hline(yintercept = 0, color = "#CBD5E1", linewidth = .4) +
    ggplot2::geom_vline(xintercept = 0, color = "#CBD5E1", linewidth = .4) +
    ggplot2::geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "#64748B") +
    ggplot2::geom_point(ggplot2::aes(color = comparison, shape = comparison), size = 2.8, alpha = .78) +
    ggplot2::geom_text(data = d[nzchar(d$label), , drop = FALSE], ggplot2::aes(label = label),
                       nudge_x = .016 * span, nudge_y = .016 * span, size = 3.5, check_overlap = TRUE) +
    ggplot2::scale_color_manual(values = c(`MFH lower` = "#D97706", `MFH higher or equal` = "#2563EB")) +
    ggplot2::scale_shape_manual(values = c(`MFH lower` = 16, `MFH higher or equal` = 1)) +
    ggplot2::coord_equal(xlim = limits, ylim = limits) +
    ggplot2::labs(title = paste("Domain-level comparison of estimated", comparison$label, "changes"),
      subtitle = sprintf("%s %s %s | %d matched domains | Unbenchmarked\nBelow equality: a lower MFH change estimate", comparison$years[2], if (identical(comparison$unit, "%")) "relative to" else "minus", comparison$years[1], nrow(d)),
      x = sprintf("UFH estimated change (%s)", comparison$unit),
      y = sprintf("MFH estimated change (%s)", comparison$unit), color = NULL, shape = NULL,
      caption = "Negative values indicate a decrease. Labels identify the four largest method gaps.\nA lower estimate does not imply greater accuracy or statistical significance.") +
    ggplot2::theme_minimal(base_size = 14) +
    ggplot2::theme(plot.title = ggplot2::element_text(face = "bold", size = 16), legend.position = "top")
}
