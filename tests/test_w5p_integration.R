# Bounded w5p integration checks: matched synthetic row units, two target types,
# and a same-configuration w5o baseline comparison. No coverage claim.
# This creates a fresh isolated copy under the system temporary directory.
# The original repository outputs and inputs are never written or removed.
# Run from the repository root:
# Rscript tests/test_w5p_integration.R --library=/path/to/R/library
# --baseline-root=<extracted w5o source> enables a third same-config baseline run.
# Optional: --scenario=poverty, --scenario=log, or --scenario=baseline_poverty.
# --variance-policy=default omits variance/covariance keys to exercise runtime defaults.
# Use explicit sm_out/sm_all/direct for policy comparisons and baseline reproduction.
# --verify-existing=<scratch directory> repeats artifact assertions without fitting.
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
baseline_root <- option("baseline-root", "")
existing <- option("verify-existing", "")
verify_only <- nzchar(existing)
variance_policy <- option("variance-policy", "default")
stopifnot(variance_policy %in% c("default", "sm_all", "sm_out", "direct"))
if (nzchar(baseline_root) && identical(variance_policy, "default") && !verify_only)
  stop("For a same-policy baseline comparison, specify --variance-policy explicitly.")
if (scenario_option == "all" && nzchar(baseline_root)) scenarios <- c(scenarios, "baseline_poverty")
if (scenario_option == "all" && verify_only && dir.exists(file.path(existing, "baseline_poverty")) &&
    !"baseline_poverty" %in% scenarios) scenarios <- c(scenarios, "baseline_poverty")
stopifnot(all(scenarios %in% c("poverty", "log", "baseline_poverty")))
repository <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
stopifnot(file.exists(file.path(repository, "scripts", "01_ufh.R")))
dependencies <- c("yaml", "readxl", "writexl", "emdi", "msae", "sf", "survey")
missing <- dependencies[!vapply(dependencies, requireNamespace, quietly = TRUE, FUN.VALUE = logical(1L))]
if (length(missing)) stop("Missing runtime dependencies: ", paste(missing, collapse = ", "))
inputs <- file.path(repository, "Data", "simulated", c("survey_example.csv", "auxiliary_example.csv", "geometry_example.geojson"))
if (!all(file.exists(inputs))) stop("The shipped synthetic inputs are required.")
snapshot_outputs <- function() {
  files <- sort(list.files(file.path(repository, "outputs"), recursive = TRUE, full.names = TRUE))
  files <- files[!file.info(files)$isdir]
  tools::md5sum(files)
}
before_outputs <- snapshot_outputs()
scratch_parent <- option("output-parent", Sys.getenv("TEMP", unset = tempdir()))
dir.create(scratch_parent, recursive = TRUE, showWarnings = FALSE)
scratch <- if (verify_only) existing else tempfile("w5p_integration_", tmpdir = scratch_parent)
if (!verify_only) dir.create(scratch, recursive = TRUE)
scratch <- normalizePath(scratch, winslash = "/", mustWork = TRUE)
if (!verify_only) write.csv(data.frame(path = names(before_outputs), md5 = unname(before_outputs)),
          file.path(scratch, "original_outputs_manifest.csv"), row.names = FALSE)
