# Standalone MFH change plots retain the same inference qualifications as tables.
# This helper changes presentation only; the supplied flags/intervals are untouched.
sae_mfh_change_plot <- function(data, title, y_label, inference_status = "regular",
                                inference_warning = "", model_label = "MFH",
                                alpha = 0.05, histogram = FALSE) {
  stopifnot(is.data.frame(data), all(c("domain", "diff", "significant") %in% names(data)))
  status <- as.character(inference_status)[1L]
  if (is.na(status) || !status %in% c("regular", "boundary_sensitive", "unavailable")) {
    status <- "unavailable"
  }
  boundary <- identical(status, "boundary_sensitive")
  unavailable <- identical(status, "unavailable")
  level <- format(100 * (1 - alpha), trim = TRUE)
  rule <- paste0("Exploratory pointwise results (unadjusted p < ",
                 format(alpha, trim = TRUE), "); no familywide interpretation.")
  interval <- if (histogram) "Bars count domains by their pointwise result." else
    paste0("Bars are approximate pointwise ", level, "% confidence intervals.")
  if (unavailable) {
    rule <- "Point estimates only; uncertainty and significance are unavailable. No familywide interpretation."
    interval <- if (histogram) "Bars count domains by their estimated change." else ""
  }
  warning <- as.character(inference_warning)[1L]
  if (is.na(warning)) warning <- ""
  qualifier <- if (boundary) {
    "PROVISIONAL: boundary-sensitive inference"
  } else if (unavailable) {
    "Inference unavailable: do not interpret points as significance evidence"
  } else {
    paste0(model_label, ": approximate pointwise inference")
  }
  if (boundary && !nzchar(warning)) {
    warning <- "Covariance-boundary fits can understate uncertainty; nominal coverage is not established."
  }
  caption <- paste(c(rule, interval, warning[nzchar(warning)]), collapse = " ")
  caption <- paste(strwrap(caption, width = 115), collapse = "\n")
  labels <- c("Significant" = if (boundary) "Provisional significant" else "Significant",
              "Not Significant" = if (boundary) "Provisional not significant" else "Not significant",
              "Unavailable" = "Unavailable inference")
  # Separate presentation category: never rewrite the exported pointwise flags.
  data$.plot_significance <- ifelse(is.na(data$significant) | unavailable,
                                    "Unavailable", as.character(data$significant))
  data$.plot_significance <- factor(data$.plot_significance, levels = names(labels))
  if (histogram) {
    p <- ggplot2::ggplot(data, ggplot2::aes(x = diff, fill = .plot_significance)) +
      ggplot2::geom_histogram(bins = 20, alpha = 0.7, color = "black", na.rm = TRUE) +
      ggplot2::geom_vline(xintercept = 0, linetype = "dashed", color = "red", linewidth = 1) +
      ggplot2::scale_fill_manual(values = c("Significant" = "coral", "Not Significant" = "lightblue",
                                          "Unavailable" = "gray75"), labels = labels,
                                name = "Pointwise\nresult") +
      ggplot2::labs(x = y_label, y = "Number of domains")
  } else {
    stopifnot(all(c("lb", "ub") %in% names(data)))
    p <- ggplot2::ggplot(data, ggplot2::aes(x = domain, y = diff, color = .plot_significance)) +
      ggplot2::geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
      ggplot2::geom_point(size = 2.5, alpha = 0.7, na.rm = TRUE) +
      ggplot2::geom_errorbar(ggplot2::aes(ymin = lb, ymax = ub), width = 0.3, alpha = 0.5, na.rm = TRUE) +
      ggplot2::scale_color_manual(values = c("Significant" = "red", "Not Significant" = "gray60",
                                           "Unavailable" = "gray75"), labels = labels,
                                 name = "Pointwise\nresult") +
      ggplot2::labs(x = "Domain", y = y_label)
  }
  p + ggplot2::labs(title = title, subtitle = qualifier, caption = caption) +
    ggplot2::theme_minimal() +
    ggplot2::theme(plot.title = ggplot2::element_text(face = "bold", size = 14),
                   plot.subtitle = ggplot2::element_text(size = 11),
                   plot.caption = ggplot2::element_text(size = 9, hjust = 0),
                   legend.position = "right")
}
