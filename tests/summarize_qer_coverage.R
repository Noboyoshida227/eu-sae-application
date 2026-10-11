# Additional descriptive evidence. Bins below describe observed boundary mass;
# they are not calibrated decision thresholds or changes to the estimator.
out <- "docs/QER/evidence"
tab <- read.csv(file.path(out, "boundary_outer.csv"))
tab <- tab[tab$bootstrap == max(tab$bootstrap), ]
stopifnot(nrow(tab) == read.csv(file.path(out, "boundary_design.csv"))$outer_replicates)
tab$original_fit <- ifelse(tab$fitted_q == 0, "zero variance",
  ifelse(tab$fitted_boundary, "correlation limit", "interior"))
tab$bootstrap_boundary_group <- cut(tab$bootstrap_boundary_fraction,
  breaks = c(-Inf, 0, .10, .50, Inf), labels = c("none", "over 0 to 10%", "over 10 to 50%", "over 50%"))
summarize <- function(key, variable) {
  groups <- split(tab, tab[[variable]], drop = TRUE)
  do.call(rbind, lapply(names(groups), function(name) {
    z <- groups[[name]]
    se <- function(v) sd(v) / sqrt(length(v))
    data.frame(stratification = key, group = name, outer_samples = nrow(z),
      change_coverage = mean(z$change_coverage), change_coverage_mcse = se(z$change_coverage),
      percentage_coverage = mean(z$percentage_coverage), percentage_coverage_mcse = se(z$percentage_coverage),
      level_coverage = mean(z$level_coverage), level_coverage_mcse = se(z$level_coverage),
      mean_bootstrap_boundary_fraction = mean(z$bootstrap_boundary_fraction),
      change_mse_ratio = mean(z$estimated_change_mse) / mean(z$realized_change_mse))
  }))
}
result <- rbind(summarize("Original fit", "original_fit"),
                summarize("Bootstrap boundary fraction", "bootstrap_boundary_group"))
write.csv(result, file.path(out, "boundary_stratification.csv"), row.names = FALSE)
print(result, row.names = FALSE)

paired <- lapply(c("identity", "log_realistic", "log_stress", "boundary"), function(name) {
  z <- read.csv(file.path(out, paste0(name, "_outer.csv")))
  aa <- z[z$bootstrap == 500, ]; bb <- z[z$bootstrap == 1000, ]
  stopifnot(identical(aa$outer, bb$outer))
  data.frame(scenario = name, outer = nrow(aa),
    change_coverage_difference_B1000_minus_B500 = mean(bb$change_coverage - aa$change_coverage),
    paired_mcse_change_coverage_difference = sd(bb$change_coverage - aa$change_coverage) / sqrt(nrow(aa)),
    percentage_coverage_difference_B1000_minus_B500 = mean(bb$percentage_coverage - aa$percentage_coverage),
    paired_mcse_percentage_coverage_difference = sd(bb$percentage_coverage - aa$percentage_coverage) / sqrt(nrow(aa)),
    change_mse_relative_difference = mean(bb$estimated_change_mse) / mean(aa$estimated_change_mse) - 1)
})
write.csv(do.call(rbind, paired), file.path(out, "bootstrap_count_sensitivity.csv"), row.names = FALSE)
