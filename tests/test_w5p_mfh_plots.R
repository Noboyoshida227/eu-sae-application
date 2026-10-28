# Run from the repository root, using R_LIBS_USER if a separate library is needed.
# Optional first argument keeps rendered fixtures in an explicit scratch directory.
source("R/mfh_bootstrap_helpers.R")
source("R/pipeline_helpers.R")
source("R/mfh_change_plots.R")
for (e in parse("scripts/02_mfh.R")) {
  if (is.call(e) && identical(e[[1L]], as.name("<-")) &&
      identical(e[[2L]], as.name("compare_mfh"))) eval(e)
}
checks <- 0L
ok <- function(x, label) {
  if (!isTRUE(x)) stop(label, call. = FALSE)
  checks <<- checks + 1L
  cat("PASS -", label, "\n")
}
pov_lab <- list(short = "Poverty rate")
args <- commandArgs(trailingOnly = TRUE)
out <- if (length(args)) args[1L] else tempfile("w5p_mfh_plots_")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
obj <- list(domain = sprintf("D%02d", 1:8),
            eblup = cbind(rep(.2, 8), seq(.05, .4, length.out = 8)),
            mse = matrix(.001, 8, 2),
            mcpe = matrix(.0002, 8, 1, dimnames = list(NULL, "(1,2)")))
baseline <- compare_mfh(mcpe_obj = obj, year_labels = c(2022, 2023))
for (status in c("regular", "boundary_sensitive", "unavailable")) {
  fixture <- obj
  if (status == "unavailable") fixture$mse[,] <- NA_real_
  warning <- if (status == "boundary_sensitive") sae_mfh_boundary_warning() else ""
  result <- compare_mfh(mcpe_obj = fixture, year_labels = c(2022, 2023),
                        inference_status = status, inference_warning = warning)
  ok(all(result$df$inference_status == status), paste(status, "table status propagated"))
  if (status != "unavailable") {
    fields <- c("diff", "mse", "lb", "ub", "p_value", "significant",
                "p_value_bh", "p_value_bonferroni")
    ok(identical(baseline$df[fields], result$df[fields]),
       paste(status, "plot qualification leaves numeric inference unchanged"))
  } else {
    ok(all(is.na(result$df$significant)), "unavailable joint moments do not gain significance")
  }
  for (bench in c(FALSE, TRUE)) for (hist in c(FALSE, TRUE)) {
    p <- sae_mfh_change_plot(result$df,
         paste(if (bench) "Benchmarked" else "Unbenchmarked", "MFH changes"),
         "Change in poverty rate (2023 - 2022)", status, warning, histogram = hist)
    ok(grepl(if (status == "unavailable") "uncertainty and significance are unavailable" else
               "Exploratory pointwise", p$labels$caption) &&
         grepl("no familywide", p$labels$caption, ignore.case = TRUE),
       "plot states pointwise scope or unavailable uncertainty")
    if (status == "boundary_sensitive") {
      ok(grepl("PROVISIONAL.*boundary-sensitive", p$labels$subtitle) &&
           grepl("Increasing bootstrap draws", p$labels$caption),
         "boundary qualifier and full warning survive standalone export")
      aes_name <- if (hist) "fill" else "colour"
      ok(any(grepl("Provisional", p$scales$get_scales(aes_name)$labels)),
         "boundary legend describes provisional results")
    }
    if (status == "unavailable") ok(grepl("Inference unavailable", p$labels$subtitle),
                                      "unavailable plot explicitly withholds inference")
    ggplot2::ggsave(file.path(out, paste(status, if (bench) "bench" else "unbench",
                                        if (hist) "hist.png" else "points.png", sep = "_")),
                    p, width = if (hist) 10 else 12, height = 6, dpi = 120)
  }
}
pipeline <- paste(readLines("scripts/02_mfh.R", warn = FALSE), collapse = "\n")
ok(!grepl('source(here::here("scripts", "mcpe_functions.R"))', pipeline, fixed = TRUE) &&
     !file.exists("scripts/mcpe_functions.R"), "obsolete bootstrap implementation is retired")
ok(grepl('source(here::here("R", "mfh_bootstrap_helpers.R"))', pipeline, fixed = TRUE) &&
     grepl("library(MASS)", pipeline, fixed = TRUE),
   "required shared engine and existing MASS dependency remain explicit")
cat(checks, "checks passed; plots:", normalizePath(out, winslash = "/"), "\n")
