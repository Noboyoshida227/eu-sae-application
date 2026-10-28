# Compare isolated, identical-input w5p integrations. No production writes.
# Rscript <this file> earlier-sm_out-root new-sm_out-root new-default-root output-dir
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 4L)
old_root <- args[1L]; compatible_root <- args[2L]; default_root <- args[3L]
output_dir <- args[4L]
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
read_table <- function(root, scenario, name) {
  as.data.frame(readxl::read_excel(file.path(root, scenario, "outputs", "data", name)))
}
for (input in c("households.csv", "persons.csv", "auxiliary.csv", "geometry.geojson", "external_targets.csv")) {
  hashes <- vapply(c(old_root, compatible_root, default_root), function(root)
    unname(tools::md5sum(file.path(root, "fixtures", input))), character(1L))
  stopifnot(length(unique(hashes)) == 1L)
}
normalize_config <- function(x) {
  if (is.list(x)) {
    if (!is.null(names(x))) x <- x[order(names(x))]
    return(lapply(x, normalize_config))
  }
  if (is.character(x)) x <- sub("^.*[/\\\\](households.csv|persons.csv|auxiliary.csv|geometry.geojson|external_targets.csv)$", "\\1", x)
  x
}
old_cfg <- yaml::read_yaml(file.path(old_root, "poverty", "integration_config.yml"))
new_cfg <- yaml::read_yaml(file.path(compatible_root, "poverty", "integration_config.yml"))
stopifnot(isTRUE(all.equal(normalize_config(old_cfg), normalize_config(new_cfg), tolerance = 0)))
compatibility <- list()
for (name in c("pov_fh.xlsx", "pov_mfh.xlsx", "statistical_significance_comparison.xlsx", "pov_comparison_detailed.xlsx")) {
  old <- read_table(old_root, "poverty", name)
  current <- read_table(compatible_root, "poverty", name)
  stopifnot(isTRUE(all.equal(old, current, tolerance = 1e-8)))
  compatibility[[name]] <- data.frame(file = name, rows = nrow(old), columns = ncol(old),
                                      tolerance = 1e-8, result = "MATCH")
}
write.csv(do.call(rbind, compatibility), file.path(output_dir, "explicit_sm_out_compatibility.csv"), row.names = FALSE)
deltas <- list()
for (scenario in c("poverty", "log")) {
  a <- read_table(old_root, scenario, "pov_fh.xlsx")
  b <- read_table(default_root, scenario, "pov_fh.xlsx")
  index <- match(paste(a$domain, a$year), paste(b$domain, b$year))
  stopifnot(!anyNA(index)); b <- b[index, ]
  stopifnot(isTRUE(all.equal(a$Direct_MSE, b$Direct_MSE, tolerance = 1e-10)))
  d <- data.frame(scenario = scenario, domain = a$domain, year = a$year,
                  sm_out_UFH = a$FH, sm_all_UFH = b$FH,
                  sm_out_UFH_MSE = a$FH_MSE, sm_all_UFH_MSE = b$FH_MSE)
  a <- read_table(old_root, scenario, "pov_mfh.xlsx")
  b <- read_table(default_root, scenario, "pov_mfh.xlsx")
  index <- match(paste(d$domain, d$year), paste(a$domain, a$year)); a <- a[index, ]
  index <- match(paste(d$domain, d$year), paste(b$domain, b$year)); b <- b[index, ]
  stopifnot(!anyNA(index), isTRUE(all.equal(a$direct_mse, b$direct_mse, tolerance = 1e-10)))
  d$sm_out_MFH <- a$rate_MFH2; d$sm_all_MFH <- b$rate_MFH2
  d$sm_out_MFH_MSE <- a$mse_MFH2; d$sm_all_MFH_MSE <- b$mse_MFH2
  deltas[[scenario]] <- d
}
delta <- do.call(rbind, deltas)
write.csv(delta, file.path(output_dir, "sm_all_vs_sm_out_results.csv"), row.names = FALSE)
summaries <- list()
for (s in unique(delta$scenario)) for (field in c("UFH", "UFH_MSE", "MFH", "MFH_MSE")) {
  d <- delta[delta$scenario == s, ]; change <- d[[paste0("sm_all_", field)]] - d[[paste0("sm_out_", field)]]
  summaries[[paste(s, field)]] <- data.frame(scenario = s, field = field, domain_years = nrow(d),
    changed_above_1e_10 = sum(abs(change) > 1e-10), max_absolute_change = max(abs(change)))
}
write.csv(do.call(rbind, summaries), file.path(output_dir, "policy_change_summary.csv"), row.names = FALSE)
print(do.call(rbind, compatibility), row.names = FALSE)
print(do.call(rbind, summaries), row.names = FALSE)
cat("PASS identical-input explicit-sm_out continuity and unchanged raw Direct uncertainty\n")
