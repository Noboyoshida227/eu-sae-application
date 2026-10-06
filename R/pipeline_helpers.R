# ============================================================
# pipeline_helpers.R -- Shared helpers for model selection,
# diagnostics, poverty-line handling, and export enrichment
# ============================================================

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) {
    if (is.null(x) || length(x) == 0) y else x
  }
}

sae_as_numeric_or_na <- function(x) {
  suppressWarnings(as.numeric(as.character(x)))
}

sae_scalar_numeric_or_na <- function(x, column = NULL) {
  if (is.null(x) || length(x) == 0L) return(NA_real_)
  if (!is.null(column) && is.data.frame(x) && column %in% names(x)) {
    x <- x[[column]]
  }
  x <- suppressWarnings(as.numeric(x))
  if (length(x) == 0L || !is.finite(x[[1]])) NA_real_ else x[[1]]
}

sae_normalize_povline_map <- function(povline_value, years_keep = NULL) {
  years_chr <- as.character(years_keep %||% character())

  if (is.null(povline_value) || length(povline_value) == 0) {
    out <- numeric(0)
  } else if (is.list(povline_value) && !is.data.frame(povline_value)) {
    out <- sae_as_numeric_or_na(unlist(povline_value, use.names = TRUE))
  } else {
    out <- sae_as_numeric_or_na(povline_value)
    names(out) <- names(povline_value)
  }

  if (length(out) == 1L && length(years_chr) > 0L &&
      (is.null(names(out)) || !nzchar(names(out)[1] %||% ""))) {
    out <- stats::setNames(rep(out[[1]], length(years_chr)), years_chr)
  }

  if (length(out) > 0L && (is.null(names(out)) || any(!nzchar(names(out))))) {
    if (length(years_chr) == length(out)) {
      names(out) <- years_chr
    }
  }

  out
}

sae_validate_numeric_poverty_lines <- function(povline_value, years_keep) {
  years_chr <- as.character(years_keep)
  vals <- sae_normalize_povline_map(povline_value, years_chr)

  if (length(years_chr) == 0L) {
    stop("Numeric poverty-line validation requires at least one analysis year.",
         call. = FALSE)
  }
  if (length(vals) == 1L && length(years_chr) > 1L) {
    vals <- stats::setNames(rep(vals[[1]], length(years_chr)), years_chr)
  }

  missing_years <- setdiff(years_chr, names(vals))
  if (length(missing_years) > 0L) {
    stop(
      "A positive numeric poverty line is required for each analysis year. Missing: ",
      paste(missing_years, collapse = ", "),
      call. = FALSE
    )
  }

  vals <- vals[years_chr]
  bad <- !is.finite(vals) | vals <= 0
  if (any(bad)) {
    stop(
      "Numeric poverty lines must be positive finite values. Check year(s): ",
      paste(years_chr[bad], collapse = ", "),
      call. = FALSE
    )
  }
  vals
}

sae_apply_numeric_poverty_lines <- function(data, povline_value,
                                            year_col = "year",
                                            years_keep = NULL,
                                            output_col = "povline") {
  if (!year_col %in% names(data)) {
    stop("Cannot apply year-specific poverty lines because year column '",
         year_col, "' is missing.", call. = FALSE)
  }
  if (is.null(years_keep)) {
    supplied <- sae_normalize_povline_map(povline_value, NULL)
    years <- if (!is.null(names(supplied)) && any(nzchar(names(supplied)))) {
      sae_as_numeric_or_na(names(supplied))
    } else {
      sort(unique(sae_as_numeric_or_na(data[[year_col]])))
    }
  } else {
    years <- years_keep
  }
  vals <- sae_validate_numeric_poverty_lines(povline_value, years)
  yr_chr <- as.character(sae_as_numeric_or_na(data[[year_col]]))
  data[[output_col]] <- as.numeric(vals[yr_chr])
  data
}

sae_poverty_line_log_message <- function(povline_type, povline_value, years_keep) {
  if (!identical(povline_type, "numeric")) {
    return("Poverty line source: column in survey data.")
  }
  vals <- sae_validate_numeric_poverty_lines(povline_value, years_keep)
  paste(
    "Poverty lines by year:",
    paste(sprintf("%s=%s", names(vals), format(vals, trim = TRUE)),
          collapse = ", ")
  )
}

sae_weighted_mean <- function(x, w) {
  x <- sae_as_numeric_or_na(x)
  w <- sae_as_numeric_or_na(w)
  ok <- is.finite(x) & is.finite(w) & w > 0
  if (!any(ok)) return(NA_real_)
  stats::weighted.mean(x[ok], w[ok])
}

sae_domain_population_summary <- function(survey_data,
                                          years_keep = NULL,
                                          domain_col = "domain",
                                          year_col = "year",
                                          weight_col = "population_weight") {
  if (is.null(survey_data) ||
      !all(c(domain_col, year_col, weight_col) %in% names(survey_data))) {
    return(data.frame(domain = character(), year = integer(),
                      population = numeric(), stringsAsFactors = FALSE))
  }
  df <- data.frame(
    domain = trimws(as.character(survey_data[[domain_col]])),
    year = sae_as_numeric_or_na(survey_data[[year_col]]),
    weight = sae_as_numeric_or_na(survey_data[[weight_col]]),
    stringsAsFactors = FALSE
  )
  if (!is.null(years_keep) && length(years_keep) > 0L) {
    df <- df[df$year %in% as.integer(years_keep), , drop = FALSE]
  }
  df <- df[is.finite(df$year) & nzchar(df$domain) & is.finite(df$weight), ,
           drop = FALSE]
  if (nrow(df) == 0L) {
    return(data.frame(domain = character(), year = integer(),
                      population = numeric(), stringsAsFactors = FALSE))
  }
  out <- stats::aggregate(
    weight ~ domain + year,
    data = df,
    FUN = function(x) sum(x, na.rm = TRUE)
  )
  names(out)[names(out) == "weight"] <- "population"
  out$year <- as.integer(out$year)
  out
}

sae_poverty_line_summary <- function(survey_data,
                                     years_keep = NULL,
                                     domain_col = "domain",
                                     year_col = "year",
                                     povline_col = "povline",
                                     weight_col = "population_weight") {
  if (is.null(survey_data) ||
      !all(c(domain_col, year_col, povline_col) %in% names(survey_data))) {
    return(data.frame(domain = character(), year = integer(),
                      poverty_line_used = numeric(),
                      poverty_line_min = numeric(),
                      poverty_line_max = numeric(),
                      stringsAsFactors = FALSE))
  }
  weight <- if (weight_col %in% names(survey_data)) {
    survey_data[[weight_col]]
  } else {
    rep(1, nrow(survey_data))
  }
  df <- data.frame(
    domain = trimws(as.character(survey_data[[domain_col]])),
    year = sae_as_numeric_or_na(survey_data[[year_col]]),
    povline = sae_as_numeric_or_na(survey_data[[povline_col]]),
    weight = sae_as_numeric_or_na(weight),
    stringsAsFactors = FALSE
  )
  if (!is.null(years_keep) && length(years_keep) > 0L) {
    df <- df[df$year %in% as.integer(years_keep), , drop = FALSE]
  }
  df <- df[is.finite(df$year) & nzchar(df$domain) & is.finite(df$povline), ,
           drop = FALSE]
  if (nrow(df) == 0L) {
    return(data.frame(domain = character(), year = integer(),
                      poverty_line_used = numeric(),
                      poverty_line_min = numeric(),
                      poverty_line_max = numeric(),
                      stringsAsFactors = FALSE))
  }
  split_key <- interaction(df$domain, df$year, drop = TRUE, lex.order = TRUE)
  parts <- split(df, split_key)
  out <- do.call(rbind, lapply(parts, function(part) {
    data.frame(
      domain = part$domain[[1]],
      year = as.integer(part$year[[1]]),
      poverty_line_used = sae_weighted_mean(part$povline, part$weight),
      poverty_line_min = min(part$povline, na.rm = TRUE),
      poverty_line_max = max(part$povline, na.rm = TRUE),
      stringsAsFactors = FALSE
    )
  }))
  rownames(out) <- NULL
  out
}

