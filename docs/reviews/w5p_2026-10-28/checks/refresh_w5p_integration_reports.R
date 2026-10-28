# Refresh only the report narration in completed synthetic w5p integrations.
# No estimates are fitted and all numerical result files must retain their hashes.
# Rscript .../refresh_w5p_integration_reports.R <integration-scratch>
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 1L)
root <- normalizePath(".", winslash = "/", mustWork = TRUE)
scratch <- normalizePath(args[1L], winslash = "/", mustWork = TRUE)
stopifnot(startsWith(tolower(scratch), paste0(tolower(root), "/tmp/")))
hash <- function(p) digest::digest(readBin(p, "raw", n = file.info(p)$size), algo = "sha256", serialize = FALSE)
rscript <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")
records <- list()
for (scenario in c("poverty", "log")) {
  work <- file.path(scratch, scenario)
  protected <- list.files(file.path(work, "outputs", "data"), full.names = TRUE, recursive = TRUE)
  protected <- protected[!file.info(protected)$isdir]
  before <- tools::md5sum(protected)
  for (relative in c("report.Rmd", "R/comparison_report_ai.R")) {
    old <- file.path(work, relative); final <- file.path(root, relative)
    records[[paste(scenario, relative)]] <- data.frame(scenario = scenario, path = relative,
      integrated_sha256 = hash(old), final_sha256 = hash(final),
      reason = "Narration only: exploratory pointwise counts and familywide qualification")
    stopifnot(file.copy(final, old, overwrite = TRUE))
  }
  log <- file.path(work, "outputs", "logs", "final_report_refresh.log")
  status <- system2(rscript, c("--vanilla", shQuote(file.path(work, "integration_worker.R")), "report"),
                    stdout = log, stderr = log)
  stopifnot(status == 0L, identical(before, tools::md5sum(protected)))
  html <- paste(readLines(file.path(work, "outputs", "final_report.html"), warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  stopifnot(grepl("Exploratory counts of pointwise-significant domains", html, fixed = TRUE),
            file.exists(file.path(work, "outputs", "final_report.docx")))
  cat("PASS", scenario, "final HTML/Word report narration refreshed; all result-data hashes unchanged\n")
}
write.csv(do.call(rbind, records), file.path(scratch, "final_report_source_receipt.csv"), row.names = FALSE)
