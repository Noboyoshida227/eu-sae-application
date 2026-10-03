# ============================================================
# input_readers.R -- Shared data readers for dashboard inputs
# ============================================================

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) {
    if (is.null(x) || length(x) == 0) y else x
  }
}

sae_file_ext <- function(path) {
  tolower(tools::file_ext(path %||% ""))
}

sae_single_object_from_rdata <- function(path, label = "input file") {
  load_env <- new.env(parent = emptyenv())
  loaded <- load(path, envir = load_env)
  if (length(loaded) != 1) {
    stop(label, " .RData/.rda file must contain exactly one object.", call. = FALSE)
  }
  load_env[[loaded[1]]]
}

sae_simplify_imported_columns <- function(x) {
  x <- as.data.frame(x, stringsAsFactors = FALSE)
  for (col in names(x)) {
    if (inherits(x[[col]], c("haven_labelled", "labelled"))) {
      x[[col]] <- as.vector(x[[col]])
    }
  }
  x
}

sae_accepted_table_formats <- function() {
  c(".rds", ".RData/.rda", ".csv", ".tsv", ".txt", ".dat", ".dta",
    ".sav", ".zsav", ".por", ".sas7bdat", ".xpt",
    ".parquet", ".feather", ".xlsx", ".xls")
}

sae_accepted_table_formats_text <- function() {
  paste(sae_accepted_table_formats(), collapse = ", ")
}

# ---- Text encodings -----------------------------------------------------
# Re-encoding a text file with fileEncoding = "UTF-8" stops at the first byte
# that is not valid UTF-8 and returns the rows read so far with only a warning,
# so a Windows (Latin-1/Windows-1252/1250) CSV with one accented character
# would silently lose every later row. Text inputs are therefore read without
# re-encoding: strings are only marked as UTF-8 when the file is valid UTF-8,
# and as Latin-1 otherwise (every byte is valid Latin-1, so nothing is lost).
# SAE_INPUT_ENCODING, when set, still forces a specific source encoding.
sae_text_encoding_args <- function(path, header_only = FALSE) {
  override <- Sys.getenv("SAE_INPUT_ENCODING", "")
  if (nzchar(override)) return(list(fileEncoding = override))

  size <- suppressWarnings(file.size(path))
  n <- if (is.na(size)) 0 else if (header_only) min(size, 1048576) else size
  bytes <- if (n > 0) readBin(path, what = "raw", n = n) else raw()
  if (length(bytes) >= 2L &&
      (identical(bytes[1:2], as.raw(c(0xFF, 0xFE))) ||
       identical(bytes[1:2], as.raw(c(0xFE, 0xFF))))) {
    return(list(fileEncoding = "UTF-16"))
  }
  if (length(bytes) >= 3L && identical(bytes[1:3], as.raw(c(0xEF, 0xBB, 0xBF)))) {
    bytes <- bytes[-(1:3)]
  }
  if (header_only) {
    newline <- which(bytes == as.raw(0x0A))
    if (length(newline)) bytes <- bytes[seq_len(newline[1])]
  }
  bytes <- bytes[bytes != as.raw(0L)]
  if (!length(bytes) || isTRUE(validUTF8(rawToChar(bytes)))) {
    return(list(encoding = "UTF-8"))
  }
  if (!header_only) {
    warning(
      basename(path), " is not UTF-8 encoded. It is read as Latin-1 so that no ",
      "rows are lost; accented characters in text columns may display ",
      "incorrectly. Save the file as 'CSV UTF-8', or set SAE_INPUT_ENCODING to ",
      "its encoding before launch.",
      call. = FALSE
    )
  }
  list(encoding = "latin1")
}

sae_strip_bom_names <- function(x) {
  nm <- names(x)
  if (length(nm) && !is.na(nm[1])) {
    # Work on bytes so this behaves the same in every locale.
    first <- charToRaw(nm[1])
    if (length(first) >= 3L && identical(first[1:3], as.raw(c(0xEF, 0xBB, 0xBF)))) {
      cleaned <- rawToChar(first[-(1:3)])
      Encoding(cleaned) <- "UTF-8"
      names(x)[1] <- cleaned
    }
  }
  x
}