sae_domain_name_columns <- function(df, include_generic = TRUE) {
  if (is.null(df) || !length(names(df))) return(character())
  specific <- c(
    "geographic_name", "domain_name", "area_name", "province_name",
    "prov_name", "provlab",
    "NUTS_NAME", "nuts_name", "shapeName", "shape_name"
  )
  generic <- c("label", "name", "NAME", "Name")
  candidates <- if (isTRUE(include_generic)) c(specific, generic) else specific
  intersect(candidates, names(df))
}

sae_build_domain_metadata <- function(...) {
  sources <- list(...)
  rows <- list()
  for (src in sources) {
    if (is.null(src) || !"domain" %in% names(src)) next
    name_cols <- sae_domain_name_columns(src)
    if (length(name_cols) == 0L) next
    nm <- name_cols[[1]]
    part <- data.frame(
      domain = trimws(as.character(src$domain)),
      geographic_name = trimws(as.character(src[[nm]])),
      stringsAsFactors = FALSE
    )
    part <- part[nzchar(part$domain) & nzchar(part$geographic_name) &
                   !is.na(part$geographic_name), , drop = FALSE]
    if (nrow(part) > 0L) rows[[length(rows) + 1L]] <- unique(part)
  }
  if (length(rows) == 0L) {
    return(data.frame(domain = character(), geographic_name = character(),
                      stringsAsFactors = FALSE))
  }
  all_rows <- do.call(rbind, rows)
  all_rows <- all_rows[!duplicated(all_rows$domain), , drop = FALSE]
  rownames(all_rows) <- NULL
  all_rows
}

sae_drop_domain_label_columns <- function(df) {
  label_cols <- sae_domain_name_columns(df, include_generic = FALSE)
  label_cols <- setdiff(label_cols, c("domain", "geographic_name"))
  out <- df[, setdiff(names(df), label_cols), drop = FALSE]
  # sf column subsetting can drop custom attributes required for map credits.
  for (key in c("boundary_attribution", "boundary_provenance")) {
    attr(out, key) <- attr(df, key, exact = TRUE)
  }
  out
}

sae_add_precision_columns <- function(df) {
  if (is.null(df) || nrow(df) == 0L) return(df)
  out <- as.data.frame(df, stringsAsFactors = FALSE)

  add_rmse <- function(mse_col, rmse_col) {
    if (!mse_col %in% names(out) || rmse_col %in% names(out)) return()
    mse <- sae_as_numeric_or_na(out[[mse_col]])
    out[[rmse_col]] <<- sqrt(pmax(mse, 0))
  }
  add_cv <- function(mse_col, estimate_col, cv_col) {
    if (!all(c(mse_col, estimate_col) %in% names(out)) ||
        cv_col %in% names(out)) return()
    mse <- sae_as_numeric_or_na(out[[mse_col]])
    estimate <- sae_as_numeric_or_na(out[[estimate_col]])
    se <- sqrt(pmax(mse, 0))
    out[[cv_col]] <<- ifelse(is.finite(se) & is.finite(estimate) &
                                abs(estimate) > 1e-12,
                              se / abs(estimate), NA_real_)
  }

  for (mse_col in names(out)) {
    if (grepl("_MSE$", mse_col)) {
      stem <- sub("_MSE$", "", mse_col)
      add_rmse(mse_col, paste0(stem, "_RMSE"))
      add_cv(mse_col, stem, paste0(stem, "_CV"))
    } else if (grepl("^mse_", mse_col)) {
      stem <- sub("^mse_", "", mse_col)
      add_rmse(mse_col, paste0("rmse_", stem))
      add_cv(mse_col, paste0("rate_", stem), paste0("cv_", stem))
    } else if (identical(mse_col, "direct_mse")) {
      add_rmse(mse_col, "direct_rmse")
      add_cv(mse_col, "direct_rate", "direct_cv")
    } else if (identical(mse_col, "mse")) {
      add_rmse(mse_col, "rmse")
    }
  }
  out
}

sae_enrich_result_table <- function(df,
                                    domain_metadata = NULL,
                                    population = NULL,
                                    poverty_lines = NULL) {
  if (is.null(df) || nrow(df) == 0L || !"domain" %in% names(df)) return(df)
  out <- as.data.frame(df, stringsAsFactors = FALSE)
  out$.sae_row_order <- seq_len(nrow(out))
  out$geographic_identifier <- out$domain

  if (!is.null(domain_metadata) && nrow(domain_metadata) > 0L) {
    out <- merge(out, unique(domain_metadata), by = "domain", all.x = TRUE,
                 sort = FALSE)
  }
  if (!"geographic_name" %in% names(out)) out$geographic_name <- NA_character_

  if (!is.null(population) && nrow(population) > 0L &&
      all(c("domain", "year") %in% names(out)) &&
      all(c("domain", "year", "population") %in% names(population))) {
    out <- merge(out, unique(population), by = c("domain", "year"),
                 all.x = TRUE, sort = FALSE)
  }

  if (!is.null(poverty_lines) && nrow(poverty_lines) > 0L &&
      all(c("domain", "year") %in% names(out)) &&
      all(c("domain", "year") %in% names(poverty_lines))) {
    poverty_lines <- as.data.frame(poverty_lines, stringsAsFactors = FALSE)
    if ("poverty_line" %in% names(poverty_lines) &&
        !"poverty_line_used" %in% names(poverty_lines)) {
      names(poverty_lines)[names(poverty_lines) == "poverty_line"] <-
        "poverty_line_used"
    }
    out <- merge(out, unique(poverty_lines), by = c("domain", "year"),
                 all.x = TRUE, sort = FALSE)
  }

  out <- sae_add_precision_columns(out)
  out <- out[order(out$.sae_row_order), , drop = FALSE]
  out$.sae_row_order <- NULL
  first_cols <- intersect(
    c("geographic_identifier", "geographic_name", "domain", "year",
      "population", "poverty_line_used", "poverty_line_min",
      "poverty_line_max"),
    names(out)
  )
  out[, c(first_cols, setdiff(names(out), first_cols)), drop = FALSE]
}

sae_deparse_formula <- function(x) paste(deparse(x), collapse = "")

sae_cv_foldid <- function(n, nfolds, seed = 123L) {
  n <- as.integer(n)
  nfolds <- as.integer(nfolds)
  seed <- suppressWarnings(as.integer(seed))
  if (!is.finite(seed)) seed <- 123L
  if (n < 1L || nfolds < 2L || nfolds > n) {
    stop("Invalid cross-validation dimensions.", call. = FALSE)
  }
  had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  if (had_seed) old_seed <- get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  on.exit({
    if (had_seed) {
      assign(".Random.seed", old_seed, envir = .GlobalEnv)
    } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
      rm(".Random.seed", envir = .GlobalEnv)
    }
  }, add = TRUE)
  set.seed(seed)
  sample(rep(seq_len(nfolds), length.out = n))
}

