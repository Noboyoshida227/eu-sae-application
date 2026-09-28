# ============================================================
# test_readiness_tables.R -- Data Readiness tables survive a run
#
# "Check Data Readiness" writes its tables to outputs/tables. The dashboard's
# Run Analysis handler rewrites them from the run's own inputs and then starts
# the background driver (which sets SAE_RUN_DIR). The pipeline's clean-up must
# keep those tables in that case, so they stay in outputs/tables and are
# archived with the run, and must still clear everything for runs started any
# other way.
#
# Run from the package root:  Rscript tests/test_readiness_tables.R
# ============================================================

root <- normalizePath(if (file.exists("app_support.R")) "." else "..",
                      winslash = "/", mustWork = TRUE)
setwd(root)
source("app_support.R")

checks <- 0L
ok <- function(cond, msg) {
  checks <<- checks + 1L
  if (!isTRUE(cond)) stop("FAILED: ", msg, call. = FALSE)
  cat("  ok -", msg, "\n")
}

sandbox <- tempfile("sae_readiness_test_")
dir.create(sandbox)
old_wd <- setwd(sandbox)
old_run_dir <- Sys.getenv("SAE_RUN_DIR", unset = NA)
on.exit({
  setwd(old_wd)
  if (is.na(old_run_dir)) Sys.unsetenv("SAE_RUN_DIR") else Sys.setenv(SAE_RUN_DIR = old_run_dir)
  unlink(sandbox, recursive = TRUE, force = TRUE)
}, add = TRUE)

touch <- function(path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  writeLines("x", path)
}
readiness <- file.path("outputs/tables", .SAE_READINESS_TABLES)
model_outputs <- c("outputs/tables/ufh_selection_diagnostics.csv",
                   "outputs/data/pov_fh.xlsx",
                   "outputs/figures/poverty_maps/map_direct_2013.png",
                   "outputs/logs/ufh_child_output.log",
                   "outputs/final_report.html",
                   "outputs/final_report.docx")
setup <- function() {
  for (p in c(readiness, model_outputs, "outputs/tables/.gitkeep")) touch(p)
}
quiet <- function(...) invisible(NULL)

cat("-- readiness table list --\n")
ok(all(c("aux_covariate_summary.csv", "national_poverty.csv", "domain_poverty_rates.csv",
         "missing_poverty.csv", "domain_consistency.csv", "readiness_messages.txt") %in%
         .SAE_READINESS_TABLES),
   "all files written by assess_data_readiness() are listed")
vc <- readLines(file.path(root, "R/validation_checks.R"), warn = FALSE)
written <- unique(regmatches(vc, regexpr('"[a-z_]+\\.(csv|txt)"', vc)))
written <- gsub('"', "", written)
ok(length(written) > 0 && all(written %in% .SAE_READINESS_TABLES),
   "every table name in validation_checks.R is in the keep list")

cat("-- run launched by the dashboard (SAE_RUN_DIR set) --\n")
setup()
Sys.setenv(SAE_RUN_DIR = file.path(sandbox, "run"))
msg <- NULL
.pipeline_clean_outputs(logger = function(m) msg <<- m)
ok(all(file.exists(readiness)), "Data Readiness tables are kept")
ok(!any(file.exists(model_outputs)), "results of the previous run are removed")
ok(file.exists("outputs/tables/.gitkeep"), ".gitkeep is kept")
ok(grepl("Data Readiness tables kept", msg), "log line says the tables were kept")

cat("-- run started any other way (SAE_RUN_DIR unset) --\n")
setup()
Sys.unsetenv("SAE_RUN_DIR")
.pipeline_clean_outputs(logger = quiet)
ok(!any(file.exists(readiness)), "Data Readiness tables are cleared")
ok(!any(file.exists(model_outputs)), "results of the previous run are removed")

cat("-- explicit argument wins --\n")
setup()
Sys.setenv(SAE_RUN_DIR = file.path(sandbox, "run"))
.pipeline_clean_outputs(logger = quiet, keep_readiness = FALSE)
ok(!any(file.exists(readiness)), "keep_readiness = FALSE clears them even under the driver")

cat("-- stale missing_poverty.csv is removed by a clean readiness check --\n")
ok(any(grepl('unlink(file.path(save_to, "missing_poverty.csv"))', vc, fixed = TRUE)),
   "assess_data_readiness() removes an old missing_poverty.csv when nothing is missing")

cat(sprintf("\nAll %d checks passed.\n", checks))