cat("Isolated integration directory:", scratch, "\n")
policy_record <- file.path(scratch, "integration_policy.txt")
if (verify_only) {
  # Existing pre-default-change fixtures explicitly selected sm_out.
  variance_policy <- if (file.exists(policy_record)) trimws(readLines(policy_record)[1L]) else "sm_out"
} else writeLines(variance_policy, policy_record)
rscript <- file.path(R.home("bin"), "Rscript.exe")
if (!file.exists(rscript)) rscript <- file.path(R.home("bin"), "Rscript")
literal <- function(x) paste(capture.output(dput(x)), collapse = "\n")
summary <- list()
# A person file expands each synthetic household into hhsize persons, each with
# its original household survey weight. Population weights and PSU totals match.
household <- read.csv(inputs[1L]); household$fixture_hh <- seq_len(nrow(household))
person <- household[rep(seq_len(nrow(household)), household$hhsize), ]
person$fixture_person <- ave(person$fixture_hh, person$fixture_hh, FUN = seq_along)
fixture_dir <- file.path(scratch, "fixtures")
if (!verify_only) {
dir.create(fixture_dir)
write.csv(household, file.path(fixture_dir, "households.csv"), row.names = FALSE)
write.csv(person, file.path(fixture_dir, "persons.csv"), row.names = FALSE)
write.csv(read.csv(inputs[2L]), file.path(fixture_dir, "auxiliary.csv"), row.names = FALSE)
stopifnot(file.copy(inputs[3L], file.path(fixture_dir, "geometry.geojson")))
}
suppressPackageStartupMessages(library(survey))
options(survey.lonely.psu = "adjust")
household$population_weight <- household$weight * household$hhsize
person$population_weight <- person$weight
source("scripts/ufh_functions.R")
source("R/pipeline_helpers.R")
parity <- list()
for (outcome in c("FGT0", "FGT1", "FGT2", "welfare")) {
  hh <- household; pp <- person
  hh$strata <- sae_strata_codes(hh$strata, context = "household parity fixture")
  pp$strata <- sae_strata_codes(pp$strata, context = "person parity fixture")
  hh$y <- if (outcome == "welfare") hh$income else compute_fgt(hh$income, hh$povline, as.integer(sub("FGT", "", outcome)))
  pp$y <- if (outcome == "welfare") pp$income else compute_fgt(pp$income, pp$povline, as.integer(sub("FGT", "", outcome)))
  h <- svyby(~y, ~year + domain, svydesign(~psu, strata = ~strata, weights = ~population_weight, data = hh, nest = TRUE), svymean, na.rm = TRUE)
  p <- svyby(~y, ~year + domain, svydesign(~psu, strata = ~strata, weights = ~population_weight, data = pp, nest = TRUE), svymean, na.rm = TRUE)
  stopifnot(isTRUE(all.equal(h$y, p$y, tolerance = 1e-10)),
            isTRUE(all.equal(h$se^2, p$se^2, tolerance = 1e-10)))
  parity[[outcome]] <- data.frame(outcome = outcome,
    max_mean_difference = max(abs(h$y-p$y)), max_variance_difference = max(abs(h$se^2-p$se^2)))
}
write.csv(do.call(rbind, parity), file.path(scratch, "row_unit_direct_parity.csv"), row.names = FALSE)
cat("PASS equivalent household/person design means and variances (FGT0/1/2/welfare)\n")
# Fixed external currency targets differ by 2% from the same survey aggregate.
target <- aggregate(cbind(total = income * population_weight, population = population_weight) ~ year, person, sum)
targets <- data.frame(region = "national", year = target$year,
                      target = 1.02 * target$total / target$population)
if (!verify_only) write.csv(targets, file.path(fixture_dir, "external_targets.csv"), row.names = FALSE)