sae_read_text_table <- function(reader, path, ..., encoding_args = NULL) {
  encoding_args <- encoding_args %||% sae_text_encoding_args(path)
  out <- do.call(reader, c(list(path, ...), encoding_args))
  sae_strip_bom_names(out)
}

sae_read_dat_input <- function(path) {
  encoding_args <- sae_text_encoding_args(path)
  readers <- list(
    tab = function() sae_read_text_table(
      utils::read.delim, path, check.names = FALSE, stringsAsFactors = FALSE,
      encoding_args = encoding_args
    ),
    comma = function() sae_read_text_table(
      utils::read.csv, path, check.names = FALSE, stringsAsFactors = FALSE,
      encoding_args = encoding_args
    ),
    semicolon = function() sae_read_text_table(
      utils::read.table, path, header = TRUE, sep = ";", check.names = FALSE,
      stringsAsFactors = FALSE, quote = "\"", comment.char = "",
      encoding_args = encoding_args
    ),
    whitespace = function() sae_read_text_table(
      utils::read.table, path, header = TRUE, sep = "", check.names = FALSE,
      stringsAsFactors = FALSE, quote = "\"", comment.char = "",
      encoding_args = encoding_args
    )
  )
  candidates <- lapply(readers, function(reader) {
    tryCatch(reader(), error = function(e) NULL)
  })
  candidates <- candidates[!vapply(candidates, is.null, logical(1))]
  if (length(candidates) == 0L) {
    stop(
      "Could not read .dat file as delimited text. Expected a header row and ",
      "a comma, tab, semicolon, or whitespace delimiter.",
      call. = FALSE
    )
  }
  candidates[[which.max(vapply(candidates, ncol, integer(1)))]]
}

sae_read_table_input <- function(path, label = "input file") {
  if (is.null(path) || !nzchar(path %||% "") || !file.exists(path)) {
    stop(label, " does not exist: ", path %||% "(blank)", call. = FALSE)
  }
  ext <- sae_file_ext(path)
  out <- switch(
    ext,
    rds = readRDS(path),
    rda = sae_single_object_from_rdata(path, label),
    rdata = sae_single_object_from_rdata(path, label),
    csv = sae_read_text_table(utils::read.csv, path, check.names = FALSE,
                              stringsAsFactors = FALSE),
    txt = sae_read_text_table(utils::read.csv, path, check.names = FALSE,
                              stringsAsFactors = FALSE),
    tsv = sae_read_text_table(utils::read.delim, path, check.names = FALSE,
                              stringsAsFactors = FALSE),
    dat = sae_read_dat_input(path),
    dta = {
      if (!requireNamespace("haven", quietly = TRUE)) {
        stop("Package 'haven' is required to read Stata .dta files. Run install_packages.R and try again.", call. = FALSE)
      }
      haven::read_dta(path)
    },
    sav = {
      if (!requireNamespace("haven", quietly = TRUE)) {
        stop("Package 'haven' is required to read SPSS .sav/.zsav files. Run install_packages.R and try again.", call. = FALSE)
      }
      haven::read_sav(path)
    },
    zsav = {
      if (!requireNamespace("haven", quietly = TRUE)) {
        stop("Package 'haven' is required to read SPSS .sav/.zsav files. Run install_packages.R and try again.", call. = FALSE)
      }
      haven::read_sav(path)
    },
    por = {
      if (!requireNamespace("haven", quietly = TRUE)) {
        stop("Package 'haven' is required to read SPSS portable .por files. Run install_packages.R and try again.", call. = FALSE)
      }
      haven::read_por(path)
    },
    sas7bdat = {
      if (!requireNamespace("haven", quietly = TRUE)) {
        stop("Package 'haven' is required to read SAS .sas7bdat files. Run install_packages.R and try again.", call. = FALSE)
      }
      haven::read_sas(path)
    },
    xpt = {
      if (!requireNamespace("haven", quietly = TRUE)) {
        stop("Package 'haven' is required to read SAS transport .xpt files. Run install_packages.R and try again.", call. = FALSE)
      }
      haven::read_xpt(path)
    },
    parquet = {
      if (!requireNamespace("arrow", quietly = TRUE)) {
        stop("Package 'arrow' is required to read Python/pandas .parquet files. Run install_packages.R and try again.", call. = FALSE)
      }
      arrow::read_parquet(path)
    },
    feather = {
      if (!requireNamespace("arrow", quietly = TRUE)) {
        stop("Package 'arrow' is required to read Python/pandas .feather files. Run install_packages.R and try again.", call. = FALSE)
      }
      arrow::read_feather(path)
    },
    xlsx = {
      if (!requireNamespace("readxl", quietly = TRUE)) {
        stop("Package 'readxl' is required to read Excel files. Run install_packages.R and try again.", call. = FALSE)
      }
      readxl::read_excel(path)
    },
    xls = {
      if (!requireNamespace("readxl", quietly = TRUE)) {
        stop("Package 'readxl' is required to read Excel files. Run install_packages.R and try again.", call. = FALSE)
      }
      readxl::read_excel(path)
    },
    stop(
      "Unsupported ", label, " format: .", ext,
      ". Accepted tabular formats are ", sae_accepted_table_formats_text(), ".",
      call. = FALSE
    )
  )
  if (!is.data.frame(out) && !inherits(out, c("data.table", "tbl_df"))) {
    stop(label, " must contain a rectangular table; found object class: ",
         paste(class(out), collapse = "/"), call. = FALSE)
  }
  out <- sae_simplify_imported_columns(out)
  if (anyDuplicated(names(out))) {
    stop(label, " contains duplicated column names: ",
         paste(unique(names(out)[duplicated(names(out))]), collapse = ", "),
         call. = FALSE)
  }
  out
}

