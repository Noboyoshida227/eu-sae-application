# R1/R2/R4: shared readers and rejection before any result cleanup.
# Run from the repository root with the application R library configured.
local({
  source("scripts/population_helpers.R", local = TRUE)
  source("R/pipeline_helpers.R", local = TRUE)
  source("R/input_paths.R", local = TRUE)
  source("R/input_preflight.R", local = TRUE)
  source("R/validation_checks.R", local = TRUE)
  checks <- 0L
  check <- function(value, label) {
    if (!isTRUE(value)) stop("FAIL - ", label, call. = FALSE)
    checks <<- checks + 1L
    cat("PASS -", label, "\n")
  }
  error_text <- function(expr) tryCatch({ force(expr); "" }, error = function(e) conditionMessage(e))
  work <- tempfile("w5p_inputs_")
  dir.create(work)
  on.exit(unlink(work, recursive = TRUE), add = TRUE)
  years <- c(2012L, 2013L)
  path <- file.path(work, "input.rds")
  put <- function(x) { saveRDS(x, path); path }
  target <- function(x, groups = c("001", "002")) sae_benchmark_targets_from_file(put(x), groups, years)
  pop <- function(x) sae_population_matrix_from_file(put(x), c("001", "002"), years)
  mat <- matrix(c(.30, .40, .20, .10), 2L,
                dimnames = list(c("001", "002"), c("2013", "2012")))
  expected <- mat[, c("2012", "2013")]
  check(identical(target(mat), expected), "targets select reversed matrix year names")
  check(identical(target(mat[2:1, ]), expected), "target rows match IDs, not order")
  check(identical(target(cbind(mat, `2011` = .9)), expected), "extra named years are selected explicitly")
  pm <- matrix(c(10, 90, 90, 10), 2L, dimnames = dimnames(mat))
  check(abs(weighted.mean(c(.1, .5), pop(pm)[, "2012"]) - .14) < 1e-12,
        "population matching restores reviewed weighted mean 0.14")
  unnamed <- mat; colnames(unnamed) <- NULL
  warnings <- character()
  unnamed_result <- withCallingHandlers(target(unnamed), warning = function(w) {
    warnings <<- c(warnings, conditionMessage(w)); invokeRestart("muffleWarning")
  })
  check(identical(unname(unnamed_result), unname(unnamed)) &&
          any(grepl("selected analysis-year order: 2012, 2013", warnings, fixed = TRUE)),
        "completely unnamed columns retain positional order with warning")
  check(grepl("exactly one", error_text(target(cbind(unnamed, 1)))), "unnamed extra columns are rejected")
  for (labels in list(c("2012", ""), c("2012", NA), c("2012", "2012"), c("2012", "1999"))) {
    x <- mat; colnames(x) <- labels
    check(nzchar(error_text(target(x))) && nzchar(error_text(pop(x))),
          paste("invalid matrix year labels rejected:", paste(labels, collapse = "/")))
  }
  for (labels in list(NULL, c("001", "001"), c("001", ""), c("001", "099"))) {
    x <- mat; rownames(x) <- labels
    check(nzchar(error_text(target(x))) && nzchar(error_text(pop(x))), "invalid matrix row IDs rejected")
  }
  # Actual UFH/MFH wrappers both use the maintained shared parser.
  for (spec in list(c("scripts/01_ufh.R", ".targets_from_optional_benchmark"),
                   c("scripts/02_mfh.R", ".matrix_from_optional_regional_benchmark"))) {
    e <- Filter(function(x) is.call(x) && identical(x[[1]], as.name("<-")) &&
                  identical(as.character(x[[2]]), spec[[2]]), parse(spec[[1]], encoding = "UTF-8"))
    check(length(e) == 1L, paste("target reader is defined once in", spec[[1]]))
    eval(e[[1L]])
    check(identical(get(spec[[2]])(put(mat), c("001", "002"), years), expected),
          paste(spec[[1]], "uses correct matrix matching"))
  }
  long <- expand.grid(group = c("001", "002"), year = years, stringsAsFactors = FALSE)
  long$target <- as.vector(expected)
  longpop <- long; names(longpop)[c(1, 3)] <- c("domain", "population")
  longpop$population <- longpop$population * 1000
  check(identical(target(long[4:1, ]), expected), "unique long target table is row-order invariant")
  check(identical(pop(longpop[4:1, ]), expected * 1000), "unique long population table is row-order invariant")
  for (equal in c(FALSE, TRUE)) {
    dup <- rbind(long, long[1, ]); if (!equal) dup$target[nrow(dup)] <- .9
    dupp <- rbind(longpop, longpop[1, ]); if (!equal) dupp$population[nrow(dupp)] <- 900
    for (reverse in c(FALSE, TRUE)) {
      a <- if (reverse) dup[nrow(dup):1, ] else dup
      b <- if (reverse) dupp[nrow(dupp):1, ] else dupp
      check(grepl("one row per group-year", error_text(target(a)), fixed = TRUE),
            paste("long duplicate targets rejected; equal:", equal, "reverse:", reverse))
      check(grepl("one row per domain-year", error_text(pop(b)), fixed = TRUE),
            paste("long duplicate populations rejected; equal:", equal, "reverse:", reverse))
    }
  }
  wide <- data.frame(group = c("001", "002"), target_2012 = expected[, 1], target_2013 = expected[, 2])
  widepop <- wide; names(widepop) <- c("domain", "population_2012", "population_2013")
  widepop[2:3] <- widepop[2:3] * 1000
  check(identical(target(wide[2:1, ]), expected), "wide targets match names and IDs")
  check(identical(pop(widepop[2:1, ]), expected * 1000), "wide populations match names and IDs")
  check(grepl("duplicate key", error_text(target(rbind(wide, wide[1, ]))), fixed = TRUE), "equal wide target duplicates are rejected")
  check(grepl("duplicate key", error_text(pop(rbind(widepop, widepop[1, ]))), fixed = TRUE), "equal wide population duplicates are rejected")
  normalized <- long; normalized$group[1] <- " 001 "
  check(identical(target(normalized), expected), "identifier normalization trims whitespace without removing zeros")
  csv <- file.path(work, "leading_zero.csv"); write.csv(long, csv, row.names = FALSE)
  check(identical(sae_benchmark_targets_from_file(csv, c("001", "002"), years), expected), "CSV preserves leading-zero IDs")
  write.csv(widepop, csv, row.names = FALSE)
  check(identical(sae_population_matrix_from_file(csv, c("001", "002"), years), expected * 1000), "CSV wide population inputs remain supported")
  if (requireNamespace("writexl", quietly = TRUE) && requireNamespace("readxl", quietly = TRUE)) {
    xlsx <- file.path(work, "inputs.xlsx")
    writexl::write_xlsx(long, xlsx)
    check(identical(sae_benchmark_targets_from_file(xlsx, c("001", "002"), years), expected), "Excel targets preserve text IDs and match year keys")
    writexl::write_xlsx(widepop, xlsx)
    check(identical(sae_population_matrix_from_file(xlsx, c("001", "002"), years), expected * 1000), "Excel wide populations remain supported")
  } else cat("SKIP - Excel reader fixtures require writexl/readxl\n")
  obj <- mat; rdata <- file.path(work, "inputs.RData"); save(obj, file = rdata)
  check(identical(sae_benchmark_targets_from_file(rdata, c("001", "002"), years), expected), "RData matrix follows the same matching policy")
  # 24 domains with D24 absent in year two: MFH blocked, UFH-only allowed.
  auxiliary <- expand.grid(domain = sprintf("D%02d", 1:24), year = years, stringsAsFactors = FALSE)
  auxiliary$x <- rep(1:24, 2)
  survey <- auxiliary[rep(seq_len(nrow(auxiliary)), each = 2L), ]
  survey$welfare <- rep(c(50, 150), nrow(auxiliary)); survey$povline <- 100
  survey$weight <- 1; survey$hh_size <- 1; survey$psu <- seq_len(nrow(survey))
  incomplete <- survey[!(survey$domain == "D24" & survey$year == 2013), ]
  check(identical(sae_missing_mfh_direct_cells(incomplete, auxiliary, years)$domain, "D24"), "missing Direct panel identifies D24")
  check(grepl("D24/2013", error_text(sae_require_complete_mfh_panel(incomplete, auxiliary, years)), fixed = TRUE), "MFH block names affected domain/year")
  check(identical(sae_require_complete_mfh_panel(survey, auxiliary, years), TRUE), "complete MFH panel passes")
  output <- file.path(work, "outputs"); dir.create(output)
  sentinel <- file.path(output, "readiness_messages.txt"); writeLines("existing results", sentinel)
  rr <- assess_data_readiness(incomplete, auxiliary, save_to = output, mfh_requested = TRUE, years_keep = years)
  check(any(grepl("ERROR.*D24/2013", rr$messages)) && identical(readLines(sentinel), "existing results"), "MFH readiness blocks without overwriting existing tables")
  rr <- assess_data_readiness(incomplete, auxiliary, save_to = NULL, mfh_requested = FALSE, years_keep = years)
  check(!any(grepl("complete two-year", rr$messages, fixed = TRUE)), "UFH-only readiness retains supported incomplete-panel behavior")
  missing_file <- file.path(work, "stale_optional.rds")
  check(identical(sae_validate_relevant_analysis_inputs(incomplete, auxiliary, years, steps = "UFH",
    do_benchmark = FALSE, population_path = missing_file, target_path = missing_file), TRUE), "disabled benchmarking ignores stale optional paths")
  check(identical(sae_validate_relevant_analysis_inputs(incomplete, auxiliary, years, steps = "Comparison",
    do_benchmark = TRUE, population_path = missing_file, target_path = missing_file), TRUE), "unused estimation inputs do not block Comparison-only")
  check(grepl("not found", error_text(sae_validate_relevant_analysis_inputs(survey, auxiliary, years,
    steps = "UFH", do_benchmark = TRUE, population_path = missing_file))), "enabled relevant upload fails early")
  # Execute actual saved/background entry with an isolated output sentinel.
  source("app_support.R", local = TRUE)
  sv_path <- file.path(work, "survey.rds"); ax_path <- file.path(work, "aux.rds"); geo_path <- file.path(work, "geo.rds")
  saveRDS(incomplete, sv_path); saveRDS(auxiliary, ax_path); saveRDS(data.frame(domain = auxiliary$domain), geo_path)
  mc <- list(psu_design = "linked", survey_path = sv_path, rhs_path = ax_path, shp_path = geo_path, rhs_domain = "domain",
    var_map = list(domain = "domain", year = "year", welfare = "welfare", povline = "povline", weight = "weight", hh_size = "hh_size", psu = "psu"),
    do_benchmark = FALSE, population_path = missing_file, benchmark_target_path = missing_file)
  cfg <- list(years_keep = years, run = list(steps = "MFH"), mfh = mc)
  cfgpath <- file.path(work, "config.yml")
  check_pipeline_packages <- function(...) invisible(TRUE)
  .pipeline_clean_outputs <- function(...) stop("passed_input_validation", call. = FALSE)
  probe <- function(config) {
    yaml::write_yaml(config, cfgpath)
    error_text(run_pipeline_from_config(cfgpath, render_report = FALSE))
  }
  old <- setwd(work); on.exit(setwd(old), add = TRUE)
  check(grepl("D24/2013", probe(cfg), fixed = TRUE), "background/direct config entry blocks incomplete MFH panel before cleanup")
  check(identical(readLines(sentinel), "existing results"), "background panel rejection preserves existing results")
  cfg$run$steps <- "UFH"; cfg$ufh <- mc
  check(identical(probe(cfg), "passed_input_validation"), "UFH-only saved config ignores unused stale files")
  cfg$ufh$do_benchmark <- TRUE
  check(grepl("Optional input", probe(cfg), fixed = TRUE), "relevant missing upload is rejected before output cleanup")
  cfg$ufh$population_path <- ""; cfg$ufh$benchmark_target_path <- path
  bad <- data.frame(year = c(2012, 2012, 2013), target = c(.2, .9, .3)); saveRDS(bad, path)
  check(grepl("duplicate key", probe(cfg), fixed = TRUE), "saved config rejects duplicate national targets before cleanup")
  check(identical(readLines(sentinel), "existing results"), "invalid upload rejection preserves existing results")
  cfg$ufh$benchmark_target_path <- ""
  cfg$benchmarking <- list(level = "national", target_path = missing_file)
  check(grepl("Optional input", probe(cfg), fixed = TRUE), "empty method target inherits global missing file before cleanup")
  cfg$benchmarking$target_path <- path
  check(grepl("duplicate key", probe(cfg), fixed = TRUE), "empty method target inherits global duplicate keys before cleanup")
  cfg$ufh$regional_benchmark_path <- missing_file
  check(grepl("Optional input", probe(cfg), fixed = TRUE), "empty target falls back consistently to legacy method path")
  cfg$ufh$regional_benchmark_path <- NULL
  cfg$ufh$benchmark_level <- ""; cfg$ufh$benchmark_level_variable <- ""
  cfg$benchmarking$level <- "custom"; cfg$benchmarking$level_variable <- "group_code"
  resolved <- sae_resolve_method_input_config(cfg, "ufh")
  check(identical(resolved$benchmark_level, "custom") &&
        identical(resolved$benchmark_level_variable, "group_code"), "empty method group settings inherit global settings")
  cfg$benchmarking$level_variable <- ""; cfg$ufh$var_map$region <- "legacy_group"
  check(identical(sae_resolve_method_input_config(cfg, "ufh")$benchmark_level_variable, "legacy_group"), "empty group settings fall back to mapped legacy group")
  cfg$ufh$var_map$region <- NULL; cfg$ufh$do_benchmark <- FALSE
  cfg$years_keep <- c(2022L, 2023L)
  for (method in c("ufh", "mfh")) {
    cfg[[method]]$years_keep <- NULL
    check(identical(sae_resolve_method_input_config(cfg, method)$years_keep, cfg$years_keep),
          paste(method, "inherits top-level years when method years are absent"))
  }
  check(grepl("Requested analysis years", probe(cfg), fixed = TRUE), "actual selected years are checked before cleanup even for UFH-only")
  cfg$ufh$years_keep <- c(2012L, 2012L)
  check(grepl("two distinct years", probe(cfg), fixed = TRUE), "duplicate method years fail before cleanup")
  check(identical(readLines(sentinel), "existing results"), "all fallback rejection paths preserve existing results")
  setwd(old)
  cat(sprintf("All %d input/preflight checks passed.\n", checks))
})
