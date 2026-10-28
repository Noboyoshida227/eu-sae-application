# Shared population helpers for benchmarking.
#
# If the user supplies a population file, read it as domain-year population
# totals. Otherwise, estimate domain-year populations from the household survey
# using population_weight = weight * household size.

# Read text identifiers without numeric guessing (for example, domain "001").
sae_read_optional_keyed_table <- function(path, label = "Population input") {
  if (is.null(path) || !length(path) || !nzchar(path)) return(NULL)
  if (!file.exists(path)) stop(label, " not found: ", path, call. = FALSE)
  ext <- tolower(tools::file_ext(path))
  if (ext == "rds") return(readRDS(path))
  if (ext %in% c("rda", "rdata")) {
    load_env <- new.env(parent = emptyenv())
    loaded <- load(path, envir = load_env)
    if (length(loaded) != 1L) stop(label, " .RData/.rda file must contain exactly one object.", call. = FALSE)
    return(load_env[[loaded[1L]]])
  }
  if (ext %in% c("csv", "txt")) return(read.csv(path, check.names = FALSE, colClasses = "character"))
  if (ext %in% c("xlsx", "xls")) {
    if (!requireNamespace("readxl", quietly = TRUE)) stop("Package 'readxl' is required to read ", label, ".", call. = FALSE)
    return(readxl::read_excel(path, col_types = "text", .name_repair = "minimal"))
  }
  stop("Unsupported ", label, " format: ", path, call. = FALSE)
}

sae_read_optional_population_table <- function(path) {
  sae_read_optional_keyed_table(path, "Population input")
}

sae_input_key <- function(x) trimws(as.character(x))

sae_require_unique_input_keys <- function(keys, label, grain) {
  keys <- as.data.frame(keys, stringsAsFactors = FALSE)
  if (any(vapply(keys, function(x) anyNA(x) || any(!nzchar(x)), logical(1)))) {
    stop(label, " requires nonmissing, nonblank ", grain, " keys.", call. = FALSE)
  }
  duplicate <- duplicated(keys) | duplicated(keys, fromLast = TRUE)
  if (any(duplicate)) {
    examples <- utils::head(unique(keys[duplicate, , drop = FALSE]), 10L)
    examples <- apply(examples, 1L, paste, collapse = "/")
    stop(label, " requires one row per ", grain, "; duplicate key(s): ",
         paste(examples, collapse = ", "),
         ". Supply aggregate totals/targets at the required grain; sex/age rows are not automatically aggregated.", call. = FALSE)
  }
  invisible(TRUE)
}

