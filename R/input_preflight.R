# Read-only checks shared by readiness, the background driver and direct steps.
# Call before any output cleanup. Survey/auxiliary columns must be harmonized.
sae_resolve_method_input_config <- function(config, method) {
  # Saved configurations and estimation must consume exactly the same inputs.
  # Blank legacy/per-method settings mean unspecified, not an empty override.
  first_set <- function(...) {
    for (value in list(...)) {
      if (is.null(value) || !length(value)) next
      if (length(value) == 1L && (is.na(value) ||
          (is.character(value) && !nzchar(trimws(value))))) next
      return(value)
    }
    ""
  }
  mc <- config[[method]]
  if (is.null(mc)) mc <- list()
  raw_years <- first_set(mc$years_keep, config$years_keep, c(2012L, 2013L))
  year_tokens <- trimws(unlist(strsplit(as.character(unlist(raw_years)), ",", fixed = TRUE)))
  years <- suppressWarnings(as.integer(year_tokens))
  if (length(years) != 2L || anyNA(years) || anyDuplicated(years)) {
    stop(method, ".years_keep must resolve to exactly two distinct years.", call. = FALSE)
  }
  mc$years_keep <- sort(years)
  mc$population_path <- first_set(mc$population_path, "")
  mc$benchmark_target_path <- first_set(mc$benchmark_target_path,
    mc$regional_benchmark_path, config$benchmarking$target_path, "")
  level <- first_set(mc$benchmark_level, config$benchmarking$level, "national")
  if (!level %in% c("national", "custom", "region")) level <- "national"
  level_var <- trimws(as.character(first_set(mc$benchmark_level_variable,
    config$benchmarking$level_variable, mc$var_map$benchmark_level,
    mc$var_map$region, "")))
  if (identical(level, "region") && !nzchar(level_var)) level_var <- "region"
  if (identical(level, "custom") && !nzchar(level_var)) level <- "national"
  mc$benchmark_level <- level
  mc$benchmark_level_variable <- if (identical(level, "national")) "" else level_var
  mc$rhs_domain <- first_set(mc$rhs_domain, mc$var_map$domain, "prov")
  mc
}

sae_missing_mfh_direct_cells <- function(survey, auxiliary, years,
                                         indicator_type = "poverty", fgt_alpha = 0L) {
  needed <- c("domain", "year", "welfare", "weight", "hh_size",
              if (identical(indicator_type, "poverty")) "povline")
  absent <- setdiff(needed, names(survey))
  if (length(absent)) stop("MFH input check is missing survey column(s): ", paste(absent, collapse = ", "), call. = FALSE)
  if (!all(c("domain", "year") %in% names(auxiliary))) stop("MFH input check requires auxiliary domain/year keys.", call. = FALSE)
  years <- as.character(years)
  sv <- survey[as.character(survey$year) %in% years, , drop = FALSE]
  aux <- auxiliary[as.character(auxiliary$year) %in% years, , drop = FALSE]
  domains <- sort(unique(c(trimws(as.character(sv$domain)), trimws(as.character(aux$domain)))))
  if (!length(domains) || anyNA(domains) || any(!nzchar(domains))) stop("MFH input check requires nonblank domain identifiers.", call. = FALSE)
  cells <- expand.grid(domain = domains, year = years, stringsAsFactors = FALSE)
  welfare <- suppressWarnings(as.numeric(as.character(sv$welfare)))
  target <- welfare
  if (identical(indicator_type, "poverty")) {
    line <- suppressWarnings(as.numeric(as.character(sv$povline)))
    target <- if (fgt_alpha == 0L) as.numeric(welfare < line) else pmax(0, (line - welfare) / line)^fgt_alpha
    target[!is.finite(welfare) | !is.finite(line) | line <= 0] <- NA_real_
  }
  weight <- suppressWarnings(as.numeric(as.character(sv$weight)) * as.numeric(as.character(sv$hh_size)))
  observed <- is.finite(target) & is.finite(weight) & weight > 0
  available <- unique(data.frame(domain = trimws(as.character(sv$domain[observed])),
                                 year = as.character(sv$year[observed]), stringsAsFactors = FALSE))
  present <- merge(cells, available, by = c("domain", "year"))
  keys <- function(x) paste(x$domain, x$year, sep = "\r")
  cells[!keys(cells) %in% keys(present), , drop = FALSE]
}

sae_require_complete_mfh_panel <- function(survey, auxiliary, years,
                                           indicator_type = "poverty", fgt_alpha = 0L) {
  missing <- sae_missing_mfh_direct_cells(survey, auxiliary, years, indicator_type, fgt_alpha)
  if (nrow(missing)) {
    examples <- paste(missing$domain, missing$year, sep = "/")
    stop("MFH requires a complete two-year Direct panel. Missing usable Direct domain/year cell(s): ",
         paste(utils::head(examples, 20L), collapse = ", "),
         if (length(examples) > 20L) ", ..." else "",
         ". MFH cannot estimate this incomplete panel; correct the inputs or choose a supported UFH-only analysis.", call. = FALSE)
  }
  invisible(TRUE)
}

sae_validate_relevant_analysis_inputs <- function(survey, auxiliary, years,
                                                  steps = c("UFH", "MFH"),
                                                  do_benchmark = FALSE,
                                                  population_path = "", target_path = "",
                                                  benchmark_level = "national", level_col = "",
                                                  indicator_type = "poverty", fgt_alpha = 0L) {
  methods <- intersect(toupper(steps), c("UFH", "MFH"))
  if (!length(methods)) return(invisible(TRUE))
  missing_survey <- setdiff(as.character(years), as.character(survey$year))
  missing_auxiliary <- setdiff(as.character(years), as.character(auxiliary$year))
  if (length(missing_survey) || length(missing_auxiliary)) {
    stop("Requested analysis years are missing from inputs. Survey: ",
         paste(missing_survey, collapse = ", "), "; auxiliary: ",
         paste(missing_auxiliary, collapse = ", "), call. = FALSE)
  }
  if ("MFH" %in% methods) sae_require_complete_mfh_panel(survey, auxiliary, years, indicator_type, fgt_alpha)
  if (!isTRUE(do_benchmark)) return(invisible(TRUE))
  sv <- survey[as.character(survey$year) %in% as.character(years), , drop = FALSE]
  aux <- auxiliary[as.character(auxiliary$year) %in% as.character(years), , drop = FALSE]
  national <- identical(benchmark_level, "national")
  if (!national) {
    if (!"region" %in% names(sv)) stop("Grouped benchmarking requires the mapped benchmark-group column.", call. = FALSE)
    sae_stop_on_benchmark_group_conflicts(sv, if (nzchar(level_col)) level_col else "benchmark group", "Input validation")
  }
  # The existing readers consume a complete external matrix for the selected
  # years, including in UFH's annual fits. This does not require observations
  # in both years for UFH-only analyses when benchmarking is disabled.
  domains <- sort(unique(c(as.character(sv$domain), as.character(aux$domain))))
  if (!length(domains)) stop("No domains are available for benchmark input validation.", call. = FALSE)
  sae_population_matrix_from_file(population_path, domains, years)
  groups <- if (national) "national" else trimws(as.character(sv$region[match(domains, as.character(sv$domain))]))
  if (anyNA(groups) || any(!nzchar(groups))) stop("Benchmark groups are missing for required domain(s): ",
    paste(domains[is.na(groups) | !nzchar(groups)], collapse = ", "), call. = FALSE)
  sae_benchmark_targets_from_file(target_path, groups, years, level_col)
  invisible(TRUE)
}
