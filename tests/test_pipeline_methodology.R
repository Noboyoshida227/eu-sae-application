# Full computation-only integration checks against the bundled Spain example.
# This creates a fresh isolated copy under the system temporary directory.
# The original repository outputs and inputs are never written or removed.
# Run from the repository root:
# Rscript tests/test_pipeline_methodology.R --library=/path/to/R/library
# Optional: --scenario=poverty or --scenario=log; default runs both.
# This checks execution/invariants, not statistical coverage or real survey validity.

args <- commandArgs(trailingOnly = TRUE)
option <- function(name, default) {
  hits <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (length(hits)) sub(paste0("^--", name, "="), "", tail(hits, 1L)) else default
}
library_path <- option("library", "")
if (nzchar(library_path)) .libPaths(c(library_path, .libPaths()))
scenario_option <- option("scenario", "all")
replicates <- as.integer(option("replicates", "50"))
stopifnot(is.finite(replicates), replicates >= 50L)
render_reports <- identical(option("render", "false"), "true")
model_rule <- toupper(option("model", "MFH2"))
stopifnot(model_rule %in% c("MFH2", "MFH3"))
scenarios <- if (scenario_option == "all") c("poverty", "log") else scenario_option
stopifnot(all(scenarios %in% c("poverty", "log")))
repository <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
stopifnot(file.exists(file.path(repository, "scripts", "01_ufh.R")))
dependencies <- c("yaml", "readxl", "writexl", "emdi", "msae", "sf", "survey")
missing <- dependencies[!vapply(dependencies, requireNamespace, quietly = TRUE, FUN.VALUE = logical(1L))]
if (length(missing)) stop("Missing runtime dependencies: ", paste(missing, collapse = ", "))
inputs <- file.path(repository, "Data", "Spain", c("survey.rds", "auxiliary.rds", "shapefile.rds"))
if (!all(file.exists(inputs))) stop("The bundled Spain inputs must be present for this integration check.")
snapshot_outputs <- function() {
  files <- sort(list.files(file.path(repository, "outputs"), recursive = TRUE, full.names = TRUE))
  files <- files[!file.info(files)$isdir]
  tools::md5sum(files)
}
before_outputs <- snapshot_outputs()
scratch_parent <- option("output-parent", Sys.getenv("TEMP", unset = tempdir()))
dir.create(scratch_parent, recursive = TRUE, showWarnings = FALSE)
scratch <- tempfile("eu_sae_methodology_", tmpdir = scratch_parent)
dir.create(scratch, recursive = TRUE)
scratch <- normalizePath(scratch, winslash = "/", mustWork = TRUE)
write.csv(data.frame(path = names(before_outputs), md5 = unname(before_outputs)),
          file.path(scratch, "original_outputs_manifest.csv"), row.names = FALSE)
cat("Isolated integration directory:", scratch, "\n")
rscript <- file.path(R.home("bin"), "Rscript.exe")
if (!file.exists(rscript)) rscript <- file.path(R.home("bin"), "Rscript")
literal <- function(x) paste(capture.output(dput(x)), collapse = "\n")
summary <- list()