sae_validate_esri_shapefile_components <- function(shp_path, label = "geometry file") {
  base <- tools::file_path_sans_ext(shp_path)
  required <- paste0(base, c(".shp", ".shx", ".dbf"))
  present <- file.exists(required)
  sizes <- suppressWarnings(file.info(required)$size)
  empty <- present & (is.na(sizes) | sizes <= 0)
  if (!all(present) || any(empty)) {
    problems <- c(
      if (any(!present)) {
        paste("Missing component(s):", paste(basename(required[!present]), collapse = ", "))
      },
      if (any(empty)) {
        paste("Empty component(s):", paste(basename(required[empty]), collapse = ", "))
      }
    )
    stop(
      label, " is an incomplete ESRI shapefile. ",
      "Upload a single .zip containing all shapefile components, especially .shp, .shx, and .dbf. ",
      "A .shp file alone is usually not enough because the .dbf stores the domain ID used for mapping. ",
      paste(problems, collapse = "; "),
      call. = FALSE
    )
  }
  invisible(TRUE)
}

sae_read_geometry_input <- function(path, label = "geometry file") {
  if (is.null(path) || !nzchar(path %||% "") || !file.exists(path)) {
    stop(label, " does not exist: ", path %||% "(blank)", call. = FALSE)
  }
  ext <- sae_file_ext(path)
  if (ext %in% c("rds", "rda", "rdata")) {
    obj <- if (ext == "rds") readRDS(path) else sae_single_object_from_rdata(path, label)
    if (!inherits(obj, c("sf", "sfc", "Spatial"))) {
      stop(label, " R object must be an sf/sfc/Spatial geometry; found class: ",
           paste(class(obj), collapse = "/"), call. = FALSE)
    }
    return(obj)
  }
  if (!requireNamespace("sf", quietly = TRUE)) {
    stop("Package 'sf' is required to read spatial files. Run install_packages.R and try again.", call. = FALSE)
  }
  spatial_path <- path
  if (identical(ext, "zip")) {
    unzip_dir <- tempfile(pattern = "sae_geometry_")
    dir.create(unzip_dir, recursive = TRUE, showWarnings = FALSE)
    on.exit(unlink(unzip_dir, recursive = TRUE, force = TRUE), add = TRUE)
    utils::unzip(path, exdir = unzip_dir)
    candidates <- list.files(
      unzip_dir,
      pattern = "\\.(shp|gpkg|geojson|json|kml|gml)$",
      recursive = TRUE,
      full.names = TRUE,
      ignore.case = TRUE
    )
    if (length(candidates) == 0) {
      stop("Zipped geometry file must contain a .shp, .gpkg, .geojson, .json, .kml, or .gml file.", call. = FALSE)
    }
    shp_first <- grep("\\.shp$", candidates, ignore.case = TRUE, value = TRUE)
    spatial_path <- if (length(shp_first) > 0) shp_first[1] else candidates[1]
  } else if (!ext %in% c("shp", "gpkg", "geojson", "json", "kml", "gml")) {
    stop(
      "Unsupported ", label, " format: .", ext,
      ". Accepted geometry formats are .rds, .RData/.rda, ESRI shapefile .zip, .gpkg, .geojson, .json, .kml, and .gml.",
      call. = FALSE
    )
  }
  if (identical(tolower(tools::file_ext(spatial_path)), "shp")) {
    sae_validate_esri_shapefile_components(spatial_path, label)
  }
  sf::st_read(spatial_path, quiet = TRUE)
}