sae_lasso_screen <- function(dt, xvars, y, enabled = FALSE,
                             lambda_choice = "lambda.1se",
                             label = "model", seed = 123L) {
  df <- as.data.frame(dt, stringsAsFactors = FALSE)
  original <- unique(xvars[xvars %in% names(df)])
  diag <- data.frame(
    model = label,
    outcome = y,
    lasso_enabled = isTRUE(enabled),
    lambda_choice = lambda_choice %||% "lambda.1se",
    seed = suppressWarnings(as.integer(seed)),
    n_candidates = length(original),
    n_numeric_candidates = NA_integer_,
    n_complete_cases = NA_integer_,
    n_selected = NA_integer_,
    selected_variables = "",
    stepwise_candidates = "",
    fallback_used = FALSE,
    note = "",
    stringsAsFactors = FALSE
  )
  set_stepwise <- function(vars) {
    vars <- unique(vars[vars %in% names(df)])
    diag$stepwise_candidates <<- paste(vars, collapse = ", ")
    vars
  }
  if (!isTRUE(enabled)) {
    diag$n_numeric_candidates <- sum(vapply(df[, original, drop = FALSE],
                                            is.numeric, logical(1)))
    diag$note <- "LASSO screening disabled; stepwise used original candidate set."
    return(list(vars = set_stepwise(original), diagnostics = diag))
  }
  if (!requireNamespace("glmnet", quietly = TRUE)) {
    stop("Package 'glmnet' is required for LASSO screening. Run install_packages.R and try again.",
         call. = FALSE)
  }
  numeric_vars <- original[vapply(df[, original, drop = FALSE],
                                  is.numeric, logical(1))]
  numeric_vars <- numeric_vars[vapply(numeric_vars, function(v) {
    x <- sae_as_numeric_or_na(df[[v]])
    x <- x[is.finite(x)]
    length(x) > 0L && length(unique(x)) > 1L
  }, logical(1))]
  diag$n_numeric_candidates <- length(numeric_vars)
  if (length(numeric_vars) == 0L) {
    diag$fallback_used <- TRUE
    diag$note <- "No nonconstant numeric candidate predictors were available for LASSO; stepwise will use an intercept-only model."
    return(list(vars = set_stepwise(character()), diagnostics = diag))
  }
  use_df <- as.data.frame(df[, c(y, numeric_vars), drop = FALSE])
  use_df <- use_df[stats::complete.cases(use_df), , drop = FALSE]
  diag$n_complete_cases <- nrow(use_df)
  if (nrow(use_df) < 5L) {
    diag$fallback_used <- TRUE
    diag$note <- "Too few complete cases for LASSO; stepwise used cleaned numeric candidate set."
    return(list(vars = set_stepwise(numeric_vars), diagnostics = diag))
  }
  complete_nzv <- vapply(use_df[, numeric_vars, drop = FALSE], function(x) {
    x <- sae_as_numeric_or_na(x)
    x <- x[is.finite(x)]
    length(unique(x)) > 1L
  }, logical(1))
  numeric_vars <- numeric_vars[complete_nzv]
  diag$n_numeric_candidates <- length(numeric_vars)
  if (length(numeric_vars) == 0L) {
    diag$fallback_used <- TRUE
    diag$note <- "All numeric candidates were constant after complete-case filtering; stepwise will use an intercept-only model."
    return(list(vars = set_stepwise(character()), diagnostics = diag))
  }
  use_df <- use_df[, c(y, numeric_vars), drop = FALSE]
  if (length(numeric_vars) < 2L) {
    diag$fallback_used <- TRUE
    diag$note <- "Only one cleaned numeric candidate was available; LASSO skipped and stepwise used that candidate."
    return(list(vars = set_stepwise(numeric_vars), diagnostics = diag))
  }

  x <- as.matrix(use_df[, numeric_vars, drop = FALSE])
  yv <- sae_as_numeric_or_na(use_df[[y]])
  if (!any(is.finite(yv)) || length(unique(yv[is.finite(yv)])) < 2L) {
    diag$fallback_used <- TRUE
    diag$note <- "Outcome had insufficient variation for LASSO; stepwise used cleaned numeric candidate set."
    return(list(vars = set_stepwise(numeric_vars), diagnostics = diag))
  }
  nfolds <- min(10L, max(3L, floor(nrow(use_df) / 2L)))
  nfolds <- min(nfolds, nrow(use_df))
  seed <- suppressWarnings(as.integer(seed))
  if (!is.finite(seed)) seed <- 123L
  diag$seed <- seed
  foldid <- sae_cv_foldid(nrow(use_df), nfolds, seed)
  fit <- tryCatch(
    glmnet::cv.glmnet(x, yv, alpha = 1, family = "gaussian",
                      standardize = TRUE, nfolds = nfolds, foldid = foldid),
    error = function(e) e
  )
  if (inherits(fit, "error")) {
    diag$fallback_used <- TRUE
    diag$note <- paste("LASSO failed; stepwise used cleaned numeric candidate set:",
                       conditionMessage(fit))
    return(list(vars = set_stepwise(numeric_vars), diagnostics = diag))
  }
  s <- if (lambda_choice %in% c("lambda.min", "lambda.1se")) {
    lambda_choice
  } else {
    "lambda.1se"
  }
  cf <- stats::coef(fit, s = s)
  selected <- rownames(cf)[as.numeric(cf[, 1]) != 0]
  selected <- setdiff(selected, "(Intercept)")
  selected <- intersect(selected, numeric_vars)
  diag$n_selected <- length(selected)
  diag$selected_variables <- paste(selected, collapse = ", ")
  if (length(selected) == 0L) {
    diag$fallback_used <- TRUE
    diag$note <- "LASSO selected no predictors; stepwise used cleaned numeric candidate set."
    return(list(vars = set_stepwise(numeric_vars), diagnostics = diag))
  }
  diag$note <- "LASSO-screened candidate set passed to AIC/BIC stepwise selection."
  list(vars = set_stepwise(selected), diagnostics = diag)
}

sae_model_fit_diagnostics <- function(method, year, formula, data,
                                      mixed_model = NULL,
                                      random_variance = NA_real_,
                                      note = "") {
  rhs_terms <- attr(stats::terms(formula), "term.labels")
  out <- data.frame(
    method = method,
    year = as.integer(year),
    formula = sae_deparse_formula(formula),
    n_domains = NA_integer_,
    n_predictors = length(rhs_terms),
    AIC = NA_real_,
    BIC = NA_real_,
    logLik = NA_real_,
    residual_sd = NA_real_,
    random_effect_variance = random_variance,
    ols_companion_r2 = NA_real_,
    ols_companion_adj_r2 = NA_real_,
    note = note,
    stringsAsFactors = FALSE
  )
  fit <- tryCatch(stats::lm(formula, data = data), error = function(e) NULL)
  if (!is.null(fit)) {
    sm <- summary(fit)
    out$n_domains <- stats::nobs(fit)
    out$AIC <- sae_scalar_numeric_or_na(
      tryCatch(stats::AIC(fit), error = function(e) NA_real_),
      column = "AIC"
    )
    out$BIC <- sae_scalar_numeric_or_na(
      tryCatch(stats::BIC(fit), error = function(e) NA_real_),
      column = "BIC"
    )
    out$logLik <- sae_scalar_numeric_or_na(
      tryCatch(stats::logLik(fit), error = function(e) NA_real_)
    )
    out$residual_sd <- sm$sigma %||% NA_real_
    out$ols_companion_r2 <- sm$r.squared %||% NA_real_
    out$ols_companion_adj_r2 <- sm$adj.r.squared %||% NA_real_
  }
  if (!is.null(mixed_model)) {
    mixed_aic <- sae_scalar_numeric_or_na(
      tryCatch(stats::AIC(mixed_model), error = function(e) NA_real_),
      column = "AIC"
    )
    mixed_bic <- sae_scalar_numeric_or_na(
      tryCatch(stats::BIC(mixed_model), error = function(e) NA_real_),
      column = "BIC"
    )
    mixed_loglik <- sae_scalar_numeric_or_na(
      tryCatch(stats::logLik(mixed_model), error = function(e) NA_real_)
    )
    if (is.finite(mixed_aic)) out$AIC <- mixed_aic
    if (is.finite(mixed_bic)) out$BIC <- mixed_bic
    if (is.finite(mixed_loglik)) out$logLik <- mixed_loglik
  }
  out
}

