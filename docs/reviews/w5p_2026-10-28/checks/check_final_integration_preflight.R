# Recheck final saved-config resolution/preflight against completed isolated
# integrations, without refitting their unchanged estimators or clearing outputs.
# Rscript .../check_final_integration_preflight.R <integration-scratch>
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 1L)
root <- normalizePath(".", winslash = "/", mustWork = TRUE)
scratch <- normalizePath(args[1L], winslash = "/", mustWork = TRUE)
stopifnot(startsWith(tolower(scratch), paste0(tolower(root), "/tmp/")))
source("app_support.R")
expr <- as.list(body(run_pipeline_from_config))[-1L]
stop_at <- which(vapply(expr, function(e) is.call(e) && identical(e[[1L]], as.name("<-")) &&
                           identical(e[[2L]], as.name("old_cfg")), logical(1)))[1L]
stopifnot(is.finite(stop_at), stop_at > 1L)
preflight <- run_pipeline_from_config
body(preflight) <- as.call(c(list(as.name("{")), expr[seq_len(stop_at - 1L)], list(quote(invisible(TRUE)))))
hash <- function(p) digest::digest(readBin(p, "raw", n = file.info(p)$size), algo = "sha256", serialize = FALSE)
records <- list()
for (scenario in c("poverty", "log")) {
  work <- file.path(scratch, scenario)
  cfg <- yaml::read_yaml(file.path(work, "integration_config.yml"))
  cfg$run <- list(steps = c("UFH", "MFH", "Comparison"))
  for (method in c("ufh", "mfh")) {
    resolved <- sae_resolve_method_input_config(cfg, method)
    stopifnot(identical(as.integer(resolved$years_keep), as.integer(cfg[[method]]$years_keep)),
              identical(resolved$benchmark_target_path, cfg[[method]]$benchmark_target_path),
              identical(resolved$benchmark_level, cfg[[method]]$benchmark_level),
              identical(resolved$rhs_domain, cfg[[method]]$rhs_domain),
              identical(resolved$population_path, ""),
              identical(resolved$benchmark_level_variable, ""))
  }
  path <- file.path(work, "final_preflight_config.yml")
  yaml::write_yaml(cfg, path)
  files <- list.files(file.path(work, "outputs"), recursive = TRUE, full.names = TRUE)
  files <- files[!file.info(files)$isdir]
  before <- tools::md5sum(files)
  stopifnot(isTRUE(preflight(path)), identical(before, tools::md5sum(files)))
  cat("PASS", scenario, "final background preflight and effective-config parity; outputs unchanged\n")
  # Keep both original tested-source and final-source hashes, since the final
  # repair only normalizes unspecified saved-config fields, absent in these runs.
  for (relative in c("R/input_preflight.R", "R/validation_checks.R", "app_support.R",
                      "scripts/01_ufh.R", "scripts/02_mfh.R")) {
    old <- file.path(work, relative); final <- file.path(root, relative)
    records[[paste(scenario, relative)]] <- data.frame(scenario = scenario, path = relative,
      integrated_sha256 = hash(old), final_sha256 = hash(final),
      reason = "Final saved-config/preflight resolver; effective inputs identical, no estimator change")
    stopifnot(file.copy(final, old, overwrite = TRUE), identical(hash(old), hash(final)))
  }
}
write.csv(do.call(rbind, records), file.path(scratch, "final_preflight_source_receipt.csv"), row.names = FALSE)
cat("PASS final source snapshot refreshed; integrated result files preserved\n")