# Shared population/target parser. Named matrix years are selected by their
# labels. Additional named years are allowed; unnamed years are positional only
# with an exact column count and an explicit warning.
sae_keyed_input_matrix <- function(obj, ids, years, id_candidates, value_candidates,
                                   prefixes, label, grain, single_id_default = FALSE) {
  ids <- sae_input_key(ids)
  years <- sae_input_key(years)
  sae_require_unique_input_keys(data.frame(id = ids), paste(label, "requested IDs"), grain)
  sae_require_unique_input_keys(data.frame(year = years), paste(label, "requested years"), "year")
  if (is.matrix(obj)) {
    rows <- rownames(obj)
    if (is.null(rows)) stop(label, " matrix must have ", grain, " row names.", call. = FALSE)
    rows <- sae_input_key(rows)
    sae_require_unique_input_keys(data.frame(id = rows), paste(label, "matrix row names"), grain)
    missing_ids <- setdiff(ids, rows)
    if (length(missing_ids)) stop(label, " matrix is missing ", grain, " ID(s): ", paste(missing_ids, collapse = ", "), call. = FALSE)
    cols <- colnames(obj)
    if (is.null(cols) || (length(cols) && !anyNA(cols) && all(!nzchar(trimws(cols))))) {
      if (ncol(obj) != length(years)) stop(label, " unnamed matrix must have exactly one column per analysis year.", call. = FALSE)
      warning(label, " unnamed matrix columns are interpreted in selected analysis-year order: ", paste(years, collapse = ", "), call. = FALSE)
      cols <- years
    } else {
      cols <- sae_input_key(cols)
      sae_require_unique_input_keys(data.frame(year = cols), paste(label, "matrix column labels"), "year")
      missing_years <- setdiff(years, cols)
      if (length(missing_years)) stop(label, " matrix is missing required year label(s): ", paste(missing_years, collapse = ", "), call. = FALSE)
    }
    mat <- obj[match(ids, rows), match(years, cols), drop = FALSE]
    suppressWarnings(storage.mode(mat) <- "double")
    dimnames(mat) <- list(ids, years)
    return(mat)
  }
  df <- as.data.frame(obj, check.names = FALSE)
  nms <- names(df)
  if (anyNA(nms) || any(!nzchar(nms)) || anyDuplicated(tolower(nms))) stop(label, " table requires unique, nonblank column names.", call. = FALSE)
  id_col <- sae_pick_col(nms, id_candidates[nzchar(id_candidates)])
  year_col <- sae_pick_col(nms, c("year", "time", "period"))
  value_col <- sae_pick_col(nms, value_candidates)
  if (is.null(id_col)) {
    if (single_id_default && length(ids) == 1L) {
      id_col <- ".sae_input_id"
      df[[id_col]] <- ids[1L]
    } else stop(label, " table must contain a ", grain, " identifier column.", call. = FALSE)
  }
  row_ids <- sae_input_key(df[[id_col]])
  if (anyNA(row_ids) || any(!nzchar(row_ids))) stop(label, " table contains missing/blank ", grain, " IDs.", call. = FALSE)
  mat <- matrix(NA_real_, length(ids), length(years), dimnames = list(ids, years))
  if (!is.null(year_col) && !is.null(value_col)) {
    row_years <- sae_input_key(df[[year_col]])
    if (anyNA(row_years) || any(!nzchar(row_years))) stop(label, " table contains missing/blank year keys.", call. = FALSE)
    keep <- row_ids %in% ids & row_years %in% years
    sae_require_unique_input_keys(data.frame(id = row_ids[keep], year = row_years[keep]), label, paste0(grain, "-year"))
    for (tt in seq_along(years)) {
      ix <- which(keep & row_years == years[tt])
      mat[match(row_ids[ix], ids), tt] <- suppressWarnings(as.numeric(as.character(df[[value_col]][ix])))
    }
  } else {
    keep <- row_ids %in% ids
    sae_require_unique_input_keys(data.frame(id = row_ids[keep]), label, grain)
    for (tt in seq_along(years)) {
      candidates <- c(years[tt], paste0(prefixes, years[tt]))
      cols <- nms[tolower(nms) %in% tolower(candidates)]
      if (length(cols) != 1L) stop(label, " requires exactly one unambiguous column for year ", years[tt], ".", call. = FALSE)
      mat[, tt] <- suppressWarnings(as.numeric(as.character(df[[cols]][match(ids, row_ids)])))
    }
  }
  mat
}

sae_benchmark_targets_from_file <- function(path, group_vec, years_keep, level_col = "") {
  obj <- sae_read_optional_keyed_table(path, "Benchmark Target Database")
  if (is.null(obj)) return(NULL)
  label <- paste0("Benchmark Target Database [", basename(path), "]")
  mat <- sae_keyed_input_matrix(obj, sort(unique(sae_input_key(group_vec))), years_keep,
    c(level_col, "benchmark_level", "level", "group", "group_id", "region", "reg", "region_id"),
    c("benchmark", "target", "B_r", "benchmark_target", "regional_benchmark", "direct", "direct_rate", "poverty_rate"),
    c("B_r_", "benchmark_", "target_", "direct_", "poor_"), label, "group", single_id_default = TRUE)
  if (any(!is.finite(mat))) {
    cells <- which(!is.finite(mat), arr.ind = TRUE)
    examples <- utils::head(paste(rownames(mat)[cells[, 1]], colnames(mat)[cells[, 2]], sep = "/"), 10L)
    stop(label, " contains missing/non-finite target(s) for group/year: ", paste(examples, collapse = ", "), call. = FALSE)
  }
  mat
}

sae_pick_col <- function(nms, candidates) {
  lower_nms <- tolower(nms)
  hit <- match(tolower(candidates), lower_nms)
  hit <- hit[!is.na(hit)]
  if (length(hit) == 0) NULL else nms[hit[1]]
}

sae_add_population_weight <- function(survey_data,
                                      weight_col = "weight",
                                      hh_size_col = "hh_size",
                                      output_col = "population_weight",
                                      context = "estimation") {
  missing <- c(weight_col, hh_size_col)[!c(weight_col, hh_size_col) %in% names(survey_data)]
  if (length(missing) > 0) {
    stop(
      "Population-weighted ", context, " requires ",
      "population_weight = ", weight_col, " * ", hh_size_col, ". ",
      "Missing required survey column(s): ",
      paste(missing, collapse = ", "),
      ". Map the household-size variable in the app."
    )
  }

  w <- suppressWarnings(as.numeric(survey_data[[weight_col]]))
  h <- suppressWarnings(as.numeric(survey_data[[hh_size_col]]))
  pop_weight <- w * h
  bad <- !is.finite(pop_weight) | pop_weight <= 0
  if (all(bad)) {
    stop(
      "Population-weighted ", context, " could not proceed because all ",
      "computed population weights are missing, non-finite, or non-positive. ",
      "Check ", weight_col, " and ", hh_size_col, "."
    )
  }
  if (any(bad)) {
    stop(
      "Population-weighted ", context, " found ",
      sum(bad), " row(s) with missing, non-finite, or non-positive ",
      "population_weight = ", weight_col, " * ", hh_size_col, ". ",
      "Please clean the weight and household-size columns before running."
    )
  }

  survey_data[[output_col]] <- pop_weight
  survey_data
}