# Effective sample size used by the arcsine Fay-Herriot transformation.
# A design effect cannot be estimated when both the design-based and SRS
# variances are zero (most commonly when a sampled domain has a direct rate of
# exactly 0 or 1). In that boundary case, use the observed domain sample size,
# which gives the standard arcsine working variance 1 / (4 * N), instead of
# allowing 0 / 0 to propagate as NaN into the covariance matrix.
sae_effective_sample_size <- function(sample_size, design_variance,
                                      srs_variance) {
  sample_size <- suppressWarnings(as.numeric(sample_size))
  design_variance <- suppressWarnings(as.numeric(design_variance))
  srs_variance <- suppressWarnings(as.numeric(srs_variance))

  if (!(length(sample_size) == length(design_variance) &&
        length(sample_size) == length(srs_variance))) {
    stop("sample_size, design_variance, and srs_variance must have equal lengths.",
         call. = FALSE)
  }
  if (any(!is.finite(sample_size) | sample_size <= 0)) {
    stop("Effective-sample-size calculation requires finite positive domain sample sizes.",
         call. = FALSE)
  }

  design_effect <- design_variance / srs_variance
  n_eff <- sample_size / design_effect
  fallback_used <- !is.finite(design_effect) | design_effect <= 0 |
                   !is.finite(n_eff) | n_eff <= 0

  design_effect[fallback_used] <- 1
  n_eff[fallback_used] <- sample_size[fallback_used]

  data.frame(
    deff = design_effect,
    n_eff = n_eff,
    effective_sample_size_fallback = fallback_used,
    stringsAsFactors = FALSE
  )
}

# ---- Mapping-collision resolution -------------------------------------------
# `rename(!!!rename_map)` fails with an opaque tidyselect error when a column
# already bears a canonical name while a *different* column is mapped to it
# (e.g. the file has a `strata` column but the user mapped `region` to strata).
# The user's mapping is the instruction, so the mapped column takes the
# canonical name and the pre-existing column is set aside as `<name>_original`,
# announced in the step log. A column that the same map renames away needs no
# treatment - the simultaneous rename handles it correctly.
sae_resolve_rename_collisions <- function(df, rename_map, context = "") {
  targets <- names(rename_map)
  sources <- unname(rename_map)
  for (i in seq_along(rename_map)) {
    target <- targets[[i]]
    source_col <- sources[[i]]
    if (identical(target, source_col)) next
    if (target %in% names(df) && !target %in% sources) {
      alt <- paste0(target, "_original")
      while (alt %in% names(df) || alt %in% targets) alt <- paste0(alt, "_")
      cat(sprintf(
        paste0("NOTE%s: the input already has a column named '%s', but the ",
               "variable mapping assigns '%s' to that role. Keeping the ",
               "mapped column '%s' and renaming the pre-existing '%s' to ",
               "'%s'. If the pre-existing column was the one you wanted, ",
               "select it in the variable mapping instead.\n"),
        if (nzchar(context)) paste0(" [", context, "]") else "",
        target, source_col, source_col, target, alt))
      names(df)[names(df) == target] <- alt
    }
  }
  df
}

# ---- Covariate type guard ---------------------------------------------------
# Fay-Herriot covariates pass through a correlation screen and a linear model,
# so a non-numeric column in the auxiliary file (a region label, a name, a date
# read as text) aborts variable selection with the opaque error
# `cor(xmat) : 'x' must be numeric`. Keep only columns a model can use, and say
# which ones were set aside and why.
sae_numeric_candidates <- function(df, vars, context = "") {
  vars <- vars[vars %in% names(df)]
  if (length(vars) == 0L) return(vars)
  usable <- vapply(vars, function(v) {
    col <- df[[v]]
    (is.numeric(col) || is.logical(col)) && !inherits(col, "sfc")
  }, logical(1))
  dropped <- vars[!usable]
  if (length(dropped) > 0L) {
    cat(sprintf(
      paste0("NOTE%s: %d auxiliary column(s) are not numeric and cannot serve ",
             "as Fay-Herriot covariates: %s. They are ignored for variable ",
             "selection. Recode them as numeric indicators if the model should ",
             "use them.\n"),
      if (nzchar(context)) paste0(" [", context, "]") else "",
      length(dropped), paste(dropped, collapse = ", ")))
  }
  vars[usable]
}

# ---- Stratum identifier normalisation ---------------------------------------
# survey::degf() derives design degrees of freedom via as.numeric(strata).
# Character stratum labels ("R1", "North_urban") coerce to NA there, which emits
# "NAs introduced by coercion" and can distort the degrees of freedom used for
# every direct-estimate confidence interval. Stable integer codes preserve the
# stratification exactly while keeping survey's internals numeric.
.sae_notified <- new.env(parent = emptyenv())
sae_strata_codes <- function(x, context = "") {
  if (is.numeric(x)) return(x)
  codes <- as.integer(factor(as.character(x)))
  key <- paste0("strata:", context)
  if (is.null(.sae_notified[[key]])) {
    cat(sprintf(
      paste0("NOTE%s: stratum labels are not numeric; converted to %d integer ",
             "stratum codes for the survey design (stratification unchanged).\n"),
      if (nzchar(context)) paste0(" [", context, "]") else "",
      length(unique(codes[!is.na(codes)]))))
    assign(key, TRUE, envir = .sae_notified)
  }
  codes
}

# Boundary attribution belongs to the selected geometry, never to a hard-coded country.
sae_boundary_attribution <- function(x) {
  value <- if (is.character(x)) x else attr(x, "boundary_attribution", exact = TRUE)
  if (!is.character(value) || length(value) != 1L || is.na(value) || !nzchar(trimws(value))) return(NULL)
  trimws(value)
}
sae_map_caption <- function(boundary, caption = NULL) {
  parts <- c(caption, sae_boundary_attribution(boundary))
  parts <- parts[!is.na(parts) & nzchar(parts)]
  if (!length(parts)) return(NULL)
  paste(parts, collapse = "\n")
}

# ------------------------------------------------------------
# MFH coefficient table (used by 03_comparison.R)
# ------------------------------------------------------------
# `estcoef` is the stacked coefficient matrix of an msae MFH fit (one block of
# rows per period, columns beta / std.error / t.statistics / p.value).
# msae labels the rows with the design-matrix column names; the robust MFH2
# refit used to return the matrix without rownames, which made the previous
# inline data.frame() call fail with "arguments imply differing number of
# rows".  This helper derives the term labels from the formulas when the
# rownames are missing, takes the year from the formula name or, failing
# that, from `years`, and returns NULL (never an error) when the matrix
# cannot be split consistently, so the comparison step degrades to a note
# instead of stopping the run.
sae_signif_stars <- function(p) {
  p <- suppressWarnings(as.numeric(p))
  out <- rep("", length(p))
  out[!is.na(p) & p < 0.1]   <- "."
  out[!is.na(p) & p < 0.05]  <- "*"
  out[!is.na(p) & p < 0.01]  <- "**"
  out[!is.na(p) & p < 0.001] <- "***"
  out
}

