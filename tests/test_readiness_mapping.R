# Regression: shared source columns must survive mapping in readiness and both
# estimation pipelines; invalid weights must not produce misleading estimates.
# All written fixtures and readiness outputs are isolated in a temporary folder.
source("R/input_readers.R")
source("R/pipeline_helpers.R")
source("R/validation_checks.R")

local({
  checks <- 0L
  ok <- function(value, label) {
    if (!isTRUE(value)) stop("FAILED: ", label, call. = FALSE)
    checks <<- checks + 1L
    cat("PASS -", label, "\n")
  }
  fixture <- tempfile("readiness_mapping_")
  dir.create(fixture)
  on.exit(unlink(fixture, recursive = TRUE), add = TRUE)
  survey <- data.frame(
    year = rep(c(2012L, 2013L), each = 4), prov = rep(c("A", "A", "B", "B"), 2),
    ea_id = 1:8, weight = rep(c(1, 2, 1, 3), 2), hhsize = rep(c(1, 4, 2, 3), 2),
    income = c(90, 110, 70, 130, 95, 120, 105, 85), povline = 100,
    region = rep(c("N", "N", "S", "S"), 2)
  )
  aux <- expand.grid(domain = c("A", "B"), year = c(2012L, 2013L))
  aux$x <- 1:4
  survey_path <- file.path(fixture, "survey.rds")
  aux_path <- file.path(fixture, "aux.rds")
  saveRDS(survey, survey_path)
  saveRDS(aux, aux_path)
  vm <- list(year = "year", domain = "prov", psu = "ea_id", weight = "weight",
             hh_size = "hhsize", welfare = "income", povline = "povline",
             strata = "region", benchmark_level = "region")
  for (src in c("app.R", "app_support.R")) {
    env <- new.env(parent = environment())
    wanted <- c("validate_mapped_input_columns", "load_and_harmonize")
    defs <- Filter(function(x) is.call(x) && identical(x[[1]], as.name("<-")) &&
      as.character(x[[2]]) %in% wanted, parse(src, encoding = "UTF-8"))
    stopifnot(length(defs) == 2L)
    for (d in defs) eval(d, env)
    load <- function(mapping) env$load_and_harmonize(survey_path, aux_path, mapping, "domain")
    good <- load(vm)
    ok(identical(good$survey$strata, survey$region) &&
         identical(good$survey$region, survey$region), paste(src, "retains shared strata and benchmark group"))
    duplicate <- vm
    duplicate$strata <- "hhsize"
    shared <- load(duplicate)
    ok(identical(shared$survey$hh_size, survey$hhsize) &&
         identical(shared$survey$strata, survey$hhsize) &&
         any(grepl("Check the strata mapping", shared$notes, fixed = TRUE)),
       paste(src, "retains household size and warns about the reported duplicate mapping"))
    r <- assess_data_readiness(shared$survey, shared$rhs, save_to = NULL)
    expected <- vapply(c(2012L, 2013L), function(y) {
      d <- survey[survey$year == y, ]
      sum((d$income < d$povline) * d$weight * d$hhsize) / sum(d$weight * d$hhsize)
    }, numeric(1))
    ok(isTRUE(r$estimates_available) && nrow(r$domain_poverty) == 4L &&
         isTRUE(all.equal(r$national_poverty$national_rate, round(expected, 6))),
       paste(src, "matches independently computed person-weighted poverty rates"))
    for (value in list(NULL, "", NA_character_, "absent_column")) {
      invalid <- vm
      invalid$hh_size <- value
      err <- tryCatch({ load(invalid); "" }, error = conditionMessage)
      ok(grepl("Input column mapping error", err, fixed = TRUE) &&
           grepl("hh_size", err, fixed = TRUE), paste(src, "rejects missing household-size mapping", deparse(value)))
    }
    invalid <- vm
    invalid$strata <- "absent_strata"
    ok(inherits(try(load(invalid), silent = TRUE), "try-error"),
       paste(src, "rejects an unavailable selected stratum column"))
  }

  # Run the real mapping blocks, without sourcing pipeline I/O or model fits.
  for (src in c("scripts/01_ufh.R", "scripts/02_mfh.R")) {
    code <- readLines(src, warn = FALSE)
    start <- which(code == "# ---- Harmonize variable names ----")
    finish <- if (grepl("01_ufh", src)) {
      grep("^# When the poverty line is a numeric constant", code)[1L]
    } else grep("^# Mean-welfare runs ignore the poverty line", code)[1L]
    block <- parse(text = code[start:(finish - 1L)])
    for (stratum in c("hhsize", "region", "prov")) {
      env <- new.env(parent = environment())
      env$var_map <- vm
      env$var_map$strata <- stratum
      env$survey_raw <- survey
      env$use_strata <- TRUE
      env$indicator_type <- "poverty"
      env$povline_type <- "column"
      invisible(capture.output(eval(block, env)))
      d <- if (grepl("01_ufh", src)) env$survey_all else env$survey_dt
      ok(identical(d$hh_size, survey$hhsize) && identical(d$strata, survey[[stratum]]) &&
           identical(d$region, survey$region) && identical(d$domain, survey$prov),
         paste(src, "retains all roles with strata mapped to", stratum))
    }
  }
  original <- data.frame(a = 1:2, b = 3:4, keep = 5:6)
  swapped <- sae_apply_column_mapping(original, c(a = "b", b = "a"))
  ok(identical(swapped$a, original$b) && identical(swapped$b, original$a),
     "swapped source names are evaluated simultaneously")
  identity <- sae_apply_column_mapping(original, c(a = "a", strata = "a"))
  ok(identical(identity$a, original$a) && identical(identity$strata, original$a),
     "an unchanged source name can also serve another role")
  invisible(capture.output(collision <- sae_apply_column_mapping(original, c(a = "b"))))
  ok(identical(collision$a, original$b) && identical(collision$a_original, original$a),
     "pre-existing canonical columns remain preserved under an original name")

  output_dir <- file.path(fixture, "diagnostics")
  dir.create(output_dir)
  sentinel <- file.path(output_dir, "national_poverty.csv")
  writeLines("prior valid output", sentinel)
  valid <- good$survey
  missing <- valid
  missing$hh_size <- NULL
  invalid <- valid
  invalid$hh_size[1L] <- 0
  incomplete <- valid
  incomplete$povline <- NULL
  for (d in list(missing, invalid, incomplete)) {
    r <- assess_data_readiness(d, aux, save_to = output_dir)
    ok(identical(r$estimates_available, FALSE) && nrow(r$national_poverty) == 0L &&
         nrow(r$domain_poverty) == 0L && any(grepl("ERROR", r$messages)) &&
         !any(grepl("Test [134]:|Results saved", r$messages)),
       "a blocked readiness check returns no downstream rate or correlation estimates")
    ok(identical(readLines(sentinel), "prior valid output") &&
         identical(list.files(output_dir), "national_poverty.csv"),
       "a blocked readiness check does not overwrite existing outputs")
  }
  cat(sprintf("All %d readiness mapping checks passed.\n", checks))
})