for (scenario in scenarios) {
  work <- file.path(scratch, scenario)
  log_run <- identical(scenario, "log")
  if (!verify_only) {
  source_root <- if (scenario == "baseline_poverty") normalizePath(baseline_root, winslash = "/", mustWork = TRUE) else repository
  dir.create(work)
  for (directory in c("R", "scripts")) {
    source_dir <- file.path(source_root, directory)
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
    stopifnot(file.copy(file.path(source_root, path), file.path(work, path)))
  }
  dir.create(file.path(work, "docs", "templates"), recursive = TRUE)
  stopifnot(file.copy(file.path(source_root, "docs", "templates", "report_reference.docx"), file.path(work, "docs", "templates")))
  log_run <- identical(scenario, "log")
  shared <- list(
    survey_path = file.path(fixture_dir, if (log_run) "persons.csv" else "households.csv"),
    rhs_path = file.path(fixture_dir, "auxiliary.csv"), shp_path = file.path(fixture_dir, "geometry.geojson"),
    var_map = list(year = "year", domain = "domain", psu = "psu", strata = "strata",
                   weight = "weight", welfare = "income", hh_size = "hhsize",
                   povline = "povline", survey_unit = if (log_run) "person" else "household"),
    benchmark_target_path = if (log_run) file.path(fixture_dir, "external_targets.csv") else "",
    years_keep = c(2022L, 2023L), rhs_domain = "domain", shp_domain = "domain",
    candidate_vars_y1 = c("educ_secondary", "unemp_rate"), candidate_vars_y2 = c("educ_secondary", "unemp_rate"),
    lasso_enabled = FALSE, ic_criterion = "none", do_benchmark = TRUE,
    benchmark_level = "national", log_transform = log_run, bias_correction = TRUE)
  if (!identical(variance_policy, "default")) shared$var_choice <- variance_policy
  cfg <- list(
    country_name = "Synthetic w5p integration fixture", analysis_seed = 62401L,
    years_keep = c(2022L, 2023L),
    indicator_type = if (log_run) "mean_welfare" else "poverty",
    log_transform = log_run, fgt_alpha = 1L, currency_symbol = "EUR",
    povline_type = "column", povline_value = "povline", change_alpha = 0.05,
    benchmarking = list(enabled = TRUE, level = "national"),
    ufh = modifyList(shared, list(transformation = "no",
                                  bootstrap_nB = replicates)),
    mfh = modifyList(shared, list(diag_model = model_rule, fit_mfh3 = FALSE,
                                  mcpe_nB = replicates,
                                  bench_nB = replicates)))
  if (!identical(variance_policy, "default"))
    cfg$mfh$cov_choice <- switch(variance_policy, sm_all = "rho_sm_all", sm_out = "rho_sm_out", direct = "rho_dir")
  config <- file.path(work, "integration_config.yml")
  yaml::write_yaml(cfg, config)
  worker <- file.path(work, "integration_worker.R")
  writeLines(c(
    paste0(".libPaths(", literal(.libPaths()), ")"),
    paste0("setwd(", literal(work), ")"),
    paste0("Sys.setenv(SAE_APP_CONFIG = ", literal(config), ")"),
    "options(warn = 1, error = function() { traceback(30); quit(status = 1L) })",
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
  }
  out <- file.path(work, "outputs")
  ufh <- as.data.frame(readxl::read_excel(file.path(out, "data", "pov_fh.xlsx")))
  mfh <- as.data.frame(readxl::read_excel(file.path(out, "data", "pov_mfh.xlsx")))
  artifacts <- readRDS(file.path(out, "data", "mfh_artifacts.rds"))
  expected_variance <- if (identical(variance_policy, "default")) "sm_all" else variance_policy
  expected_covariance <- switch(expected_variance, sm_all = "rho_sm_all", sm_out = "rho_sm_out", direct = "rho_dir")
  stopifnot(identical(artifacts$var_choice, expected_variance),
            identical(artifacts$cov_choice, expected_covariance))
  if (scenario != "baseline_poverty") {
    variance_audit <- read.csv(file.path(out, "tables", "ufh_variance_audit.csv"))
    stopifnot(nrow(variance_audit) == 80L,
              all(variance_audit$variance_policy == expected_variance),
              all(variance_audit$working_scale == if (log_run) "log" else "identity"),
              all(is.finite(variance_audit$working_variance)),
              all(variance_audit$working_variance > 0))
    if (identical(variance_policy, "default")) {
      saved_cfg <- yaml::read_yaml(file.path(work, "integration_config.yml"))
      stopifnot(is.null(saved_cfg$ufh$var_choice), is.null(saved_cfg$mfh$var_choice),
                is.null(saved_cfg$mfh$cov_choice))
    }
  }
  selected <- artifacts$diag_model
  rate_column <- paste0("rate_", selected)
  mse_column <- paste0("mse_", selected)
  stopifnot(identical(artifacts$diag_model_requested, model_rule),
            selected %in% if (model_rule == "MFH2") "MFH2" else c("MFH1", "MFH2", "MFH3"),
            !isTRUE(artifacts$model_fit_failed), !identical(artifacts$inference_valid, FALSE),
            nrow(ufh) == 80L, nrow(mfh) == 80L,
            all(is.finite(ufh$FH)), all(is.finite(ufh$FH_MSE)), all(ufh$FH_MSE >= 0),
            all(is.finite(mfh[[rate_column]])), all(is.finite(mfh[[mse_column]])), all(mfh[[mse_column]] >= 0))
  changes <- read.csv(file.path(out, "tables", "comparison_final.csv"))
  stopifnot(nrow(changes) == 40L, all(is.finite(changes$diff)),
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
    rows <- mfh$year == c(2022L, 2023L)[tt]
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
    year <- c(2022L, 2023L)[tt]
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
  # The baseline intentionally retains its mislabeled UFH Direct MSE; the
  # repaired candidate must agree with the actual MFH survey-design variance.
  direct_column <- if ("direct_mse" %in% names(mfh)) "direct_mse" else stop("Missing MFH Direct MSE")
  idx <- match(paste(ufh$domain, ufh$year), paste(mfh$domain, mfh$year))
  if (scenario != "baseline_poverty") stopifnot(isTRUE(all.equal(ufh$Direct_MSE, mfh[[direct_column]][idx], tolerance = 1e-8)))
  # Benchmark constraints in reported units, for both survey and fixed targets.
  for (yr in c(2022L, 2023L)) {
    rows <- mfh$year == yr
    hh <- household[household$year == yr, ]
    Nd <- aggregate(population_weight ~ domain, hh, sum)
    w <- Nd$population_weight[match(mfh$domain[rows], Nd$domain)]
    B <- if (log_run) targets$target[targets$year == yr] else
      weighted.mean(compute_fgt(hh$income, hh$povline, 1L), hh$population_weight)
    stopifnot(abs(weighted.mean(mfh$rate_Bench[rows], w) - B) < 1e-6)
    uu <- ufh[ufh$year == yr, ]; uw <- Nd$population_weight[match(uu$domain, Nd$domain)]
    stopifnot(abs(weighted.mean(uu$FH_Bench, uw) - B) < 1e-6)
  }
  summary[[scenario]] <- data.frame(scenario = scenario, domains = 40L,
    configured_variance_policy = variance_policy,
    effective_variance_policy = expected_variance, effective_covariance_policy = expected_covariance,
    requested_model = model_rule, selected_model = selected,
    inference_status = artifacts$inference_status,
    ufh_rows = nrow(ufh), mfh_rows = nrow(mfh), comparison_rows = nrow(comparison),
    bootstrap_successes = boot$n_success, bootstrap_failures = boot$fails,
    bootstrap_covariance_boundaries = boot$covariance_boundary_count)
  cat("PASS", scenario, "exported estimates, uncertainty, and joint-error consistency\n")
}
if (all(c("poverty", "baseline_poverty") %in% names(summary))) {
  old <- as.data.frame(readxl::read_excel(file.path(scratch, "baseline_poverty", "outputs", "data", "pov_fh.xlsx")))
  new <- as.data.frame(readxl::read_excel(file.path(scratch, "poverty", "outputs", "data", "pov_fh.xlsx")))
  fields <- c("FH", "FH_MSE", "FH_Bench", "FH_Bench_MSE")
  stopifnot(isTRUE(all.equal(old[fields], new[fields], tolerance = 1e-8)))
  delta <- data.frame(domain = new$domain, year = new$year,
                      w5o_Direct_MSE = old$Direct_MSE, w5p_Direct_MSE = new$Direct_MSE)
  write.csv(delta, file.path(scratch, "baseline_direct_mse_correction.csv"), row.names = FALSE)
  for (file in c("pov_mfh.xlsx", "statistical_significance_comparison.xlsx")) {
    old <- as.data.frame(readxl::read_excel(file.path(scratch, "baseline_poverty", "outputs", "data", file)))
    new <- as.data.frame(readxl::read_excel(file.path(scratch, "poverty", "outputs", "data", file)))
    shared <- intersect(names(old)[vapply(old, is.numeric, logical(1))], names(new))
    stopifnot(isTRUE(all.equal(old[shared], new[shared], tolerance = 1e-8)))
  }
  cat("PASS w5o baseline: unchanged model estimates/uncertainty; raw Direct MSE repair isolated\n")
}
stopifnot(identical(before_outputs, snapshot_outputs()))
cat("PASS original repository outputs are unchanged\n")
print(do.call(rbind, summary), row.names = FALSE)
write.csv(do.call(rbind, summary), file.path(scratch, "integration_summary.csv"), row.names = FALSE)
cat("Review logs and generated test artifacts under:", scratch, "\n")