sae_mfh_coef_table <- function(estcoef, formulas, years, method = "MFH") {
  if (is.null(estcoef) || !is.matrix(estcoef) || nrow(estcoef) == 0L) return(NULL)
  if (is.null(formulas) || length(formulas) == 0L) return(NULL)
  needed <- c("beta", "std.error", "t.statistics", "p.value")
  if (!all(needed %in% colnames(estcoef))) return(NULL)

  term_labels <- lapply(formulas, function(f) {
    tt <- stats::terms(f)
    labs <- attr(tt, "term.labels")
    if (isTRUE(attr(tt, "intercept") == 1L)) c("(Intercept)", labs) else labs
  })
  n_per_period <- vapply(term_labels, length, integer(1))
  if (sum(n_per_period) != nrow(estcoef)) return(NULL)

  formula_names <- names(formulas)
  years <- suppressWarnings(as.integer(years))
  rows <- vector("list", length(formulas))
  start <- 1L
  for (t in seq_along(formulas)) {
    end <- start + n_per_period[[t]] - 1L
    ec  <- estcoef[start:end, , drop = FALSE]
    yr <- NA_integer_
    if (!is.null(formula_names) && !is.na(formula_names[[t]]) &&
        grepl("[0-9]{4}$", formula_names[[t]])) {
      yr <- suppressWarnings(as.integer(sub("^.*?([0-9]{4})$", "\\1", formula_names[[t]])))
    }
    if (is.na(yr) && length(years) >= t) yr <- years[[t]]
    terms_t <- rownames(ec)
    if (is.null(terms_t) || length(terms_t) != nrow(ec) || any(!nzchar(terms_t))) {
      terms_t <- term_labels[[t]]
    }
    rows[[t]] <- data.frame(
      Method    = rep(as.character(method), nrow(ec)),
      Year      = rep(yr, nrow(ec)),
      Term      = terms_t,
      Estimate  = as.numeric(ec[, "beta"]),
      Std.Error = as.numeric(ec[, "std.error"]),
      z.value   = as.numeric(ec[, "t.statistics"]),
      p.value   = as.numeric(ec[, "p.value"]),
      Signif    = sae_signif_stars(ec[, "p.value"]),
      check.names = FALSE,
      stringsAsFactors = FALSE
    )
    start <- end + 1L
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

# ------------------------------------------------------------
# Model-selection criterion (AIC/BIC) and fixed covariates
# ------------------------------------------------------------
# AIC/BIC is used only by stepwise covariate selection. With LASSO off, a
# covariate list entered for a year fixes that year's formula, so the
# criterion is not used for that year. When both years are fixed it is not
# used at all: the app then records `ic_criterion: none`, and the UFH and
# MFH scripts accept "none" only in that case. The app's criterion box
# (ic_criterion_input() in app.R) follows the same rule.
sae_covariates_fixed <- function(lasso_enabled, vars) {
  vars <- as.character(unlist(vars))
  !isTRUE(lasso_enabled) && length(vars[nzchar(trimws(vars))]) > 0L
}

sae_effective_ic_criterion <- function(criterion, lasso_enabled, vars_y1, vars_y2) {
  if (sae_covariates_fixed(lasso_enabled, vars_y1) &&
      sae_covariates_fixed(lasso_enabled, vars_y2)) {
    return("none")
  }
  criterion
}

# Plain-language description for logs, the wizard review and diagnostics.
sae_ic_criterion_label <- function(criterion, lasso_enabled, vars_y1, vars_y2,
                                   years = c("Year 1", "Year 2")) {
  fixed1 <- sae_covariates_fixed(lasso_enabled, vars_y1)
  fixed2 <- sae_covariates_fixed(lasso_enabled, vars_y2)
  if ((fixed1 && fixed2) || identical(criterion, "none")) {
    return("not used (covariates fixed for both years)")
  }
  crit <- if (is.null(criterion) || !nzchar(criterion %||% "")) "(unset)" else as.character(criterion)
  if (fixed1) return(sprintf("%s (%s only; %s covariates fixed)", crit, years[2], years[1]))
  if (fixed2) return(sprintf("%s (%s only; %s covariates fixed)", crit, years[1], years[2]))
  crit
}

# Error text when "none" is requested but a year still needs stepwise
# selection; NULL when "none" is consistent with the covariate settings.
sae_ic_none_problem <- function(model, lasso_enabled, vars_y1, vars_y2,
                                years = c("Year 1", "Year 2")) {
  if (isTRUE(lasso_enabled)) {
    reason <- "LASSO screening is on, so the covariates are only a candidate pool for stepwise selection"
  } else {
    missing <- years[c(!sae_covariates_fixed(FALSE, vars_y1),
                       !sae_covariates_fixed(FALSE, vars_y2))]
    if (length(missing) == 0L) return(NULL)
    reason <- sprintf("%s %s no usable covariates (none entered, or none found in the auxiliary data), so stepwise selection is needed",
                      paste(missing, collapse = " and "),
                      if (length(missing) == 1L) "has" else "have")
  }
  sprintf(paste("%s: the model-selection criterion is 'none' (not used), which requires LASSO off",
                "and covariates fixed for both years, but %s. Choose AIC or BIC, or enter valid",
                "covariates for both years with LASSO off."), model, reason)
}

# ---- Price deflation (mean welfare) -----------------------------------------
# Household-survey welfare is usually in current (nominal) prices. For
# mean-welfare runs the user can enter a consumer price index (for example
# the CPI or the HICP); welfare is then expressed in constant prices of a base
# year: welfare_t * P(base year) / P(t), where P is the price level. The base
# year is the first analysis year unless another one is chosen (for example
# 2017, or the last analysis year). Levels are in base-year prices and changes
# between years are real changes; percentage changes do not depend on the
# base year. Poverty runs are never deflated (the poverty line is already in
# each year's prices).
#
# Three ways of reporting the index are accepted, as statistical offices
# publish all of them:
#   index_type: fixed           an index with a fixed reference year (for
#                               example 2015 = 100), one value per analysis
#                               year and for a base year outside them;
#   index_type: previous_year   annual indices with the previous year = 100
#                               (for example 103.6 for 3.6% annual-average
#                               inflation), one value for every year after
#                               the earliest and up to the latest of the
#                               analysis years and the base year. They are
#                               chained: P(t) = P(t - 1) * index(t) / 100;
#   index_type: percent_change  annual changes in % (for example 3.6), for the
#                               same years; index(t) = 100 + change(t).
# The values are typed in by year or read from a CPI file (one country's
# CPI by year) chosen in the Data step; the app then records the file and
# columns in source_file, year_column and value_column, and any problem
# reading them in source_problem.
#
# Incomes refer to (income_period; owner's decision of 4 Oct 2026):
#   survey_year             the incomes of survey year t are in t's prices
#                           (the default, and the behaviour before w5k);
#   previous_calendar_year  they refer to the calendar year before the survey
#                           (as in EU-SILC: survey 2013 asks about 2012
#                           incomes), so the index of t - 1 is used for t.
# Index values, the base year and "constant <year> prices" are always about
# the year of the prices ("income year"); results stay labelled by survey year.
#
# When the survey's welfare is already in constant (real) prices, nothing is
# converted and the config records it for the labels (owner's request of
# 4 Oct 2026):
#   price_index: {enabled: no, welfare_prices: real, base_year: 2017}
# (base_year optional: the year of those prices).
#
# Config shape (app_config.yml):
#   price_index:
#     enabled: yes
#     index_type: fixed          # optional; default fixed
#     income_period: survey_year # optional; default survey_year
#     base_year: 2017            # optional; default: first income year
#     values: {"2012": 100, "2013": 101.4, "2017": 104.9}
#     source_file: cpi.xlsx      # optional (CPI file)
#     year_column: year
#     value_column: cpi

# Named numeric vector of index values by year (no recycling of a single value,
# unlike the poverty-line helper: every year needs its own index).
sae_price_index_values <- function(values) {
  if (is.null(values) || length(values) == 0L) return(stats::setNames(numeric(0), character(0)))
  v <- if (is.list(values) && !is.data.frame(values)) unlist(values, use.names = TRUE) else values
  nm <- names(v)
  out <- suppressWarnings(as.numeric(v))
  names(out) <- if (is.null(nm)) rep("", length(out)) else nm
  out[nzchar(names(out))]
}

sae_price_index_enabled <- function(price_index, indicator_type = "mean_welfare") {
  identical(as.character(indicator_type %||% ""), "mean_welfare") &&
    is.list(price_index) && isTRUE(as.logical(price_index$enabled %||% FALSE))
}

# "fixed" (index with a fixed reference year; the default), "previous_year"
# (annual indices, previous year = 100) or "percent_change" (annual changes
# in %). NA for any other value.
sae_price_index_type <- function(price_index) {
  raw <- if (is.list(price_index)) price_index$index_type else NULL
  if (is.null(raw) || length(raw) == 0L || is.na(raw[[1]]) || !nzchar(trimws(as.character(raw[[1]])))) {
    return("fixed")
  }
  type <- trimws(as.character(raw[[1]]))
  if (type %in% c("fixed", "previous_year", "percent_change")) type else NA_character_
}

# "survey_year" (the default) or "previous_calendar_year": which year's prices
# the incomes of a survey year are in. NA for any other value.
sae_price_income_period <- function(price_index) {
  raw <- if (is.list(price_index)) price_index$income_period else NULL
  if (is.null(raw) || length(raw) == 0L || is.na(raw[[1]]) ||
      !nzchar(trimws(as.character(raw[[1]])))) {
    return("survey_year")
  }
  p <- trimws(as.character(raw[[1]]))
  if (p %in% c("survey_year", "previous_calendar_year")) p else NA_character_
}

# The years whose prices the incomes of the analysis years are in: the
# analysis years themselves, or one year earlier when incomes refer to the
# calendar year before the survey.
sae_price_income_years <- function(price_index, years_keep) {
  yrs <- as.integer(years_keep)
  if (identical(sae_price_income_period(price_index), "previous_calendar_year")) yrs - 1L else yrs
}

# Years whose value is an annual change (previous_year, percent_change) rather
# than an index level.
sae_price_index_is_chain <- function(price_index) {
  sae_price_index_type(price_index) %in% c("previous_year", "percent_change")
}

# The price base year as a whole number: price_index$base_year, or the first
# income year (normally the first analysis year) when it is not set. NA when it
# is set but is not a calendar year (1900-2100).
sae_price_base_year <- function(price_index, years_keep) {
  years_int <- sort(sae_price_income_years(price_index, years_keep))
  raw <- if (is.list(price_index)) price_index$base_year else NULL
  if (is.null(raw) || length(raw) == 0L ||
      (length(raw) == 1L && is.character(raw) && !nzchar(trimws(raw)))) {
    return(if (length(years_int)) years_int[1] else NA_integer_)
  }
  b <- suppressWarnings(as.numeric(raw[[1]]))
  if (!is.finite(b) || b != round(b) || b < 1900 || b > 2100) return(NA_integer_)
  as.integer(b)
}

# Years that need an annual index (previous year = 100): every year after the
# earliest and up to the latest of the income years and the base year.
sae_price_chain_years <- function(price_index, years_keep) {
  yrs <- sae_price_income_years(price_index, years_keep)
  base <- sae_price_base_year(price_index, years_keep)
  if (!is.na(base)) yrs <- c(yrs, base)
  yrs <- yrs[!is.na(yrs)]
  if (length(yrs) == 0L || min(yrs) == max(yrs)) return(integer(0))
  seq.int(min(yrs) + 1L, max(yrs))
}

# Problems with the price-index settings for the analysis years (character(0)
# when they are usable or deflation is off).
sae_price_index_problems <- function(price_index, years_keep,
                                     indicator_type = "mean_welfare") {
  if (!sae_price_index_enabled(price_index, indicator_type)) return(character(0))
  if (is.na(sae_price_income_period(price_index))) {
    return(sprintf("'incomes refer to' must be 'survey_year' or 'previous_calendar_year' (got '%s')",
                   as.character(price_index$income_period[[1]])))
  }
  years_chr <- as.character(sort(sae_price_income_years(price_index, years_keep)))
  vals <- sae_price_index_values(price_index$values)
  type <- sae_price_index_type(price_index)
  probs <- character(0)
  if (is.na(type)) {
    return(sprintf("price index type must be 'fixed', 'previous_year' or 'percent_change' (got '%s')",
                   as.character(price_index$index_type[[1]])))
  }
  src <- sae_price_source_text(price_index)
  where <- if (nzchar(src)) sprintf(" in the %s", src) else ""
  source_problem <- as.character(unlist(price_index$source_problem %||% character(0)))
  source_problem <- source_problem[!is.na(source_problem) & nzchar(source_problem)]
  if (length(source_problem)) probs <- c(probs, source_problem)
  base <- sae_price_base_year(price_index, years_keep)
  if (is.na(base)) {
    probs <- c(probs, "the price base year must be a calendar year, for example 2017")
  }
  if (sae_price_index_is_chain(price_index)) {
    need <- as.character(sae_price_chain_years(price_index, years_keep))
    missing <- setdiff(need, names(vals))
    what <- if (identical(type, "percent_change")) "annual price change (%)" else
      "annual price index (previous year = 100)"
    if (length(missing)) {
      probs <- c(probs, sprintf("%s missing for year(s) %s%s", what,
                                paste(missing, collapse = ", "), where))
    }
    have <- intersect(need, names(vals))
    bad <- if (identical(type, "percent_change")) {
      have[!is.finite(vals[have]) | vals[have] <= -100]
    } else {
      have[!is.finite(vals[have]) | vals[have] <= 0]
    }
    if (length(bad)) {
      probs <- c(probs, sprintf("%s (year(s) %s%s)",
                                if (identical(type, "percent_change")) "annual price change must be a number above -100"
                                else "price index must be a positive number",
                                paste(bad, collapse = ", "), where))
    }
    return(probs)
  }
  missing <- setdiff(years_chr, names(vals))
  if (length(missing)) {
    probs <- c(probs, sprintf("price index missing for year(s) %s%s",
                              paste(missing, collapse = ", "), where))
  }
  have <- intersect(years_chr, names(vals))
  bad <- have[!is.finite(vals[have]) | vals[have] <= 0]
  if (length(bad)) {
    probs <- c(probs, sprintf("price index must be a positive number (year(s) %s%s)",
                              paste(bad, collapse = ", "), where))
  }
  if (!is.na(base) && !as.character(base) %in% years_chr) {
    b <- as.character(base)
    if (!b %in% names(vals)) {
      probs <- c(probs, sprintf("price index missing for the base year %s%s", b, where))
    } else if (!is.finite(vals[[b]]) || vals[[b]] <= 0) {
      probs <- c(probs, sprintf("price index must be a positive number (base year %s%s)", b, where))
    }
  }
  probs
}

# Price levels by year for the income years and the base year: the entered
# values for a fixed-reference index, or the chained annual indices (earliest
# year = 100) for previous-year indices. Assumes the settings have no problems.
sae_price_levels <- function(price_index, years_keep) {
  vals <- sae_price_index_values(price_index$values)
  base <- sae_price_base_year(price_index, years_keep)
  years <- sort(unique(c(sae_price_income_years(price_index, years_keep), base)))
  if (!sae_price_index_is_chain(price_index)) {
    return(stats::setNames(as.numeric(vals[as.character(years)]), as.character(years)))
  }
  # Annual changes in % become indices with the previous year = 100.
  if (identical(sae_price_index_type(price_index), "percent_change")) vals <- 100 + vals
  span <- seq.int(min(years), max(years))
  lev <- stats::setNames(rep(100, length(span)), as.character(span))
  for (k in seq_along(span)[-1L]) {
    lev[k] <- lev[k - 1L] * as.numeric(vals[[as.character(span[k])]]) / 100
  }
  lev[as.character(years)]
}

# Factors P(base) / P(income year), named by analysis (survey) year, or NULL
# when deflation is off.
sae_price_factors <- function(price_index, years_keep,
                              indicator_type = "mean_welfare") {
  if (!sae_price_index_enabled(price_index, indicator_type)) return(NULL)
  probs <- sae_price_index_problems(price_index, years_keep, indicator_type)
  if (length(probs)) {
    stop("Price index: ", paste(probs, collapse = "; "), call. = FALSE)
  }
  years_int <- sort(as.integer(years_keep))
  income_chr <- as.character(sae_price_income_years(price_index, years_int))
  lev <- sae_price_levels(price_index, years_keep)
  base <- as.character(sae_price_base_year(price_index, years_keep))
  stats::setNames(as.numeric(lev[[base]]) / as.numeric(lev[income_chr]), as.character(years_int))
}

# Multiply welfare by the year's factor. Rows of other years are unchanged.
sae_apply_price_index <- function(data, price_index, years_keep,
                                  indicator_type = "mean_welfare",
                                  welfare_col = "welfare", year_col = "year") {
  factors <- sae_price_factors(price_index, years_keep, indicator_type)
  if (is.null(factors) || !all(c(welfare_col, year_col) %in% names(data))) {
    return(data)
  }
  f <- unname(factors[as.character(data[[year_col]])])
  f[is.na(f)] <- 1
  data[[welfare_col]] <- suppressWarnings(as.numeric(data[[welfare_col]])) * f
  attr(data, "price_factors") <- factors
  data
}

# Multiply the year columns of a target matrix (rows = groups, columns =
# years) by the factors; used for external mean-welfare benchmark targets.
sae_deflate_year_matrix <- function(mat, factors) {
  if (is.null(mat) || is.null(factors)) return(mat)
  for (yr in intersect(colnames(mat), names(factors))) {
    mat[, yr] <- as.numeric(mat[, yr]) * factors[[yr]]
  }
  mat
}

# The prices choice of a saved setup ("convert", "current" or "real"), read
# from its own inputs before defaults are filled in. Setups saved before w5k
# have only deflate_welfare (ticked = "convert", unticked = "current").
sae_setup_welfare_prices <- function(inputs) {
  if (!is.list(inputs)) return("current")
  v <- inputs$welfare_prices
  v <- if (length(v)) as.character(v[[1]]) else NA_character_
  if (!is.na(v) && v %in% c("convert", "current", "real")) return(v)
  if (isTRUE(as.logical(inputs$deflate_welfare %||% FALSE)[1])) "convert" else "current"
}

# TRUE when the survey's welfare is already in constant (real) prices
# (price_index$welfare_prices = "real"): no price index is needed or applied.
sae_price_welfare_is_real <- function(price_index) {
  if (!is.list(price_index)) return(FALSE)
  v <- price_index$welfare_prices
  length(v) >= 1L && !is.na(v[[1]]) && identical(trimws(as.character(v[[1]])), "real")
}

# Short description for logs and the report.
sae_price_basis_label <- function(price_index, years_keep,
                                  indicator_type = "mean_welfare") {
  if (!identical(as.character(indicator_type %||% ""), "mean_welfare")) {
    return("not applicable (poverty indicator)")
  }
  if (!sae_price_index_enabled(price_index, indicator_type)) {
    if (sae_price_welfare_is_real(price_index)) {
      yr <- suppressWarnings(as.numeric(price_index$base_year %||% NA)[1])
      yr_txt <- if (length(yr) == 1L && is.finite(yr) && yr == round(yr) &&
                    yr >= 1900 && yr <= 2100) paste0(" ", as.integer(yr)) else ""
      return(sprintf("constant%s prices as provided in the survey data (no price index applied)", yr_txt))
    }
    return("current prices (not deflated)")
  }
  years_chr <- as.character(sort(sae_price_income_years(price_index, years_keep)))
  vals <- sae_price_index_values(price_index$values)
  base_int <- sae_price_base_year(price_index, years_keep)
  base <- if (is.na(base_int)) "(base year not set)" else as.character(base_int)
  fmt <- function(y) as.character(signif(as.numeric(vals[y]), 8))
  src <- sae_price_source_text(price_index)
  src_txt <- if (nzchar(src)) paste0("; from the ", src) else ""
  # Only said when incomes refer to the calendar year before the survey, so
  # labels of the default setting read as before.
  period_txt <- if (identical(sae_price_income_period(price_index), "previous_calendar_year")) {
    "incomes refer to the calendar year before the survey; "
  } else ""
  type <- sae_price_index_type(price_index)
  if (sae_price_index_is_chain(price_index)) {
    chain <- as.character(sae_price_chain_years(price_index, years_keep))
    what <- if (identical(type, "percent_change")) "annual price change in %" else
      "annual price index, previous year = 100"
    return(sprintf("constant %s prices (%s%s: %s%s)", base, period_txt, what,
                   if (length(chain)) paste(sprintf("%s = %s", chain, fmt(chain)), collapse = ", ")
                   else "none needed", src_txt))
  }
  index_txt <- paste(sprintf("%s = %s", years_chr, fmt(years_chr)), collapse = ", ")
  if (!is.na(base_int) && !base %in% years_chr) {
    index_txt <- sprintf("%s; base year %s = %s", index_txt, base, fmt(base))
  }
  sprintf("constant %s prices (%sprice index: %s%s)", base, period_txt, index_txt, src_txt)
}

# "CPI file cpi.xlsx, column CPI" when the values came from a CPI file, else "".
sae_price_source_text <- function(price_index) {
  if (!is.list(price_index)) return("")
  f <- as.character(unlist(price_index$source_file %||% ""))[1]
  if (is.na(f) || !nzchar(f)) return("")
  col <- as.character(unlist(price_index$value_column %||% ""))[1]
  if (is.na(col) || !nzchar(col)) sprintf("CPI file %s", basename(f)) else
    sprintf("CPI file %s, column %s", basename(f), col)
}

# ---- CPI file (one country's consumer price index by year) -------------------
# Years: numbers, or text holding a four-digit year ("2013", "2013A00",
# "2013-01-01"). Values: numbers, or text with a decimal comma ("101,4") or
# spaces as thousands separators.
sae_cpi_parse_year <- function(x) {
  if (is.numeric(x)) {
    y <- suppressWarnings(as.integer(round(x)))
    y[!is.finite(x) | abs(x - round(x)) > 1e-8] <- NA_integer_
  } else {
    x <- as.character(x)
    hit <- regexpr("(?<![0-9])(19|20|21)[0-9]{2}(?![0-9])", x, perl = TRUE)
    found <- !is.na(hit) & hit > 0
    y <- rep(NA_integer_, length(x))
    y[found] <- as.integer(regmatches(x, hit))
  }
  y[!is.na(y) & (y < 1900 | y > 2100)] <- NA_integer_
  y
}

sae_cpi_parse_number <- function(x) {
  if (is.numeric(x)) return(as.numeric(x))
  s <- trimws(gsub("[\\s\u00a0\u202f]", "", as.character(x), perl = TRUE))
  s[s %in% c("", ":", "-", "..", "NA", "n/a")] <- NA_character_
  has_comma <- grepl(",", s, fixed = TRUE); has_dot <- grepl(".", s, fixed = TRUE)
  comma_last <- has_comma & (!has_dot | regexpr(",[^,]*$", s) > regexpr("\\.[^.]*$", s))
  s[comma_last] <- gsub(",", ".", gsub(".", "", s[comma_last], fixed = TRUE), fixed = TRUE)
  s[!comma_last] <- gsub(",", "", s[!comma_last], fixed = TRUE)
  suppressWarnings(as.numeric(s))
}

# Guess the year column and the CPI column of a CPI table.
sae_cpi_guess_columns <- function(df) {
  nm <- names(df)
  if (!length(nm)) return(list(year = "", value = ""))
  year_names <- "^(year|years|rok|anno|ano|a\u00f1o|annee|ann\u00e9e|jahr|time|time_period|period|date)$"
  year <- nm[grepl(year_names, nm, ignore.case = TRUE, perl = TRUE)][1]
  if (is.na(year)) {
    ok <- vapply(nm, function(n) {
      y <- sae_cpi_parse_year(df[[n]])
      sum(!is.na(y)) >= 2L && mean(!is.na(y)) >= 0.8 && !anyDuplicated(y[!is.na(y)])
    }, logical(1))
    year <- nm[ok][1]
  }
  if (is.na(year)) year <- ""
  others <- setdiff(nm, year)
  numeric_ok <- vapply(others, function(n) {
    v <- sae_cpi_parse_number(df[[n]])
    sum(is.finite(v)) >= 2L && mean(is.finite(v)) >= 0.8
  }, logical(1))
  cand <- others[numeric_ok]
  pref <- cand[grepl("cpi|hicp|index|inflation|price|obs_value|value", cand, ignore.case = TRUE)]
  value <- c(pref, cand)[1]
  list(year = year, value = if (is.na(value)) "" else value)
}

# Values by year from a CPI table: list(values = named numeric sorted by year,
# problems = character(), notes = character()).
sae_cpi_series <- function(df, year_col, value_col) {
  out <- list(values = stats::setNames(numeric(0), character(0)),
              problems = character(0), notes = character(0))
  if (is.null(df) || !nrow(df)) {
    out$problems <- "the CPI file has no rows"
    return(out)
  }
  for (col in c(year_col, value_col)) {
    if (!nzchar(col %||% "") || !col %in% names(df)) {
      out$problems <- c(out$problems, sprintf("column '%s' is not in the CPI file", col %||% ""))
    }
  }
  if (length(out$problems)) return(out)
  y <- sae_cpi_parse_year(df[[year_col]])
  v <- sae_cpi_parse_number(df[[value_col]])
  keep <- !is.na(y) & is.finite(v)
  if (any(!is.na(y) & !is.finite(v))) {
    out$notes <- c(out$notes, sprintf("no number in column '%s' for year(s) %s", value_col,
                                      paste(sort(unique(y[!is.na(y) & !is.finite(v)])), collapse = ", ")))
  }
  y <- y[keep]; v <- v[keep]
  if (!length(y)) {
    out$problems <- sprintf("no year with a number found in columns '%s' and '%s'", year_col, value_col)
    return(out)
  }
  dup <- unique(y[duplicated(y)])
  clash <- dup[vapply(dup, function(d) length(unique(v[y == d])) > 1L, logical(1))]
  if (length(clash)) {
    out$problems <- sprintf(paste("the CPI file has different values for the same year (%s);",
                                  "keep one row per year, or choose another column"),
                            paste(sort(clash), collapse = ", "))
    return(out)
  }
  keep <- !duplicated(y)
  ord <- order(y[keep])
  out$values <- stats::setNames(v[keep][ord], as.character(y[keep][ord]))
  out
}

# ---- Percentage change of a mean (mean-welfare runs) --------------------------
# The change in mean welfare is reported as a percentage of the earlier year's
# mean: 100 * (m2 / m1 - 1). Inference uses the log ratio r = log(m2 / m1),
# whose variance by the delta method is
#   v = MSE1 / m1^2 + MSE2 / m2^2 - 2 * C / (m1 * m2),
# where C is the covariance of the two estimates. C is implied by the MSE of the
# difference that the UFH and MFH steps report: Var(m2 - m1) = MSE1 + MSE2 - 2C.
# (UFH assumes independent years, so C = 0 there.) The covariance-adjusted
# variance is used whenever it is positive, however small (owner's decision of
# 4 Oct 2026: no 1% rule). Only when it is zero, negative or not a number (a
# zero-width interval or an impossible negative variance) is the independence
# variance used instead, as in the MFH step; mse_fallback_used marks those
# rows, and log_ratio_covariance_used is TRUE only when a change MSE was given
# and its implied covariance was used. The 95% interval
# 100 * (exp(r +/- z se) - 1) is asymmetric and never below -100%.
sae_percent_change <- function(m1, m2, mse1, mse2, mse_diff, alpha = 0.05) {
  n <- max(length(m1), length(m2))
  m1 <- rep_len(as.numeric(m1), n); m2 <- rep_len(as.numeric(m2), n)
  mse1 <- rep_len(as.numeric(mse1), n); mse2 <- rep_len(as.numeric(mse2), n)
  mse_diff <- rep_len(as.numeric(mse_diff), n)
  alpha <- rep_len(as.numeric(alpha), n)
  alpha[!is.finite(alpha) | alpha <= 0 | alpha >= 1] <- 0.05
  ok <- is.finite(m1) & is.finite(m2) & m1 > 0 & m2 > 0
  r <- ifelse(ok, log(m2 / m1), NA_real_)
  v_indep <- mse1 / m1^2 + mse2 / m2^2
  has_cov <- is.finite(mse_diff)
  cov12 <- ifelse(has_cov, (mse1 + mse2 - mse_diff) / 2, 0)
  v_cov <- v_indep - 2 * cov12 / (m1 * m2)
  use_cov <- is.finite(v_cov) & is.finite(v_indep) & v_cov > 0
  v <- ifelse(use_cov, v_cov, v_indep)
  v[!ok | !is.finite(v) | v <= 0] <- NA_real_
  se <- sqrt(v)
  z <- stats::qnorm(1 - alpha / 2)
  p <- 2 * stats::pnorm(abs(r / se), lower.tail = FALSE)
  data.frame(
    pct_change = 100 * (exp(r) - 1),
    pct_lb = 100 * (exp(r - z * se) - 1),
    pct_ub = 100 * (exp(r + z * se) - 1),
    pct_mse = (100 * exp(r))^2 * v,
    log_ratio = r,
    log_ratio_var = v,
    log_ratio_covariance_used = ok & has_cov & use_cov,
    # A fallback only where the independence variance itself is usable
    # (missing level MSEs give no inference, not a fallback).
    mse_fallback_used = ok & has_cov & !use_cov & is.finite(v_indep) & v_indep > 0,
    p_value = p,
    stringsAsFactors = FALSE
  )
}