sae_validate_population_matrix <- function(mat, label = "Population") {
  bad <- !is.finite(mat) | mat <= 0
  if (any(bad)) {
    idx <- which(bad, arr.ind = TRUE)
    examples <- utils::head(sprintf(
      "%s/%s",
      rownames(mat)[idx[, 1]],
      colnames(mat)[idx[, 2]]
    ), 10)
    stop(
      label,
      " contains missing, non-finite, or non-positive population totals for ",
      "domain/year cell(s): ",
      paste(examples, collapse = ", "),
      if (nrow(idx) > length(examples)) ", ..." else ""
    )
  }
  mat
}

sae_population_matrix_from_file <- function(path, domain_vec, years_keep) {
  obj <- sae_read_optional_population_table(path)
  if (is.null(obj)) return(NULL)
  label <- paste0("Population input [", basename(path), "]")
  mat <- sae_keyed_input_matrix(obj, domain_vec, years_keep,
    c("domain", "prov", "area", "area_id"), c("Nd", "N_d", "population", "pop", "N"),
    c("Nd_", "N_", "population_", "pop_"), label, "domain")
  sae_validate_population_matrix(mat, label)
}

sae_population_matrix_from_survey <- function(survey_data,
                                              domain_vec,
                                              years_keep,
                                              domain_col = "domain",
                                              year_col = "year",
                                              weight_col = "weight",
                                              hh_size_col = "hh_size") {
  required <- c(domain_col, year_col, weight_col, hh_size_col)
  missing <- required[!required %in% names(survey_data)]
  if (length(missing) > 0) {
    stop(
      "No population file was supplied, so benchmarking must estimate ",
      "domain populations from the survey using weight * household size. ",
      "Missing required survey column(s): ",
      paste(missing, collapse = ", "),
      ". Map the household-size variable in the app or supply a population file."
    )
  }

  domain_chr <- as.character(domain_vec)
  year_chr <- as.character(years_keep)
  mat <- matrix(NA_real_, nrow = length(domain_chr), ncol = length(year_chr),
                dimnames = list(domain_chr, year_chr))

  w <- suppressWarnings(as.numeric(survey_data[[weight_col]]))
  h <- suppressWarnings(as.numeric(survey_data[[hh_size_col]]))
  pop_weight <- w * h
  df <- data.frame(
    domain = as.character(survey_data[[domain_col]]),
    year = as.character(survey_data[[year_col]]),
    pop_weight = pop_weight,
    stringsAsFactors = FALSE
  )
  df <- df[is.finite(df$pop_weight), , drop = FALSE]

  if (nrow(df) == 0) {
    stop("Survey-derived population weights are all missing/non-finite. ",
         "Check the weight and household-size columns.")
  }

  agg <- stats::aggregate(pop_weight ~ domain + year, data = df, FUN = sum)
  for (tt in seq_along(year_chr)) {
    rows <- agg$year == year_chr[tt]
    ids <- agg$domain[rows]
    vals <- agg$pop_weight[rows]
    common <- intersect(domain_chr, ids)
    mat[common, tt] <- vals[match(common, ids)]
  }

  sae_validate_population_matrix(mat, "Survey-derived population totals")
}

sae_resolve_population_matrix <- function(population_path,
                                          survey_data,
                                          domain_vec,
                                          years_keep,
                                          hh_size_col = "hh_size",
                                          context = "benchmarking") {
  if (!is.null(population_path) && length(population_path) > 0 &&
      nzchar(population_path)) {
    mat <- sae_population_matrix_from_file(population_path, domain_vec, years_keep)
    cat("Using external domain population sizes for ", context, ": ",
        population_path, "\n", sep = "")
    return(mat)
  }

  mat <- sae_population_matrix_from_survey(
    survey_data = survey_data,
    domain_vec = domain_vec,
    years_keep = years_keep,
    hh_size_col = hh_size_col
  )
  cat("No population file supplied; estimated domain populations for ",
      context, " as sum(weight * household size) by domain/year ",
      "(household size is 1 when each survey row is a person).\n", sep = "")
  mat
}