sae_read_input_names <- function(path, kind = c("table", "geometry")) {
  kind <- match.arg(kind)
  if (is.null(path) || !nzchar(path %||% "") || !file.exists(path)) {
    return(character())
  }
  obj <- tryCatch({
    if (identical(kind, "geometry")) {
      sae_read_geometry_input(path)
    } else {
      ext <- sae_file_ext(path)
      if (ext == "csv") {
        return(names(sae_read_text_table(
          utils::read.csv, path, nrows = 0, check.names = FALSE,
          encoding_args = sae_text_encoding_args(path, header_only = TRUE)
        )))
      }
      if (ext == "tsv") {
        return(names(sae_read_text_table(
          utils::read.delim, path, nrows = 0, check.names = FALSE,
          encoding_args = sae_text_encoding_args(path, header_only = TRUE)
        )))
      }
      if (ext == "dat") {
        return(names(sae_read_table_input(path)))
      }
      if (ext == "dta" && requireNamespace("haven", quietly = TRUE)) {
        return(names(haven::read_dta(path, n_max = 0)))
      }
      if (ext %in% c("sav", "zsav", "por", "sas7bdat", "xpt",
                     "parquet", "feather")) {
        return(names(sae_read_table_input(path)))
      }
      sae_read_table_input(path)
    }
  }, error = function(e) NULL)
  unique(trimws(as.character(names(obj) %||% colnames(obj) %||% character())))
}

# CPI file (one country's consumer price index by year, Data step). Text files
# are read with the delimiter found in the header line (comma, semicolon or
# tab, as written by Excel in many European locales) and every column kept as
# text, so that decimal commas ("101,4") survive; sae_cpi_series()
# (R/pipeline_helpers.R) converts the numbers. Other formats are read by
# sae_read_table_input().
sae_read_cpi_input <- function(path, label = "CPI file") {
  if (is.null(path) || !nzchar(path %||% "") || !file.exists(path)) {
    stop(label, " does not exist: ", path %||% "(blank)", call. = FALSE)
  }
  ext <- sae_file_ext(path)
  if (!ext %in% c("csv", "txt", "tsv", "dat")) {
    return(as.data.frame(sae_read_table_input(path, label)))
  }
  enc <- sae_text_encoding_args(path, header_only = TRUE)
  first <- tryCatch({
    con <- if (!is.null(enc$fileEncoding)) file(path, encoding = enc$fileEncoding) else file(path)
    on.exit(close(con), add = TRUE)
    readLines(con, n = 1L, warn = FALSE)
  }, error = function(e) "")
  first <- gsub("\"[^\"]*\"", "", first[1] %||% "")
  counts <- c(`\t` = lengths(regmatches(first, gregexpr("\t", first, fixed = TRUE))),
              `;` = lengths(regmatches(first, gregexpr(";", first, fixed = TRUE))),
              `,` = lengths(regmatches(first, gregexpr(",", first, fixed = TRUE))))
  sep <- if (max(counts) > 0) names(counts)[which.max(counts)] else ","
  out <- sae_read_text_table(utils::read.table, path, sep = sep, header = TRUE,
                             quote = "\"", comment.char = "", check.names = FALSE,
                             colClasses = "character", strip.white = TRUE,
                             blank.lines.skip = TRUE)
  as.data.frame(out)
}