for (scenario in scenarios) {
  work <- file.path(scratch, scenario)
  dir.create(work)
  for (directory in c("R", "scripts")) {
    source_dir <- file.path(repository, directory)
    destination <- file.path(work, directory)
    dir.create(destination)
    paths <- list.files(source_dir, full.names = TRUE, recursive = TRUE)
    paths <- paths[!file.info(paths)$isdir]
    for (path in paths) {
      relative <- substring(normalizePath(path, winslash = "/"), nchar(source_dir) + 2L)
      target <- file.path(destination, relative)
      dir.create(dirname(target), showWarnings = FALSE, recursive = TRUE)
      if (!file.copy(path, target)) stop("Could not copy integration source: ", path)
    }
  }
  for (directory in c("data", "tables", "figures", "logs")) {
    dir.create(file.path(work, "outputs", directory), recursive = TRUE)
  }
  for (path in c("report.Rmd", "app_support.R", "VERSION", "WIZARD_VERSION")) {
    stopifnot(file.copy(file.path(repository, path), file.path(work, path)))
  }
  dir.create(file.path(work, "docs"))
  stopifnot(file.copy(file.path(repository, "docs", "report_reference.docx"), file.path(work, "docs")))
  log_run <- identical(scenario, "log")
  shared <- list(
    survey_path = inputs[1L], rhs_path = inputs[2L], shp_path = inputs[3L],
    years_keep = c(2012L, 2013L), rhs_domain = "prov", shp_domain = "prov",
    candidate_vars_y1 = c("gen", "educ1"), candidate_vars_y2 = c("gen", "educ1"),
    lasso_enabled = FALSE, ic_criterion = "none", do_benchmark = log_run,
    benchmark_level = "national", log_transform = log_run, bias_correction = TRUE,
    var_choice = "sm_out")
  cfg <- list(
    country_name = "Spain integration fixture", analysis_seed = 62401L,
    years_keep = c(2012L, 2013L),
    indicator_type = if (log_run) "mean_welfare" else "poverty",
    log_transform = log_run, fgt_alpha = 0L, currency_symbol = "EUR",
    povline_type = "column", povline_value = "povline", change_alpha = 0.05,
    benchmarking = list(enabled = log_run, level = "national"),
    ufh = modifyList(shared, list(transformation = if (log_run) "no" else "arcsin",
                                  bootstrap_nB = replicates)),
    mfh = modifyList(shared, list(diag_model = model_rule, fit_mfh3 = FALSE,
                                  cov_choice = "rho_sm_out", mcpe_nB = replicates,
                                  bench_nB = replicates)))
  config <- file.path(work, "integration_config.yml")
  yaml::write_yaml(cfg, config)
  worker <- file.path(work, "integration_worker.R")
  writeLines(c(
    paste0(".libPaths(", literal(.libPaths()), ")"),
    paste0("setwd(", literal(work), ")"),
    paste0("Sys.setenv(SAE_APP_CONFIG = ", literal(config), ")"),
    "options(error = function() { traceback(30); quit(status = 1L) })",
    "stage <- commandArgs(trailingOnly = TRUE)[1L]",
    "if (stage == '01_ufh') { source('R/release_controls.R'); sae_write_run_metadata(yaml::read_yaml(Sys.getenv('SAE_APP_CONFIG')), config_path = Sys.getenv('SAE_APP_CONFIG')) }",
    "grDevices::pdf(file = file.path('outputs', 'figures', paste0(stage, '_device.pdf')))",
    "if (stage == 'report') {",
    "  source('app_support.R')",
    "  result <- render_final_report(include_ai = FALSE)",
    "  stopifnot(isTRUE(result$rendered), !is.null(result$docx))",
    "} else source(file.path('scripts', paste0(stage, '.R')), echo = FALSE, local = globalenv())",
    "grDevices::dev.off()"), worker)
  for (stage in c("01_ufh", "02_mfh", "03_comparison", if (render_reports) "report")) {
    log <- file.path(work, "outputs", "logs", paste0(stage, ".log"))
    cat("START", scenario, stage, "\n")
    status <- system2(rscript, c("--vanilla", shQuote(worker), stage),
                      stdout = log, stderr = log)
    if (!identical(status, 0L)) {
      cat(paste(tail(readLines(log, warn = FALSE), 70L), collapse = "\n"), "\n")
      stop("Integration stage failed: ", scenario, "/", stage, "; log: ", log)
    }
    cat("PASS", scenario, stage, "\n")
  }
  out <- file.path(work, "outputs")
  ufh <- as.data.frame(readxl::read_excel(file.path(out, "data", "pov_fh.xlsx")))
  mfh <- as.data.frame(readxl::read_excel(file.path(out, "data", "pov_mfh.xlsx")))
  artifacts <- readRDS(file.path(out, "data", "mfh_artifacts.rds"))
  selected <- artifacts$diag_model
  rate_column <- paste0("rate_", selected)
  mse_column <- paste0("mse_", selected)
  stopifnot(identical(artifacts$diag_model_requested, model_rule),
            selected %in% if (model_rule == "MFH2") "MFH2" else c("MFH1", "MFH2", "MFH3"),
            !isTRUE(artifacts$model_fit_failed), !identical(artifacts$inference_valid, FALSE),
            nrow(ufh) == 104L, nrow(mfh) == 104L,
            all(is.finite(ufh$FH)), all(is.finite(ufh$FH_MSE)), all(ufh$FH_MSE >= 0),
            all(is.finite(mfh[[rate_column]])), all(is.finite(mfh[[mse_column]])), all(mfh[[mse_column]] >= 0))
  changes <- read.csv(file.path(out, "tables", "comparison_final.csv"))
  stopifnot(nrow(changes) == 52L, all(is.finite(changes$diff)),
            all(is.finite(changes$mse)), all(changes$mse >= 0),
            all(changes$lb <= changes$ub))
  boot_path <- file.path(out, "data", paste0("mcpe_", tolower(selected), "_obj.rds"))
  stopifnot(file.exists(boot_path))
  boot <- readRDS(boot_path)
  stopifnot(boot$n_success == replicates,
            boot$covariance_boundary_count >= 0L,
            boot$covariance_boundary_count <= boot$n_success,
            identical(artifacts$inference_status, boot$inference_status),
            all(changes$inference_status == artifacts$inference_status),
            all(boot$mcpe[, 1L]^2 <= boot$mse[, 1L] * boot$mse[, 2L] + 1e-8))
  for (tt in seq_len(2L)) {
    rows <- mfh$year == c(2012L, 2013L)[tt]
    index <- match(as.character(mfh$domain[rows]), as.character(boot$domain))
    stopifnot(!anyNA(index),
              isTRUE(all.equal(mfh[[rate_column]][rows], as.numeric(boot$eblup[index, tt]), tolerance = 1e-8)),
              isTRUE(all.equal(mfh[[mse_column]][rows], as.numeric(boot$mse[index, tt]), tolerance = 1e-8)))
  }
  if (log_run) {
    stopifnot(identical(boot$output_scale, "original"),
              all(is.finite(ufh$FH_Bench)), all(is.finite(ufh$FH_Bench_MSE)),
              all(is.finite(mfh$rate_Bench)), all(is.finite(mfh$mse_Bench)))
  }
  comparison <- as.data.frame(readxl::read_excel(file.path(out, "data", "pov_comparison_detailed.xlsx")))
  stopifnot(nrow(comparison) > 0L)
  stopifnot(all(comparison$MFH_inference_status == artifacts$inference_status))
  stopifnot(identical(artifacts$residual_method, "RPR_standardized"))
  residuals <- read.csv(file.path(out, "tables", "mfh_standardized_residuals.csv"))
  normality_values <- read.csv(file.path(out, "tables", "normality_raw_values.csv"))
  normality_tests <- read.csv(file.path(out, "figures", "tables", "normality_tests.csv"))
  for (tt in seq_len(2L)) {
    year <- c(2012L, 2013L)[tt]
    fh_model <- readRDS(file.path(out, "data", paste0("fh_model_y", tt, ".rds")))
    expected_by_method <- list(
      FH = as.numeric(fh_model$model$std_real_residuals),
      MFH = residuals$standardized_residual[residuals$year == year])
    for (method in names(expected_by_method)) {
      expected <- expected_by_method[[method]]
      expected <- expected[is.finite(expected)]
      exported <- normality_values$value[normality_values$method == method &
        normality_values$year == year & normality_values$component == "Residual"]
      test <- normality_tests[normality_tests$method == method &
        normality_tests$year == year & normality_tests$component == "Residual", , drop = FALSE]
      independent <- stats::shapiro.test(expected)
      stopifnot(isTRUE(all.equal(sort(exported), sort(expected), tolerance = 1e-10)),
                nrow(test) == 1L, test$n == length(expected),
                isTRUE(all.equal(as.numeric(test$W), as.numeric(independent$statistic), tolerance = 1e-10)),
                isTRUE(all.equal(as.numeric(test$p_value), as.numeric(independent$p.value), tolerance = 1e-10)))
    }
  }
  cat("PASS", scenario, "comparison normality diagnostics use the fitted standardized residuals\n")
  summary[[scenario]] <- data.frame(scenario = scenario, domains = 52L,
    requested_model = model_rule, selected_model = selected,
    inference_status = artifacts$inference_status,
    ufh_rows = nrow(ufh), mfh_rows = nrow(mfh), comparison_rows = nrow(comparison),
    bootstrap_successes = boot$n_success, bootstrap_failures = boot$fails,
    bootstrap_covariance_boundaries = boot$covariance_boundary_count)
  cat("PASS", scenario, "exported estimates, uncertainty, and joint-error consistency\n")
}
stopifnot(identical(before_outputs, snapshot_outputs()))
cat("PASS original repository outputs are unchanged\n")
print(do.call(rbind, summary), row.names = FALSE)
write.csv(do.call(rbind, summary), file.path(scratch, "integration_summary.csv"), row.names = FALSE)
cat("Review logs and generated test artifacts under:", scratch, "\n")
