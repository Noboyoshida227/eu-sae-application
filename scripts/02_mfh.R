# ============================================================================
# EU SAE Package4 -- 02_mfh.R
# Multivariate Fay-Herriot (MFH) Pipeline
#
# Converted from qmd/50-mfh_v2.qmd (computation only, no prose/knitr)
# All paths use here::here() anchored to the project root.
# Figures saved to outputs/figures/, data to outputs/data/,
# tables to outputs/tables/.
# ============================================================================

suppressPackageStartupMessages({
  library(sf)
  library(data.table)
  library(dplyr)
  library(tidyr)
  library(stringr)
  library(purrr)
  library(tictoc)
  library(tidyverse)
  library(car)
  library(msae)
  library(sae)
  library(survey)
  library(spdep)
  library(MASS)
  library(caret)
  library(conflicted)
  library(tibble)
  library(emdi)
  library(ggplot2)
  library(gt)
  library(viridis)
  library(scales)
  library(patchwork)
  library(knitr)
  library(here)
})

# Anchor all here::here() calls to this package copy, even when it is nested
# inside another Git checkout containing older EU SAE files.
here::i_am("scripts/02_mfh.R")

conflicted::conflict_prefer("select", "dplyr")
conflicted::conflict_prefer("filter", "dplyr")
conflicted::conflict_prefer("lag",    "dplyr")
conflicted::conflict_prefer("first",  "dplyr")
conflicted::conflict_prefer("recode", "dplyr")

options(survey.lonely.psu = "adjust")

source(here::here("scripts", "ufh_functions.R"))
source(here::here("scripts", "population_helpers.R"))
source(here::here("R", "input_preflight.R"))
source(here::here("R", "input_readers.R"))
source(here::here("R", "input_paths.R"))
source(here::here("R", "pipeline_helpers.R"))
source(here::here("R", "variance_policy.R"))
source(here::here("R", "mfh_model_selection.R"))
source(here::here("R", "mfh_convergence_check.R"))
source(here::here("R", "mfh_bootstrap_helpers.R"))
source(here::here("R", "mfh_change_plots.R"))
source(here::here("R", "map_style.R"))


.write_xlsx_safe <- function(df, path) {
  if (!requireNamespace("writexl", quietly = TRUE)) {
    install.packages("writexl", repos = "https://cloud.r-project.org")
  }
  df <- as.data.frame(df)
  for (col in names(df)) {
    x <- df[[col]]
    attributes(x) <- NULL
    if (inherits(x, c("haven_labelled", "labelled"))) x <- as.vector(x)
    df[[col]] <- x
  }
  writexl::write_xlsx(df, path = path)
}

# ---- Patch msae convergence check for R >= 4.4 compatibility ----
# Install narrowly patched copies that preserve missing call arguments.  The
# previous recursive walker replaced missing arguments with NULL and corrupted
# eblupMFH3 before it ever reached estimation.
source(here::here("R", "msae_compat.R"))
sae_install_msae_compat_functions(envir = globalenv())

# ---- Robust MFH2 REML endpoint validation and refit ----
# Retain a usable package fit; otherwise refit with constrained REML. Original
# fits and every bootstrap refit share this wrapper and the independent gate.
.eblupMFH2_patched <- get("eblupMFH2", envir = globalenv())
source(here::here("scripts", "eblupMFH2_robust.R"))
.eblupMFH2_with_robust <- function(formula, vardir, MAXITER = 100,
                                   PRECISION = 1e-04, data) {
  eblupMFH2_robust(formula = formula, vardir = vardir, MAXITER = MAXITER,
                   PRECISION = PRECISION, data = data,
                   .orig_fn = .eblupMFH2_patched)
}
assign("eblupMFH2", .eblupMFH2_with_robust, envir = globalenv())
cat(
  "patch-msae: eblupMFH2 wrapped with robust refit fallback ",
  "(activates when the package fit fails the REML endpoint check).\n",
  sep = ""
)




# ============================================================
# Data loading and harmonization
#
# Objective:
# Load the core data inputs required for the MFH analysis and
# harmonize variable names across sources to a common, canonical
# schema used consistently throughout the document.
#
# This chunk:
# - loads household-level survey microdata, domain-level auxiliary
#   covariates, and spatial geometries;
# - removes redundant domain labels to avoid ambiguity in merges;
# - maps raw variable names to standardized names used in estimation
#   and diagnostics; and
# - defines the set of analysis years retained for MFH estimation.
# ============================================================

# ---- Load data ----
cfg_path <- Sys.getenv("SAE_APP_CONFIG", unset = "")
cfg      <- list()
mfh_cfg  <- list()
if (nzchar(cfg_path) && file.exists(cfg_path)) {
  cfg <- yaml::read_yaml(cfg_path)
  if (!is.null(cfg$mfh)) mfh_cfg <- cfg$mfh
}
mfh_cfg <- sae_resolve_method_input_config(cfg, "mfh")
cfg$mfh <- mfh_cfg
psu_design <- sae_require_psu_design(sae_config_psu_design(cfg))

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) {
    if (is.null(x) || length(x) == 0) y else x
  }
}

cfg_or_default <- function(x, default) {
  if (is.null(x) || length(x) == 0 ||
      (length(x) == 1 && is.na(x)) ||
      (is.character(x) && !isTRUE(nzchar(x)))) default else x
}

existing_default_path <- function(...) {
  candidates <- c(...)
  existing <- candidates[file.exists(candidates)]
  path <- if (length(existing) > 0) existing[[1]] else candidates[[1]]
  normalizePath(path, winslash = "/", mustWork = FALSE)
}

resolve_config_path <- function(path, default_path, label) {
  path <- sae_resolve_input_path(cfg_or_default(path, default_path), root = here::here())
  if (!is.null(path) && file.exists(path)) return(path)
  stop(sprintf(
    "%s file does not exist: %s\nUpload the file again or update app_config.yml to a stable path.",
    label, path
  ), call. = FALSE)
}

# ---- Indicator: poverty (FGT) or mean welfare ----------------------------
if (file.exists(here::here("R", "indicator_helpers.R"))) source(here::here("R", "indicator_helpers.R"))

indicator_type   <- cfg_or_default(cfg$indicator_type,  "poverty")
# MFH-specific log_transform (preferred). Falls back to the global
# cfg$log_transform for back-compat with older app_config.yml files
# that didn't carry per-model flags. Independent from the UFH choice
# so MFH can run on log scale even when UFH ran on identity, or
# vice versa.
.mfh_log_transform_raw <- if (!is.null(cfg$mfh$log_transform)) {
  cfg$mfh$log_transform
} else {
  cfg_or_default(cfg$log_transform, FALSE)
}
log_transform    <- isTRUE(.mfh_log_transform_raw) &&
                    identical(indicator_type, "mean_welfare")

# The UFH fitted in this step (msae::eblupUFH) uses the MFH covariates and
# the MFH scale: untransformed poverty rates, or log welfare when MFH runs
# on the log scale. It is not the UFH of the UFH step (emdi, arcsine or log
# transformation, its own covariates), so its columns and labels name the
# scale, e.g. rate_UFH_untransformed (before w5j: rate_UFH).
ufh_msae_code  <- if (isTRUE(log_transform)) "UFH_log" else "UFH_untransformed"
ufh_msae_label <- if (isTRUE(log_transform)) "UFH, log scale" else "UFH, untransformed"
.ufh_col <- function(stat, suffix = "") paste0(stat, "_", ufh_msae_code, suffix)
.safe_log_positive <- function(x) {
  out <- rep(NA_real_, length(x))
  ok <- is.finite(x) & x > 0
  out[ok] <- log(x[ok])
  out
}

# MFH bias correction uses the Gaussian conditional lognormal mean.
# This multivariate extension is evaluated by a refitted bootstrap. FALSE -> use
# naive exp(eta_hat). Default TRUE if missing. Only meaningful when
# log_transform is on; otherwise ignored.
mfh_bias_correction <- as.logical(cfg_or_default(cfg$mfh$bias_correction, TRUE))
if (is.na(mfh_bias_correction)) mfh_bias_correction <- TRUE
currency_symbol  <- cfg_or_default(cfg$currency_symbol, "EUR")
fgt_alpha        <- as.integer(cfg_or_default(cfg$fgt_alpha, 0L))
povline_type     <- cfg_or_default(cfg$povline_type, "column")
povline_cfg      <- cfg_or_default(cfg$povline_value, "povline")

ind_lab <- indicator_label(indicator_type, fgt_alpha,
                            log_transform = log_transform,
                            currency_symbol = currency_symbol)
pov_lab <- ind_lab    # back-compat alias for downstream chunks

.safe_cv <- function(mse, estimate, eps = 1e-12) {
  ifelse(is.finite(mse) & is.finite(estimate) & abs(estimate) > eps,
         sqrt(pmax(mse, 0)) / abs(estimate), NA_real_)
}

if (identical(indicator_type, "poverty")) {
  cat("Indicator: Poverty --", ind_lab$fgt, "-", ind_lab$short, "\n")
  if (povline_type == "numeric") {
    cat(sae_poverty_line_log_message("numeric", povline_cfg,
                                     cfg$mfh$years_keep %||% cfg$years_keep %||% c(2012L, 2013L)),
        "\n")
  }
} else {
  cat("Indicator: Mean welfare", if (log_transform) "(log-fit, back-transformed)" else "(identity scale)", "\n")
  if (isTRUE(log_transform)) {
    cat("Bias correction:", if (isTRUE(mfh_bias_correction)) {
      "TRUE (Gaussian conditional lognormal mean)"
    } else {
      "FALSE (naive exponential back-transform)"
    }, "\n")
  }
}

.default_survey_path <- here::here("Data", "Spain_2y", "survey.rds")
.default_rhs_path <- here::here("Data", "Spain_2y", "auxiliary.rds")
.default_shp_path <- here::here("Data", "Spain_2y", "shapefile.rds")
survey_path <- resolve_config_path(mfh_cfg$survey_path, .default_survey_path, "Survey")
rhs_path <- resolve_config_path(mfh_cfg$rhs_path, .default_rhs_path, "Auxiliary covariates")
shp_path <- resolve_config_path(mfh_cfg$shp_path, .default_shp_path, "Geometry")

survey_raw <- sae_read_table_input(survey_path, "Survey data")   # household-level survey data
rhs_dt     <- sae_read_table_input(rhs_path, "Auxiliary covariates")      # domain-level covariates
shp_dt     <- sae_read_geometry_input(shp_path, "Geometry data")      # province geometries
.map_attribution <- sae_boundary_attribution(shp_dt)

# Domain label columns are kept until after canonical domain names are built
# so exports can include geographic names when they are available.

# ============================================================
# Variable name mapping
# Raw data  ->  Canonical names used in the code
# ============================================================

var_map <- list(
  year     = "year",      # survey year
  domain   = "prov",      # small area / domain identifier
  psu      = "ea_id",     # primary sampling unit
  weight   = "weight",    # household survey weights
  strata   = "",          # optional strata ID
  hh_size  = "hhsize",    # household size for population weights
  welfare  = "income",    # welfare aggregate
  povline  = "povline",   # poverty line
  poor     = "poor",      # poverty indicator (if exists)
  benchmark_level = "",    # optional higher-level unit for grouped benchmarking
  region   = "",           # legacy alias; internally normalized to benchmark_level
  hh_id    = "",           # optional household ID, used only to check the survey unit
  survey_unit = "household" # "household" or "person" rows (w5o)
)

if (!is.null(mfh_cfg$var_map)) {
  var_map[names(mfh_cfg$var_map)] <- mfh_cfg$var_map
}

use_strata <- isTRUE({
  strata_var <- trimws(as.character(var_map$strata %||% ""))
  length(strata_var) == 1 && !is.na(strata_var) && nzchar(strata_var)
})
if (!use_strata) var_map$strata <- ""

benchmark_level <- cfg_or_default(
  mfh_cfg$benchmark_level,
  cfg$benchmarking$level %||% "national"
)
if (!benchmark_level %in% c("national", "custom", "region")) benchmark_level <- "national"
benchmark_target_path <- cfg_or_default(
  mfh_cfg$benchmark_target_path %||% mfh_cfg$regional_benchmark_path,
  cfg$benchmarking$target_path %||% ""
)
benchmark_level_var_cfg <- trimws(as.character(cfg_or_default(
  mfh_cfg$benchmark_level_variable,
  cfg$benchmarking$level_variable %||% ""
)))
mapped_benchmark_level_var <- benchmark_level_var_cfg
if (!nzchar(mapped_benchmark_level_var)) {
  mapped_benchmark_level_var <- trimws(as.character(
    var_map$benchmark_level %||% var_map$region %||% ""
  ))
}
if (identical(benchmark_level, "region") && !nzchar(mapped_benchmark_level_var)) {
  mapped_benchmark_level_var <- "region"
}
if (benchmark_level %in% c("custom", "region")) {
  if (!nzchar(mapped_benchmark_level_var)) {
    benchmark_level <- "national"
  }
  var_map$benchmark_level <- mapped_benchmark_level_var
  var_map$region <- mapped_benchmark_level_var
} else {
  var_map$benchmark_level <- ""
  var_map$region <- ""
}

# ---- Harmonize variable names ----
# Survey unit (w5o): with one row per person, household size is not used and
# population_weight equals the survey weight (sae_apply_survey_unit()).
survey_unit <- sae_survey_unit(var_map$survey_unit)
rename_cols_mfh <- c(
  year = var_map$year, domain = var_map$domain, psu = var_map$psu,
  weight = var_map$weight, welfare = var_map$welfare,
  sae_unit_rename_cols(var_map, names(survey_raw), survey_unit)
)
if (use_strata) rename_cols_mfh <- c(rename_cols_mfh, strata = var_map$strata)
if (!is.null(var_map$benchmark_level) && nzchar(var_map$benchmark_level) &&
    var_map$benchmark_level %in% names(survey_raw)) {
  rename_cols_mfh <- c(rename_cols_mfh, region = var_map$benchmark_level)
}
if (identical(indicator_type, "poverty") &&
    povline_type == "column" && !is.null(var_map$povline)) {
  rename_cols_mfh <- c(rename_cols_mfh, povline = var_map$povline)
}
survey_dt <- sae_apply_column_mapping(survey_raw, rename_cols_mfh, context = "MFH mapping")
if (!use_strata && "strata" %in% names(survey_dt)) {
  survey_dt <- survey_dt %>% select(-any_of("strata"))
}
# Mean-welfare runs ignore the poverty line; ensure the column exists for
# any downstream code that references it.
if (!identical(indicator_type, "poverty") && !"povline" %in% names(survey_dt)) {
  survey_dt$povline <- NA_real_
}
# Mean-welfare runs: express welfare in constant prices of the base year (by
# default the first income year) when a price index was entered
# (R/pipeline_helpers.R).
.price_years <- as.integer(unlist(cfg_or_default(mfh_cfg$years_keep, c(2012L, 2013L))))
price_index_cfg <- cfg$price_index
price_factors <- sae_price_factors(price_index_cfg, .price_years, indicator_type)
if (identical(indicator_type, "mean_welfare")) {
  cat("Prices:", sae_price_basis_label(price_index_cfg, .price_years, indicator_type), "\n")
}
if (!is.null(price_factors)) {
  survey_dt <- sae_apply_price_index(survey_dt, price_index_cfg, .price_years, indicator_type)
  cat(sprintf("Welfare multiplied by %s.\n",
              paste(sprintf("%s in %s", signif(price_factors, 6), names(price_factors)),
                    collapse = " and ")))
}
# When the poverty line is a numeric constant, create the column
if (povline_type == "numeric") {
  survey_dt <- sae_apply_numeric_poverty_lines(
    survey_dt,
    povline_value = povline_cfg,
    year_col = "year",
    years_keep = as.integer(cfg_or_default(mfh_cfg$years_keep, c(2012L, 2013L))),
    output_col = "povline"
  )
}
survey_dt <- sae_apply_survey_unit(survey_dt, survey_unit, "MFH")
# Check the analysis years only, as Data Readiness does.
.unit_years <- as.integer(unlist(cfg_or_default(mfh_cfg$years_keep, c(2012L, 2013L))))
.unit_check <- sae_check_survey_unit(
  survey_dt[as.integer(as.character(survey_dt$year)) %in% .unit_years, , drop = FALSE], survey_unit)
if (identical(.unit_check$status, "error")) stop(.unit_check$message, call. = FALSE)
if (identical(.unit_check$status, "warning")) cat("WARNING:", .unit_check$message, "\n")
survey_dt <- sae_add_population_weight(
  survey_dt,
  weight_col = "weight",
  hh_size_col = "hh_size",
  output_col = "population_weight",
  context = "MFH direct estimation"
)
cat(if (identical(survey_unit, "person")) {
  "MFH direct estimates use population_weight = weight (one row per person).\n"
} else {
  "MFH direct estimates use population_weight = weight * hh_size.\n"
})
survey_dt <- survey_dt %>%
  mutate(domain = trimws(as.character(domain)))

if ("region" %in% names(survey_dt)) {
  survey_dt <- survey_dt %>% mutate(region = trimws(as.character(region)))
}

rhs_domain_col <- cfg_or_default(mfh_cfg$rhs_domain, "prov")
shp_domain_col <- cfg_or_default(mfh_cfg$shp_domain, "prov")

rhs_year_col <- if (!is.null(var_map$year) && var_map$year %in% names(rhs_dt)) {
  var_map$year
} else {
  "year"
}

rhs_dt <- rhs_dt %>%
  rename(domain = all_of(rhs_domain_col)) %>%
  { if (rhs_year_col != "year" && rhs_year_col %in% names(.)) rename(., year = all_of(rhs_year_col)) else . } %>%
  mutate(domain = trimws(as.character(domain)))

shp_dt <- shp_dt %>%
  rename(domain = all_of(shp_domain_col)) %>%
  mutate(domain = trimws(as.character(domain)))

domain_metadata <- sae_build_domain_metadata(shp_dt, rhs_dt, survey_dt)
rhs_dt <- sae_drop_domain_label_columns(rhs_dt)
shp_dt <- sae_drop_domain_label_columns(shp_dt)
# rename/mutate on sf may discard custom attributes; restore the selected credit.
attr(shp_dt, "boundary_attribution") <- .map_attribution
survey_dt <- sae_drop_domain_label_columns(survey_dt)

# ---- Analysis years ----
years_keep <- c(2012L, 2013L)
if (!is.null(mfh_cfg$years_keep) && length(mfh_cfg$years_keep) == 2) {
  years_keep <- sort(as.integer(unlist(mfh_cfg$years_keep)))
}
missing_survey_years <- setdiff(years_keep, sort(unique(as.integer(survey_dt$year))))
missing_rhs_years <- setdiff(years_keep, sort(unique(as.integer(rhs_dt$year))))
if (length(missing_survey_years) > 0 || length(missing_rhs_years) > 0) {
  stop(
    "Requested analysis years are not available. ",
    "Requested: ", paste(years_keep, collapse = ", "),
    ". Missing in survey: ",
    if (length(missing_survey_years) > 0) paste(missing_survey_years, collapse = ", ") else "none",
    ". Missing in auxiliary covariates: ",
    if (length(missing_rhs_years) > 0) paste(missing_rhs_years, collapse = ", ") else "none",
    "."
  )
}
domain_population <- sae_domain_population_summary(survey_dt, years_keep)
poverty_line_export <- if (identical(indicator_type, "poverty")) {
  sae_poverty_line_summary(survey_dt, years_keep)
} else {
  NULL
}

# ---- Model configuration ----
# Which MFH variant to use for diagnostics, maps, MCPE change analysis,
# and final results downstream. MFH2 is the package default. Selecting MFH3
# invokes the Molina-Romero sequence: fit MFH3, use MFH2 on an error or
# non-convergence, and otherwise use the MFH3 variance-homogeneity contrasts
# to choose MFH3 or MFH2. AUTO remains accepted only for legacy saved setups.
#
# UFH is intentionally NOT a valid choice here: UFH analysis is handled
# end-to-end by 40-fh_v2.qmd. This stage (50-mfh_v2.qmd) and the
# downstream Comparison report only support multivariate variants so
# that cross-period inference (MCPE) is well-defined.
diag_model <- toupper(as.character(cfg_or_default(mfh_cfg$diag_model, "MFH2")))
if (identical(toupper(diag_model), "UFH")) {
  message(
    "diag_model = 'UFH' is no longer supported in 50-mfh_v2.qmd. ",
    "UFH analysis is produced by 40-fh_v2.qmd. ",
    "Falling back to 'MFH2' for the multivariate pipeline."
  )
  diag_model <- "MFH2"
}
if (!diag_model %in% c("AUTO", "MFH1", "MFH2", "MFH3")) {
  warning("Unknown mfh.diag_model '", diag_model,
          "'; using MFH2 (package default).")
  diag_model <- "MFH2"
}
diag_model_requested <- diag_model
refvar_adjustment <- tolower(as.character(cfg_or_default(
  mfh_cfg$refvar_adjustment, "bonferroni"
)))
if (!refvar_adjustment %in% c("bonferroni", "bh", "none")) {
  warning("Unknown mfh.refvar_adjustment '", refvar_adjustment,
          "'; using 'bonferroni'.")
  refvar_adjustment <- "bonferroni"
}
refvar_alpha <- suppressWarnings(as.numeric(cfg_or_default(
  mfh_cfg$refvar_alpha, 0.05
)))
if (!is.finite(refvar_alpha) || refvar_alpha <= 0 || refvar_alpha >= 1) {
  warning("mfh.refvar_alpha must be between 0 and 1; using 0.05.")
  refvar_alpha <- 0.05
}

# Set to TRUE to estimate the MFH3 (heteroskedastic) model.
# MFH3 allows the variance of area-time random effects to differ across
# time periods. Use when homoskedasticity of random effects is rejected.
fit_mfh3 <- isTRUE(mfh_cfg$fit_mfh3) ||
  diag_model_requested %in% c("AUTO", "MFH3")

# Record the user's original intent separately from the runtime `fit_mfh3`
# flag, because `fit_mfh3` may be flipped to FALSE later if estimation fails.
# The callout warning near the end of Step 3 uses this to decide whether
# to notify the reader that a requested MFH3 fit fell back to another model.
fit_mfh3_requested <- fit_mfh3 ||
  diag_model_requested %in% c("AUTO", "MFH3")

# Per-year candidate vars (new) or single list (legacy)
mfh_candidate_vars_y1 <- NULL
mfh_candidate_vars_y2 <- NULL
if (!is.null(mfh_cfg$candidate_vars_y1) && length(mfh_cfg$candidate_vars_y1) > 0) {
  mfh_candidate_vars_y1 <- as.character(unlist(mfh_cfg$candidate_vars_y1))
}
if (!is.null(mfh_cfg$candidate_vars_y2) && length(mfh_cfg$candidate_vars_y2) > 0) {
  mfh_candidate_vars_y2 <- as.character(unlist(mfh_cfg$candidate_vars_y2))
}
# Legacy fallback
if (is.null(mfh_candidate_vars_y1) && is.null(mfh_candidate_vars_y2) &&
    !is.null(mfh_cfg$candidate_vars) && length(mfh_cfg$candidate_vars) > 0) {
  mfh_candidate_vars_y1 <- as.character(unlist(mfh_cfg$candidate_vars))
  mfh_candidate_vars_y2 <- mfh_candidate_vars_y1
}
# Validate user-specified candidate vars against actual RHS columns
available_covs <- setdiff(names(rhs_dt), c("domain", "year"))
validate_mfh_covs <- function(vars, label) {
  if (is.null(vars) || length(vars) == 0) return(NULL)
  found   <- vars[vars %in% available_covs]
  missing <- vars[!vars %in% available_covs]
  if (length(missing) > 0) {
    warning(sprintf("MFH %s: dropping unknown covariates: %s",
                    label, paste(missing, collapse = ", ")))
  }
  if (length(found) == 0) return(NULL)
  found
}
mfh_candidate_vars_y1 <- validate_mfh_covs(mfh_candidate_vars_y1, "Year 1")
mfh_candidate_vars_y2 <- validate_mfh_covs(mfh_candidate_vars_y2, "Year 2")
# Per-year candidate vars are applied separately during variable selection

# ---- Benchmarking configuration ----
# Set to TRUE to apply benchmarking to MFH estimates. The dashboard writes
# this explicitly; missing values default to FALSE so old sample data are not
# used accidentally.
do_benchmark <- isTRUE(mfh_cfg$do_benchmark)
population_path <- cfg_or_default(mfh_cfg$population_path, "")
bench_nB <- sae_bootstrap_count(mfh_cfg$bench_nB %||% mfh_cfg$mcpe_nB, label = "mfh.bench_nB")

# Model selection criterion: "AIC" (default) or "BIC"; "none" when the
# covariates are fixed for both years with LASSO off (no stepwise selection).
mfh_ic_criterion <- cfg_or_default(mfh_cfg$ic_criterion, "AIC")
if (!mfh_ic_criterion %in% c("AIC", "BIC", "none")) {
  warning(sprintf("Invalid ic_criterion '%s' for MFH; defaulting to AIC.", mfh_ic_criterion))
  mfh_ic_criterion <- "AIC"
}
mfh_lasso_enabled <- isTRUE(mfh_cfg$lasso_enabled)
if (!is.null(mfh_cfg$variance_lower_multiplier)) {
  cat("Note: mfh.variance_lower_multiplier is set in the configuration but is not used:",
      "sm_out replaces a direct variance only when it is missing/non-finite or below 0.001.\n")
}
.mfh_ic_years <- paste("Year", 1:2, paste0("(", sort(as.integer(years_keep))[1:2], ")"))
if (identical(mfh_ic_criterion, "none")) {
  .mfh_ic_problem <- sae_ic_none_problem("MFH", mfh_lasso_enabled,
                                         mfh_candidate_vars_y1, mfh_candidate_vars_y2,
                                         years = .mfh_ic_years)
  if (!is.null(.mfh_ic_problem)) stop(.mfh_ic_problem, call. = FALSE)
}
cat("Model-selection criterion:",
    sae_ic_criterion_label(mfh_ic_criterion, mfh_lasso_enabled,
                           mfh_candidate_vars_y1, mfh_candidate_vars_y2,
                           years = .mfh_ic_years), "\n")
mfh_lasso_lambda <- cfg_or_default(mfh_cfg$lasso_lambda, "lambda.1se")
analysis_seed <- suppressWarnings(as.integer(cfg_or_default(cfg$analysis_seed, 123L)))
if (!is.finite(analysis_seed) || analysis_seed < 0L) analysis_seed <- 123L
mcpe_nB <- sae_bootstrap_count(mfh_cfg$mcpe_nB, label = "mfh.mcpe_nB")
if (!mfh_lasso_lambda %in% c("lambda.1se", "lambda.min")) {
  warning(sprintf("Invalid lasso_lambda '%s' for MFH; defaulting to lambda.1se.",
                  mfh_lasso_lambda))
  mfh_lasso_lambda <- "lambda.1se"
}
cat("LASSO screening (MFH):",
    if (mfh_lasso_enabled) paste("enabled,", mfh_lasso_lambda) else "disabled",
    "\n")

# ---- Benchmark grouping map (derived from survey data) ----
if (do_benchmark) {
  if (identical(benchmark_level, "national")) {
    region_map <- survey_dt %>%
      select(domain) %>%
      distinct() %>%
      mutate(region = "national")
  } else if ("region" %in% colnames(survey_dt)) {
    # Each domain must belong to exactly one benchmark group (w5o).
    .bench_rows <- survey_dt[as.integer(as.character(survey_dt$year)) %in% years_keep, , drop = FALSE]
    sae_stop_on_benchmark_group_conflicts(
      .bench_rows, paste(var_map$benchmark_level, "group"), "MFH benchmarking")
    region_map <- .bench_rows %>%
      select(domain, region) %>%
      distinct()
  } else {
    stop("Grouped benchmarking requires mapped benchmark-level column '",
         var_map$benchmark_level,
         "' in the survey data. Leave the benchmark-level mapping blank for national benchmarking.")
  }
  bench_desc <- if (identical(benchmark_level, "national")) {
    "national"
  } else {
    paste0("grouped by ", var_map$benchmark_level)
  }
  cat("MFH benchmarking enabled at level:", bench_desc, "\n")
} else {
  region_map <- NULL
  cat("MFH benchmarking disabled by configuration.\n")
  if (nzchar(population_path %||% "")) {
    cat("Population file was provided but MFH benchmarking is disabled; population file is not used in this step.\n")
  }
}

# Validate the complete Direct panel and relevant uploads before cleanup.
sae_validate_relevant_analysis_inputs(survey_dt, rhs_dt, years_keep,
  steps = "MFH", do_benchmark = do_benchmark, population_path = population_path,
  target_path = benchmark_target_path, benchmark_level = benchmark_level,
  level_col = var_map$benchmark_level, indicator_type = indicator_type, fgt_alpha = fgt_alpha)

# ---- Invalidate stale MFH output artifacts ----
dir.create(here::here("outputs", "data"), showWarnings = FALSE, recursive = TRUE)
.mfh_outputs_to_clean <- c(
  here::here("outputs", "data", "mfh_artifacts.rds"),
  here::here("outputs", "tables", "mfh_shapiro_results.csv"),
  here::here("outputs", "data", "mcpemfh2_obj.rds"),
  here::here("outputs", "data", "mcpe_mfh1_obj.rds"),
  here::here("outputs", "data", "mcpe_mfh2_obj.rds"),
  here::here("outputs", "data", "mcpe_mfh3_obj.rds"),
  here::here("outputs", "tables", "comparison_final.csv"),
  here::here("outputs", "tables", "comparison_final_bench.csv"),
  here::here("outputs", "data", "pov_mfh.xlsx"),
  here::here("outputs", "tables", "mfh_selection_diagnostics.csv"),
  here::here("outputs", "tables", "mfh_model_diagnostics.csv"),
  here::here("outputs", "tables", "mfh_variance_structure_selection.csv"),
  here::here("outputs", "tables", "mfh_mcpe_validation.csv"),
  here::here("outputs", "tables", "mfh_convergence_check.csv"),
  here::here("outputs", "tables", "mfh_sampling_covariance.csv"),
  here::here("outputs", "tables", "mfh_standardized_residuals.csv")
)
for (.f in .mfh_outputs_to_clean) {
  if (file.exists(.f)) {
    tryCatch(file.remove(.f),
             warning = function(w) NULL,
             error   = function(e) NULL)
  }
}
cat("Cleaned stale MFH output artifacts before render.\n")


# Source benchmarking functions for MFH
source(here::here("scripts", "bench_regional_mfh.R"))



# Column overview only: no record values in the step log (w5o).
sae_log_data_overview(survey_dt, "Survey data")
sae_log_data_overview(rhs_dt, "Auxiliary data")
sae_log_data_overview(shp_dt, "Geometry data")



library(tibble)
library(gt)
library(dplyr)

# Create the updated table content with canonical names
mfh_table <- tibble::tibble(
  Dataset = c("`survey_dt`", "`rhs_dt`", "`shp_dt`"),
  `Unit of Observation` = c(
    "Household (or Individual)",
    "Target Area (e.g., Province)",
    "Target Area (Spatial)"
  ),
  `Required Variables` = c(
    "`domain`, `weight`, `psu`, `year`, `welfare`, `povline`",
    "`domain`, `year`, covariates (e.g., `gen`, `educ1`, `schyrs`)",
    "`domain`, `geometry` (from `sf` object)"
  )
)

# Build the gt table
mfh_table %>%
  gt() %>%
  tab_header(
    title = md("**Data Input Checklist for the Multivariate Fay-Herriot Model**"),
    subtitle = md("*Standardized datasets, observation levels, and required variables*")
  ) %>%
  cols_label(
    Dataset = "Dataset Name",
    `Unit of Observation` = "Unit of Observation",
    `Required Variables` = "Required Variables"
  ) %>%
  tab_options(
    table.font.names = "Arial",
    heading.title.font.size = px(20),
    heading.subtitle.font.size = px(14),
    table.font.size = px(14),
    column_labels.font.weight = "bold",
    data_row.padding = px(6),
    table.border.top.width = px(2),
    table.border.bottom.width = px(2),
    heading.align = "left"
  ) %>%
  fmt_markdown(columns = everything())



# ------------------------------------------------------------
# Step 1: Direct estimation of province poverty by year
# - PSU ID is preserved across time to facilitate later 
#   cross-year covariance/correlation calculations.
# ------------------------------------------------------------

# Ensure years_keep is standardized for consistent filtering
years_keep <- sort(as.integer(years_keep))
stopifnot(length(years_keep) == 2)

y1 <- years_keep[1]
y2 <- years_keep[2]

# Helper functions for dynamic column naming based on years_keep
col_poor <- function(y) paste0("poor_", y)
col_mse  <- function(y) paste0("mse_",  y)
col_se   <- function(y) paste0("se_",   y)
col_N    <- function(y) paste0("N_",    y)

# Define reusable column vectors to maintain consistency across the pipeline
poor_cols <- c(col_poor(y1), col_poor(y2))
mse_cols  <- c(col_mse(y1),  col_mse(y2))
se_cols   <- c(col_se(y1),   col_se(y2))
N_cols    <- c(col_N(y1),    col_N(y2))

# Filter and prepare survey data for estimation. The column `poor` is the
# LHS the model is fitted on; we keep that name for back-compat with all
# downstream chunks regardless of which indicator was selected.
survey_step1 <- survey_dt %>%
  filter(year %in% years_keep) %>%
  mutate(
    year = as.integer(year),
    poor = if (identical(indicator_type, "poverty")) {
      ifelse(is.na(welfare) | is.na(povline), NA_real_,
             compute_fgt(welfare, povline, fgt_alpha))
    } else {
      as.numeric(welfare)
    },
    psu  = psu
  )

# ---- Define Survey Design ----
# Direct poverty/indicator estimates are person-weighted by expanding each
# sampled household by household size: population_weight = weight * hh_size.
if (isTRUE(use_strata) && "strata" %in% names(survey_step1)) {
  survey_step1$strata <- sae_strata_codes(survey_step1$strata, context = "MFH survey design")
}
.psu_overlap_warning <- sae_psu_overlap_warning(survey_step1, psu_design, use_strata)
if (length(.psu_overlap_warning)) cat(.psu_overlap_warning, "
")
des <- sae_mfh_survey_design(survey_step1, psu_design, use_strata)

# ---- Direct estimates: Domain x Year ----
dir_est_domain_long <- svyby(
  formula    = ~poor,
  by         = ~year + domain,
  design     = des,
  FUN        = svymean,
  na.rm      = TRUE,
  keep.var   = TRUE
) %>%
  mutate(mse = se^2)

# EMDI transforms the direct arithmetic area mean, not individual welfare.
# Retain direct estimates and design variances in original currency units.
direct_arith_domain_long <- if (isTRUE(log_transform)) {
  dir_est_domain_long %>% transmute(year = as.integer(year), domain,
                                   direct_arith = poor, SD_arith = se)
} else NULL
if (isTRUE(log_transform)) {
  if (any(!is.finite(dir_est_domain_long$poor) | dir_est_domain_long$poor <= 0)) {
    stop("Log mean-welfare estimation requires positive finite direct area means. ",
         "Use the identity transformation or review the affected domain-year inputs.")
  }
  dir_est_domain_long <- dir_est_domain_long %>%
    mutate(mse = mse / poor^2, se = sqrt(mse), poor = log(poor))
}

# Pivot to wide format for the MFH modeling frame (one row per domain)
dir_est_domain_all_years <- dir_est_domain_long %>%
  select(domain, year, poor, mse, se) %>%
  pivot_wider(
    names_from  = year,
    values_from = c(poor, mse, se),
    names_glue  = "{.value}_{year}"
  ) 

# ---- Calculate Sample Sizes per Domain-Year ----
sampsize_dt <- survey_step1 %>%
  group_by(domain, year) %>%
  summarize(N = sum(!is.na(poor)), .groups = "drop") %>%
  pivot_wider(
    names_from  = year,
    values_from = N,
    names_glue  = "N_{year}"
  ) 

dir_est_domain_all_years <- dir_est_domain_all_years %>%
  left_join(sampsize_dt, by = "domain")

# ---- Store consolidated direct variances and sample sizes ----
all_var_hat_domain_dt <- dir_est_domain_all_years %>%
  transmute(
    domain      = as.character(domain),
    v1          = .data[[mse_cols[1]]],
    v2          = .data[[mse_cols[2]]],
    !!N_cols[1] := .data[[N_cols[1]]],
    !!N_cols[2] := .data[[N_cols[2]]]
  ) %>%
  distinct()

# Cleanup intermediate objects
rm(dir_est_domain_long, sampsize_dt)




# -------------------------------------------------------------------
# Variance smoothing 
# Assumes already defined upstream:
#   - years_keep (sorted), y1, y2
#   - N_cols (length 2) like c("N_2012","N_2013")
#   - all_var_hat_domain_dt with N_cols already present
#   - v_domain_hh_df with v1, v2
# -------------------------------------------------------------------

stopifnot(length(years_keep) == 2, length(N_cols) == 2)

##### Opt 2: Var - Smoothing: All Smooth variances

col_map <- tibble(
  year = years_keep,
  vcol = c("v1", "v2"),
  ncol = N_cols
)

# Detect whether varsmoothie_king() supports a 'y' argument (script-dependent)
has_y_arg <- "y" %in% names(formals(varsmoothie_king))

var_smooth_long <- pmap_dfr(col_map, function(year, vcol, ncol) {

  if (has_y_arg) {
    y_vec <- survey_step1 %>% filter(year == !!year) %>% pull(poor)

    out <- varsmoothie_king(
      domain     = all_var_hat_domain_dt$domain,
      direct_var = all_var_hat_domain_dt[[vcol]],
      sampsize   = all_var_hat_domain_dt[[ncol]],
      y          = y_vec
    )
  } else {
    out <- varsmoothie_king(
      domain     = all_var_hat_domain_dt$domain,
      direct_var = all_var_hat_domain_dt[[vcol]],
      sampsize   = all_var_hat_domain_dt[[ncol]]
    )
  }

  out %>%
    transmute(
      domain     = as.character(Domain),
      year       = as.integer(year),
      var_smooth = var_smooth
    )
})

# Wide: v1_sm_all, v2_sm_all (stable names regardless of actual years)
var_smooth_wide <- var_smooth_long %>%
  mutate(col = paste0("v", match(year, years_keep), "_sm_all")) %>%
  select(domain, col, var_smooth) %>%
  pivot_wider(names_from = col, values_from = var_smooth)

all_var_hat_domain_dt <- all_var_hat_domain_dt %>%
  left_join(var_smooth_wide, by = "domain")

rm(var_smooth_wide, var_smooth_long, has_y_arg, col_map)

###### Opt 3: Var - Threshold smoothing

# sm_out follows the same transparent rule as UFH: retain the direct
# sampling variance when it is finite and at least 0.001; otherwise use the
# regression-smoothed variance. Large direct variances are not replaced.

all_var_hat_domain_dt <- all_var_hat_domain_dt %>%
  mutate(
    v1_sm_out = sae_sm_out_variance(v1, v1_sm_all),
    v2_sm_out = sae_sm_out_variance(v2, v2_sm_all),
    # "direct" safety-backfilled variants: keep raw direct variances but
    # replace NA / exactly-zero values with smoothed ones so downstream MFH
    # fits don't error out. Matches UFH's "direct" safety backfill. (Direct
    # is intentionally NOT upper-tail-trimmed; sm_out replaces only
    # nonfinite or below-0.001 variances, not upper-tail values.)
    v1_direct = if_else(is.na(v1) | v1 == 0, v1_sm_all, v1),
    v2_direct = if_else(is.na(v2) | v2 == 0, v2_sm_all, v2)
  )




##### Option 1: Cov - Domain direct 

stopifnot(length(years_keep) == 2, length(N_cols) == 2)

# Ensure factor ordering matches years_keep (do NOT redefine years_keep here)
survey_step1$year <- factor(as.integer(survey_step1$year), levels = years_keep)
domain_list <- sort(unique(survey_step1$domain))

# Make domain-level svyby robust (domains can fail if a year has no data)
safe_svyby <- purrr::possibly(
  function(des_p) {
    out <- svyby(
      ~as.numeric(poor),
      ~year,
      des_p,
      svymean,
      covmat = TRUE,
      na.rm  = TRUE
    )
    vcov(out)
  },
  otherwise = NA_real_
)

svyby_out <- lapply(domain_list, function(p) {
  des_p <- subset(des, domain == p)
  list(domain = p, V = safe_svyby(des_p))
})

# Safely extract covariance using dimnames (robust to ordering)
y1_chr <- as.character(y1)
y2_chr <- as.character(y2)

covariances <- map_dfr(svyby_out, function(x) {
  V <- x$V

  v12 <- NA_real_
  if (is.matrix(V)) {
    rn <- rownames(V)
    cn <- colnames(V)

    v12 <- if (!is.null(rn) && !is.null(cn) && y1_chr %in% rn && y2_chr %in% cn) {
      V[y1_chr, y2_chr]
    } else {
      V[1, 2]
    }
  }

  tibble(
    domain = as.character(x$domain),
    v12_d  = as.numeric(v12)
  )
})

if (isTRUE(log_transform)) {
  .arith_pair <- direct_arith_domain_long %>%
    select(domain, year, direct_arith) %>%
    pivot_wider(names_from = year, values_from = direct_arith)
  .cov_match <- match(as.character(covariances$domain), as.character(.arith_pair$domain))
  covariances$v12_d <- covariances$v12_d /
    (.arith_pair[[as.character(y1)]][.cov_match] * .arith_pair[[as.character(y2)]][.cov_match])
}

print(covariances)

all_var_hat_domain_dt <- all_var_hat_domain_dt %>%
  left_join(covariances, by = "domain")

###### Option 2: Using national correlation coefficient

fit_nat_nolink_psu <- svyby(
  ~poor,
  ~year,
  des,
  svymean,
  covmat  = TRUE,
  na.rm   = TRUE,
  vartype = NULL
)

V_nat_nolink <- attr(fit_nat_nolink_psu, "var")
R_nat_nolink <- cov2cor(V_nat_nolink)

print(V_nat_nolink)

# Extract rho_12 robustly
rn <- rownames(R_nat_nolink)
cn <- colnames(R_nat_nolink)

rho_12 <- if (!is.null(rn) && !is.null(cn) && y1_chr %in% rn && y2_chr %in% cn) {
  R_nat_nolink[y1_chr, y2_chr]
} else {
  R_nat_nolink[1, 2]
}

if (psu_design == "independent") rho_12 <- 0

# Keep objects if you want diagnostics
nat_cov_no_link <- V_nat_nolink
nat_cor_no_link <- R_nat_nolink

# Opt 2_1: National correlation coefficient x direct variance estimate.
# Use v1_direct / v2_direct (the NA/zero-backfilled safety variants)
# rather than the raw v1 / v2. This is the covariance paired with
# `var_choice = "direct"` (whose diagonal uses v1_direct / v2_direct),
# so they must come from the same column to keep the sampling-error
# covariance matrix consistent: a raw NA on the diagonal that gets
# backfilled to v_sm_all would otherwise leave the off-diagonal at
# rho * sqrt(NA) * sqrt(.) = NA, and eblupMFH2() would abort with
# "Object vardir contains NA values". For non-NA, non-zero raw values
# v_direct == v exactly, so this is identical to the previous behaviour
# in the common case.
all_var_hat_domain_dt$v12_d_nc <-
  rho_12 * sqrt(all_var_hat_domain_dt$v1_direct) *
           sqrt(all_var_hat_domain_dt$v2_direct)

# Option 2_2: National correlation coefficient x variance (outlier-smoothed)
all_var_hat_domain_dt$v12_d_ncsm <-
  rho_12 * sqrt(all_var_hat_domain_dt$v1_sm_out) *
           sqrt(all_var_hat_domain_dt$v2_sm_out)

# Option 2_3: National correlation coefficient x fully smoothed variances
all_var_hat_domain_dt$v12_d_ncsm_all <-
  rho_12 * sqrt(all_var_hat_domain_dt$v1_sm_all) *
           sqrt(all_var_hat_domain_dt$v2_sm_all)

##### Option 3: Cov = 0

all_var_hat_domain_dt <- all_var_hat_domain_dt %>%
  select(domain, all_of(N_cols), everything())

all_var_hat_domain_dt$v12_zero <- 0

##### Cleanup: intermediate survey objects (recommended)
rm(
  svyby_out,          # per-domain svyby() results (already merged)
  covariances,        # merged already
  fit_nat_nolink_psu  # national svyby() object (used to extract V/R)
)




# ============================================================
# Step X: Build modeling dataset (domain_dt) + define candidates
#         + outcome/uncertainty table (dir_y_dt)
#         + stepwise AIC wrapper (stepAIC_wrapper)
#
# Assumes Pattern B objects already exist upstream:
#   years_keep (sorted), y1, y2
#   poor_cols, mse_cols, se_cols, N_cols
#   dir_est_domain_all_years, shp_dt, rhs_dt
# ============================================================

stopifnot(length(years_keep) == 2,
          length(poor_cols) == 2,
          length(mse_cols)  == 2,
          length(se_cols)   == 2,
          length(N_cols)    == 2)

# ---- Build RHS covariates for MFH without averaging time-varying signals ----
# Static covariates remain available under their original names. Covariates
# that vary across the selected years are pivoted to year-specific columns
# such as educ_2019 and educ_2020, so each MFH outcome can use the matching
# year's auxiliary signal.
rhs_cov_cols <- setdiff(names(rhs_dt), c("domain", "year"))
rhs_dt_selected <- rhs_dt %>%
  filter(as.integer(year) %in% years_keep)

.first_nonmissing <- function(x) {
  x <- x[!is.na(x)]
  if (length(x) == 0) NA else x[[1]]
}
.summarize_rhs_value <- function(x) {
  if (is.numeric(x)) {
    out <- mean(x, na.rm = TRUE)
    if (is.nan(out)) NA_real_ else out
  } else {
    .first_nonmissing(x)
  }
}
.rhs_varies_by_domain <- function(df, col) {
  any(vapply(split(df[[col]], df$domain), function(x) {
    x <- x[!is.na(x)]
    length(unique(x)) > 1
  }, logical(1)), na.rm = TRUE)
}

rhs_time_varying_cols <- rhs_cov_cols[
  vapply(rhs_cov_cols, function(col) .rhs_varies_by_domain(rhs_dt_selected, col), logical(1))
]
rhs_static_cols <- setdiff(rhs_cov_cols, rhs_time_varying_cols)

rhs_static <- if (length(rhs_static_cols) > 0) {
  rhs_dt_selected %>%
    group_by(domain) %>%
    summarize(across(all_of(rhs_static_cols), .first_nonmissing), .groups = "drop")
} else {
  tibble(domain = unique(rhs_dt_selected$domain))
}

rhs_wide <- if (length(rhs_time_varying_cols) > 0) {
  rhs_dt_selected %>%
    select(domain, year, all_of(rhs_time_varying_cols)) %>%
    group_by(domain, year) %>%
    summarize(across(all_of(rhs_time_varying_cols), .summarize_rhs_value), .groups = "drop") %>%
    tidyr::pivot_wider(
      names_from = year,
      values_from = all_of(rhs_time_varying_cols),
      names_glue = "{.value}_{year}"
    )
} else {
  tibble(domain = unique(rhs_dt_selected$domain))
}

rhs_dt_unique <- full_join(rhs_static, rhs_wide, by = "domain")
if (length(rhs_time_varying_cols) > 0) {
  cat(
    "MFH auxiliary covariates treated as time-varying: ",
    paste(rhs_time_varying_cols, collapse = ", "),
    ". Year-specific columns were created for each selected year.\n",
    sep = ""
  )
}

# ---- Build the domain-level modeling frame ----
domain_dt <- dir_est_domain_all_years %>%
  left_join(shp_dt,        by = "domain") %>%
  left_join(rhs_dt_unique, by = "domain")

# Drop direct-estimate uncertainty columns for selected years from the modeling frame
domain_dt <- domain_dt %>%
  select(-all_of(c(mse_cols, se_cols, N_cols)))

# ---- Candidate regressors (exclude id + outcomes + geometry) ----
candidate_vars_all <- setdiff(
  colnames(domain_dt),
  c("domain", poor_cols, "geometry")
)
candidate_vars_all <- sae_numeric_candidates(
  domain_dt, candidate_vars_all, context = "MFH covariate pool")

shp_candidate_cols <- setdiff(names(shp_dt), c("domain", "geometry"))
base_static_candidates <- intersect(
  c(shp_candidate_cols, rhs_static_cols),
  candidate_vars_all
)
.year_specific_rhs_candidates <- function(yr) {
  intersect(paste0(rhs_time_varying_cols, "_", yr), candidate_vars_all)
}
.default_candidates_for_year <- function(yr) {
  unique(c(base_static_candidates, .year_specific_rhs_candidates(yr)))
}
.resolve_user_candidates_for_year <- function(vars, yr) {
  if (is.null(vars) || length(vars) == 0) return(character(0))
  vars <- trimws(as.character(vars))
  vars <- vars[nzchar(vars)]
  resolved <- unlist(lapply(vars, function(v) {
    v_year <- paste0(v, "_", yr)
    if (v_year %in% candidate_vars_all) v_year else v
  }), use.names = FALSE)
  # A listed covariate that is not numeric cannot enter msae's design
  # matrix. Before w5j it was dropped silently from a fixed formula; now
  # the run says so (the step log and the app's warning summary).
  dropped <- setdiff(unique(resolved), candidate_vars_all)
  if (length(dropped) > 0L) {
    warning(sprintf(paste(
      "MFH %s: covariate(s) entered for this year are not used because they are",
      "not numeric: %s. Recode them as numeric indicators (0/1) to use them.%s"),
      yr, paste(dropped, collapse = ", "),
      if (length(dropped) == length(unique(resolved)) && !isTRUE(mfh_lasso_enabled))
        " No entered covariate is usable, so this year's MFH model has an intercept only." else ""),
      call. = FALSE)
  }
  intersect(candidate_vars_all, unique(resolved))
}

# Per-year candidate vars: if user specified per-year lists, filter accordingly;
# otherwise fall back to the full set of available candidates.
candidate_vars_per_year <- setNames(
  lapply(seq_along(poor_cols), function(i) {
    yr <- years_keep[i]
    yr_vars <- if (i == 1) mfh_candidate_vars_y1 else mfh_candidate_vars_y2
    if (!is.null(yr_vars) && length(yr_vars) > 0) {
      .resolve_user_candidates_for_year(yr_vars, yr)
    } else {
      .default_candidates_for_year(yr)
    }
  }),
  poor_cols
)

# Legacy: single candidate_vars used for display / downstream (union of per-year)
candidate_vars <- candidate_vars_all

# ---- Outcome + sampling-uncertainty table (selected years only) ----
dir_y_dt <- dir_est_domain_all_years %>%
  select(domain, all_of(c(poor_cols, se_cols, mse_cols, N_cols))) %>%
  distinct()

# ============================================================
# Stepwise variable selection wrapper (AIC)
#   - drops all-NA columns
#   - complete-case restriction
#   - drops aliased vars + near-linear combos + highly correlated vars
#   - then stepAIC in both directions
# ============================================================

stepAIC_wrapper <- function(dt, xvars, y, cor_thresh = 0.95, ic_criterion = "AIC") {

  dt <- data.table::as.data.table(dt)

  # Drop columns that are entirely NA
  dt <- dt[, which(unlist(lapply(dt, function(x) !all(is.na(x))))), with = FALSE]

  # Keep only requested xvars that still exist
  xvars <- xvars[xvars %in% colnames(dt)]

  # Keep only complete cases on y + xvars
  dt <- na.omit(dt[, c(y, xvars), with = FALSE])

  if (length(xvars) == 0) {
    stop("No candidate xvars remain after NA filtering / complete-case restriction.")
  }

  # Step 1: Remove aliased (perfectly collinear) variables
  model_formula <- as.formula(paste(y, "~", paste(xvars, collapse = " + ")))
  lm_model <- lm(model_formula, data = dt)
  aliased <- is.na(coef(lm_model))
  if (any(aliased)) {
    xvars <- names(aliased)[!aliased & names(aliased) != "(Intercept)"]
  }

  if (length(xvars) == 0) {
    stop("All xvars dropped due to perfect collinearity (aliased coefficients).")
  }

  # Step 2: Remove near-linear combinations
  xmat <- as.matrix(dt[, ..xvars])
  combo_check <- tryCatch(caret::findLinearCombos(xmat), error = function(e) NULL)
  if (!is.null(combo_check) && length(combo_check$remove) > 0) {
    xvars <- xvars[-combo_check$remove]
  }

  if (length(xvars) == 0) {
    stop("All xvars dropped by findLinearCombos().")
  }

  xmat <- as.matrix(dt[, ..xvars])

  # Step 3: Drop highly correlated variables
  cor_mat <- abs(cor(xmat))
  diag(cor_mat) <- 0

  while (any(cor_mat > cor_thresh, na.rm = TRUE) && length(xvars) > 1) {
    cor_pairs <- which(cor_mat == max(cor_mat, na.rm = TRUE), arr.ind = TRUE)[1, ]
    var1 <- colnames(cor_mat)[cor_pairs[1]]
    var2 <- colnames(cor_mat)[cor_pairs[2]]

    drop_var <- if (mean(cor_mat[var1, ], na.rm = TRUE) > mean(cor_mat[var2, ], na.rm = TRUE)) {
      var1
    } else {
      var2
    }

    xvars <- setdiff(xvars, drop_var)

    xmat <- as.matrix(dt[, ..xvars])
    cor_mat <- abs(cor(xmat))
    diag(cor_mat) <- 0
  }

  # Step 4: Warn if still ill-conditioned
  if (ncol(xmat) >= 2) {
    cond_number <- kappa(xmat, exact = TRUE)
    if (cond_number > 1e10) {
      warning("Design matrix is ill-conditioned (condition number > 1e10). Consider reviewing variable selection.")
    }
  }

  # Final model fit
  model_formula <- as.formula(paste(y, "~", paste(xvars, collapse = " + ")))
  full_model <- lm(model_formula, data = dt)

  # Stepwise selection (k = 2 for AIC, k = log(n) for BIC)
  k_val <- if (identical(ic_criterion, "BIC")) log(nrow(dt)) else 2
  MASS::stepAIC(full_model, direction = "both", trace = 0, k = k_val)
}




### the set of outcome variables (Pattern B)
outcome_list <- poor_cols

# Check whether the user forced specific covariates for each year
# A custom list is a fixed formula only when LASSO is off.  When LASSO is on,
# the same list is the per-year candidate pool to be screened.
user_forced_y1 <- !isTRUE(mfh_lasso_enabled) &&
  !is.null(mfh_candidate_vars_y1) && length(mfh_candidate_vars_y1) > 0
user_forced_y2 <- !isTRUE(mfh_lasso_enabled) &&
  !is.null(mfh_candidate_vars_y2) && length(mfh_candidate_vars_y2) > 0
mfh_selection_diagnostics_list <- list()

### applying variable selection to each outcome variable (per-year candidate vars)
stepaicmodel_list <- setNames(
  lapply(seq_along(outcome_list), function(i) {
    yname <- outcome_list[i]
    user_forced <- if (i == 1) user_forced_y1 else user_forced_y2

    # Use per-year candidate vars, excluding outcome columns
    yr_candidates <- setdiff(candidate_vars_per_year[[yname]], outcome_list)

    if (user_forced) {
      # User specified covariates: use them directly (skip stepwise)
      cat(sprintf("Using user-specified covariates for %s: %s\n",
                  yname, paste(yr_candidates, collapse = ", ")))
      mfh_selection_diagnostics_list[[yname]] <<- data.frame(
        model = paste("MFH", years_keep[i]),
        outcome = yname,
        lasso_enabled = FALSE,
        lambda_choice = mfh_lasso_lambda,
        n_candidates = length(yr_candidates),
        n_numeric_candidates = NA_integer_,
        n_complete_cases = NA_integer_,
        n_selected = length(yr_candidates),
        selected_variables = paste(yr_candidates, collapse = ", "),
        stepwise_candidates = paste(yr_candidates, collapse = ", "),
        fallback_used = FALSE,
        note = "User-specified covariates supplied; fixed formula used and automated selection skipped.",
        stringsAsFactors = FALSE
      )
      yr_candidates
    } else {
      lasso <- sae_lasso_screen(
        dt = domain_dt,
        xvars = yr_candidates,
        y = yname,
        enabled = mfh_lasso_enabled,
        lambda_choice = mfh_lasso_lambda,
        label = paste("MFH", years_keep[i]),
        seed = analysis_seed + as.integer(years_keep[i])
      )
      mfh_selection_diagnostics_list[[yname]] <<- lasso$diagnostics
      cat(sprintf("MFH %s LASSO screen: %s\n", years_keep[i],
                  lasso$diagnostics$note[[1]]))
      if (nzchar(lasso$diagnostics$selected_variables[[1]])) {
        cat("MFH", years_keep[i], "LASSO-selected variables:",
            lasso$diagnostics$selected_variables[[1]], "\n")
      }
      if (length(lasso$vars) == 0L) {
        cat("MFH", years_keep[i],
            "has no safe covariates for stepwise selection; using intercept-only formula.\n")
        character()
      } else {
        # No user specification: run stepwise selection
        fit <- stepAIC_wrapper(
          dt           = domain_dt,
          xvars        = lasso$vars,
          y            = yname,
          cor_thresh   = 0.8,
          ic_criterion = mfh_ic_criterion
        )

        # keep only selected regressors (drop intercept)
        sel <- names(coef(fit))
        sel <- setdiff(sel, "(Intercept)")
        sel
      }
    }
  }),
  outcome_list
)

### now create a list of equations (formulas)
mfh_formula <- mapply(
  FUN = function(outcome, rhs_vars) {
    if (length(rhs_vars) == 0) {
      as.formula(paste0(outcome, " ~ 1"))
    } else {
      as.formula(paste0(outcome, " ~ ", paste(rhs_vars, collapse = " + ")))
    }
  },
  outcome_list,
  stepaicmodel_list,
  SIMPLIFY = FALSE
)

mfh_formula

dir.create(here::here("outputs", "tables"), showWarnings = FALSE, recursive = TRUE)
mfh_selection_diagnostics <- dplyr::bind_rows(mfh_selection_diagnostics_list)
write.csv(
  mfh_selection_diagnostics,
  here::here("outputs", "tables", "mfh_selection_diagnostics.csv"),
  row.names = FALSE
)



# ============================================================
# Model checking: OLS fits implied by MFH formulas
# ============================================================

# Baseline: fit OLS models using the selected MFH formulas
lmcheck_obj <- lapply(
  X   = mfh_formula,
  FUN = lm,
  data = domain_dt
)

# Inspect baseline results
lm_summaries <- lapply(lmcheck_obj, summary)
lm_summaries









# ============================================================
# Objective: Attach sampling variance/covariance inputs to domain_dt
#            and select the var-cov components to feed into MFH
# ============================================================

# 1) Attach sampling uncertainty columns (v1/v2/etc.) to the modeling frame
domain_dt <- domain_dt %>%
  left_join(all_var_hat_domain_dt, by = "domain")

# 2) Define the available variance and covariance "menus"
#    (These names are stable across years because v1/v2 refer to y1/y2 ordering.)

var_menu <- list(
  direct   = c("v1_direct", "v2_direct"),# domain direct variances, NA/zero backfilled
  sm_out   = c("v1_sm_out", "v2_sm_out"),# threshold-smoothed variances
  sm_all   = c("v1_sm_all", "v2_sm_all") # all variances replaced with smoothed
)

cov_menu <- list(
  direct     = "v12_d",           # domain direct covariance (if available)
  rho_dir    = "v12_d_nc",        # national rho * sqrt(v1*v2)
  rho_sm_out     = "v12_d_ncsm",      # national rho * sqrt(v1_sm_out*v2_sm_out)
  rho_sm_all = "v12_d_ncsm_all",  # national rho * sqrt(v1_sm_all*v2_sm_all)
  zero       = "v12_zero"         # covariance set to zero
)

# 3) Choose which variance and covariance definitions to use
var_choice <- sae_variance_choice(mfh_cfg$var_choice)
cov_choice <- if (psu_design == "independent") "zero" else
  sae_covariance_choice(mfh_cfg$cov_choice, var_choice)

# 4) Build the chosen column-name vector (to pass downstream)
vardir_cols <- c(var_menu[[var_choice]], cov_menu[[cov_choice]])

# 5) Defensive checks: ensure the chosen columns exist
missing_cols <- setdiff(vardir_cols, names(domain_dt))
if (length(missing_cols) > 0) {
  stop(
    "Chosen variance/covariance columns not found in domain_dt: ",
    paste(missing_cols, collapse = ", "),
    "\nCheck that earlier variance/covariance steps were executed and the choices are valid."
  )
}

vardir_cols



# ============================================================
# Objective: Estimate UFH/MFH models using the chosen sampling
#            variance--covariance inputs, then compare model-based
#            poverty estimates (EBLUP, MSE, CV) against direct
#            estimates in a tidy (wide) table for export.
# ============================================================

# ---- 0) Fit models (UFH + MFH variants) using the chosen vardir columns ----
# Assumes already defined upstream:
#   - mfh_formula (list of formulas, one per outcome)
#   - vardir_cols (chosen variance/covariance columns, e.g., c("v1_sm_out","v2_sm_out","v12_d_ncsm"))
#   - domain_dt (modeling frame, already joined with all_var_hat_domain_dt)

# Upfront input check: eblupMFH*() requires every entry of vardir to be a
# finite number. When var_choice = "direct", some domains may have missing
# variances (e.g., single-PSU domains). We drop those domains from the
# fitting data and fit the model on the valid subset; excluded domains
# get NA results in the output tables.
.vardir_mat <- as.matrix(domain_dt[, vardir_cols, drop = FALSE])
.vardir_bad <- !is.finite(.vardir_mat)
.bad_row_mask <- rowSums(.vardir_bad) > 0
.n_bad_rows <- sum(.bad_row_mask)
.excluded_domains <- if (.n_bad_rows > 0) domain_dt$domain[.bad_row_mask] else character(0)
.all_domains_dt <- domain_dt

if (.n_bad_rows > 0) {
  cat(
    "\n**Note:** ", .n_bad_rows, " of ", nrow(domain_dt),
    " domain(s) have missing/non-finite vardir values (",
    paste0("`", vardir_cols, "`", collapse = ", "),
    "). These domains are excluded from MFH fitting and will have NA results.\n\n",
    sep = ""
  )
  domain_dt <- domain_dt[!.bad_row_mask, , drop = FALSE]
}

# Repair once; every original fit and bootstrap refit uses these same matrices.
.sampling_covariance <- sae_mfh_prepare_sampling_covariance(
  domain_dt, vardir_cols, length(mfh_formula), repair = TRUE)
domain_dt <- .sampling_covariance$data
if (any(.sampling_covariance$diagnostics$repaired)) {
  cat(sum(.sampling_covariance$diagnostics$repaired),
      "domain sampling covariance matrices were repaired before fitting; inspect mfh_sampling_covariance.csv.\n")
}
.sampling_covariance$diagnostics$domain <- as.character(domain_dt$domain)
write.csv(.sampling_covariance$diagnostics,
          here::here("outputs", "tables", "mfh_sampling_covariance.csv"), row.names = FALSE)

.fit_skipped <- FALSE
.mfh_fitted_domain_ids <- trimws(as.character(domain_dt$domain))
if (any(is.na(.mfh_fitted_domain_ids) | !nzchar(.mfh_fitted_domain_ids))) {
  stop("MFH modeling data contains missing or blank domain IDs after vardir filtering.")
}
if (anyDuplicated(.mfh_fitted_domain_ids)) {
  stop(
    "MFH modeling data contains duplicate domain IDs after vardir filtering: ",
    paste(unique(.mfh_fitted_domain_ids[duplicated(.mfh_fitted_domain_ids)]), collapse = ", ")
  )
}
domain_dt$domain <- .mfh_fitted_domain_ids
rownames(domain_dt) <- .mfh_fitted_domain_ids

model_ufh  <- eblupUFH(mfh_formula, vardir = vardir_cols, data = domain_dt, MAXITER = 100, PRECISION = 1e-04)
model_mfh1 <- eblupMFH1(mfh_formula, vardir = vardir_cols, data = domain_dt, MAXITER = 100, PRECISION = 1e-04)
model_mfh2 <- eblupMFH2(mfh_formula, vardir = vardir_cols, data = domain_dt, MAXITER = 100, PRECISION = 1e-04)
.mfh3_failure_type <- NA_character_
.mfh3_failure_message <- NA_character_
.mfh3_iterations <- NA_integer_
model_mfh3 <- NULL
.model_mfh3_attempt <- NULL
if (fit_mfh3) {
  model_mfh3 <- tryCatch(
    eblupMFH3(mfh_formula, vardir = vardir_cols, data = domain_dt, MAXITER = 100, PRECISION = 1e-04),
    error = function(e) {
      .mfh3_failure_type <<- "computational_error"
      .mfh3_failure_message <<- conditionMessage(e)
      cat(
        "\n**Note:** MFH3 (heteroskedastic) model encountered a computational error.\n",
        "Technical error: ", .mfh3_failure_message, "\n",
        "MFH3 estimation is unavailable. ",
        "Downstream results will use MFH1/MFH2 (and UFH for diagnostics) only.\n\n",
        sep = ""
      )
      NULL
    }
  )
  .model_mfh3_attempt <- model_mfh3
  if (!is.null(model_mfh3)) {
    .mfh3_iterations <- suppressWarnings(as.integer(model_mfh3$fit$iterations %||% NA_integer_))
    if (!sae_mfh_fit_usable(model_mfh3, "MFH3", mfh_formula, vardir_cols, domain_dt)) {
      .model_mfh3_attempt$fit$convergence <- FALSE
      .mfh3_failure_type <- "non_convergence"
      .mfh3_failure_message <- paste0(
        "The MFH3 fit did not pass the convergence and REML endpoint checks",
        if (is.finite(.mfh3_iterations)) paste0(" after ", .mfh3_iterations, " iterations") else "",
        "."
      )
      cat(
        "\n**Note:** MFH3 (heteroskedastic) model did not converge",
        if (is.finite(.mfh3_iterations)) paste0(" after ", .mfh3_iterations, " iterations") else "",
        ".\nMFH3 estimation is skipped. Downstream results will use MFH1/MFH2 ",
        "(and UFH for diagnostics) only.\n\n",
        sep = ""
      )
      model_mfh3 <- NULL
    }
  }
  if (is.null(model_mfh3)) fit_mfh3 <- FALSE
}
rm(.vardir_mat, .vardir_bad, .bad_row_mask)

# ---- Molina-Romero MFH3/MFH2 variance-structure decision ----
if (diag_model_requested %in% c("AUTO", "MFH3")) {
  .mfh_variance_selection <- sae_choose_mfh_variance_structure(
    model_mfh3 = .model_mfh3_attempt,
    alpha = refvar_alpha,
    adjustment = refvar_adjustment,
    fit_error = if (identical(.mfh3_failure_type, "computational_error")) {
      .mfh3_failure_message
    } else {
      NULL
    }
  )
  diag_model <- .mfh_variance_selection$selected_model
} else {
  diag_model <- diag_model_requested
  .mfh_variance_selection <- list(
    requested_model = diag_model_requested,
    selected_model = diag_model,
    reason_code = "manual_model_choice",
    reason = paste0(
      "The user selected ", diag_model,
      " directly; the automatic MFH3/MFH2 variance-structure rule was not applied."
    ),
    mfh3_converged = sae_mfh_model_converged(.model_mfh3_attempt),
    test_available = FALSE,
    adjustment = refvar_adjustment,
    alpha = refvar_alpha,
    tests = data.frame()
  )
}
cat("\nMFH variance-structure selection: ",
    .mfh_variance_selection$reason, "\n\n", sep = "")
write.csv(
  sae_mfh_selection_export(
    .mfh_variance_selection,
    requested_model = diag_model_requested
  ),
  here::here("outputs", "tables", "mfh_variance_structure_selection.csv"),
  row.names = FALSE
)

# ---- Model lookup for diagnostics and downstream analysis ----
# Only multivariate variants are valid choices for the diagnostic model.
# UFH is still fitted (it appears in diagnostics/comparison tables), but
# it cannot be selected as the driver of the Comparison report -- its
# analysis lives in 40-fh_v2.qmd.
model_lookup <- list(MFH1 = model_mfh1, MFH2 = model_mfh2)
if (fit_mfh3) model_lookup[["MFH3"]] <- model_mfh3

if (!diag_model %in% names(model_lookup)) {
  fallback <- "MFH2"
  cat(
    "\n**Note:** diag_model = \"", diag_model, "\" is not available ",
    "(valid options are ",
    paste(shQuote(names(model_lookup)), collapse = ", "),
    "; MFH3 requires fit_mfh3 = TRUE and successful convergence).\n",
    "Falling back to \"", fallback, "\" for post-estimation diagnostics.\n\n",
    sep = ""
  )
  diag_model <- fallback
}
selected_model <- model_lookup[[diag_model]]

# ---- REML check at msae's end point (R/mfh_convergence_check.R) ----
# msae's estimates are kept; this records whether each fitted MFH model
# stopped at a REML maximum and warns when the selected model did not.
.mfh_conv_models <- list(MFH1 = model_mfh1, MFH2 = model_mfh2,
                         MFH3 = .model_mfh3_attempt)
.mfh_conv_models <- .mfh_conv_models[!vapply(.mfh_conv_models, is.null, logical(1))]
.mfh_conv_checks <- lapply(names(.mfh_conv_models), function(m) {
  sae_mfh_reml_endpoint(.mfh_conv_models[[m]], m, mfh_formula, vardir_cols, domain_dt)
})
.mfh_conv_tbl <- do.call(rbind, lapply(.mfh_conv_checks, sae_mfh_check_row,
                                       selected_model = diag_model))
.mfh_boundary_checks <- setNames(lapply(names(.mfh_conv_models), function(model_name) {
  tryCatch(sae_mfh_covariance_boundary(.mfh_conv_models[[model_name]], model_name),
           error = function(e) NULL)
}), names(.mfh_conv_models))
for (.j in if (is.null(.mfh_conv_tbl)) integer() else seq_len(nrow(.mfh_conv_tbl))) {
  .b <- .mfh_boundary_checks[[as.character(.mfh_conv_tbl$model[.j])]]
  .mfh_conv_tbl$covariance_boundary[.j] <- if (is.null(.b)) NA else .b$boundary
  .mfh_conv_tbl$variance_zero[.j] <- if (is.null(.b)) NA else .b$variance_zero
  .mfh_conv_tbl$correlation_limit[.j] <- if (is.null(.b)) NA else .b$correlation_limit
  .mfh_conv_tbl$inference_status[.j] <- if (is.null(.b) || .mfh_conv_tbl$status[.j] != "ok")
    "unavailable" else .b$inference_status
}
dir.create(here::here("outputs", "tables"), showWarnings = FALSE, recursive = TRUE)
write.csv(.mfh_conv_tbl, here::here("outputs", "tables", "mfh_convergence_check.csv"),
          row.names = FALSE)
cat("\nREML check at msae's end point (outputs/tables/mfh_convergence_check.csv):\n")
for (.chk in .mfh_conv_checks) {
  .is_sel <- identical(.chk$model, diag_model)
  cat(sprintf("  %s%s: %s. %s\n", .chk$model, if (.is_sel) " (selected)" else "",
              .chk$status, .chk$message))
  if (.is_sel && !identical(.chk$status, "ok")) {
    warning(sprintf(paste(
      "%s (selected MFH model): %s This endpoint cannot support inference; see",
      "outputs/tables/mfh_convergence_check.csv and the",
      "'MFH Convergence Check' section of the report."), .chk$model, .chk$message),
      call. = FALSE)
  }
}
rm(.chk)

# Detect a wholesale fit failure (selected_model is NULL or its fit object
# is empty). This happens when something further upstream made eblupMFH*()
# error out before producing any object -- most often a NA in vardir that
# the safety backfills missed. Without this guard, the downstream NA-fill
# fallbacks render a successful-looking HTML even though the model itself
# never ran. Surface it loudly so it can't be missed.
.model_fit_failed <- is.null(selected_model) ||
  is.null(selected_model$fit) ||
  is.null(selected_model$fit$refvar) ||
  length(selected_model$fit$refvar) == 0 ||
  !sae_mfh_fit_usable(selected_model, diag_model, mfh_formula, vardir_cols, domain_dt)

# Zero innovations do not imply zero G in MFH3 because u0 is retained.
# A genuine zero covariance is a legal model boundary, not a bootstrap failure.
.refvar_zero <- if (.model_fit_failed) FALSE else
  all(abs(sae_mfh_G(diag_model, sae_mfh_theta(selected_model, diag_model))) <= 1e-12)
.covariance_boundary <- if (.model_fit_failed) NULL else
  sae_mfh_covariance_boundary(selected_model, diag_model)
.inference_status <- if (.model_fit_failed) "unavailable" else
  .covariance_boundary$inference_status
.inference_warning <- if (identical(.inference_status, "boundary_sensitive"))
  sae_mfh_boundary_warning() else ""
.covariance_boundary_reason <- if (is.null(.covariance_boundary)) "fit_unavailable" else
  .covariance_boundary$reason
if (nzchar(.inference_warning)) {
  cat("\n--- MFH CHANGE SIGNIFICANCE IS PROVISIONAL ---\n", .inference_warning, "\n\n", sep = "")
  warning(.inference_warning, call. = FALSE)
}
if (!.model_fit_failed) {
  selected_model$fit$inference_status <- .inference_status
  selected_model$fit$covariance_boundary <- .covariance_boundary
}

# Diagnostic: did the robust optim() fallback get used for any of the
# candidate models? Surfaced as a small note so the user can see when
# msae's standard implementation was overridden.
.robust_used <- vapply(
  list(MFH1 = model_mfh1, MFH2 = model_mfh2,
       MFH3 = if (exists("model_mfh3")) model_mfh3 else NULL),
  function(m) isTRUE(attr(m, ".robust_refit_used")),
  logical(1)
)
.robust_failed <- vapply(
  list(MFH1 = model_mfh1, MFH2 = model_mfh2,
       MFH3 = if (exists("model_mfh3")) model_mfh3 else NULL),
  function(m) isTRUE(attr(m, ".robust_refit_failed")),
  logical(1)
)

# Save artifacts needed by Comparison_v2.qmd
dir.create(here::here("outputs", "data"), showWarnings = FALSE, recursive = TRUE)
saveRDS(
  list(
    years_keep       = years_keep,
    selected_model   = selected_model,
    convergence_check = .mfh_conv_tbl,
    # A formula keeps its creating environment; do not save survey rows with it.
    formula          = lapply(mfh_formula, function(f) { environment(f) <- globalenv(); f }),
    diag_model_requested = diag_model_requested,
    diag_model       = diag_model,
    variance_structure_selection = .mfh_variance_selection,
    refvar_adjustment = refvar_adjustment,
    refvar_alpha = refvar_alpha,
    refvar_zero      = .refvar_zero,
    model_fit_failed = .model_fit_failed,
    inference_valid = !.model_fit_failed,
    inference_status = .inference_status,
    covariance_boundary = .covariance_boundary,
    covariance_boundary_reason = .covariance_boundary_reason,
    inference_warning = .inference_warning,
    sampling_covariance = .sampling_covariance$diagnostics,
    residual_method = "RPR_standardized",
    fit_skipped      = .fit_skipped,
    var_choice       = var_choice,
    cov_choice       = cov_choice,
    psu_design       = psu_design,
    vardir_cols       = vardir_cols,
    bad_vardir_rows   = .n_bad_rows,
    excluded_domains  = .excluded_domains,
    n_domains         = nrow(.all_domains_dt),
    n_domains_fitted  = nrow(domain_dt),
    mfh3_requested    = isTRUE(fit_mfh3_requested),
    mfh3_available    = isTRUE(fit_mfh3),
    mfh3_failure_type = .mfh3_failure_type,
    mfh3_failure_message = .mfh3_failure_message,
    mfh3_iterations   = .mfh3_iterations
  ),
  file = here::here("outputs", "data", "mfh_artifacts.rds")
)

.run_metadata_path <- here::here("outputs", "data", "run_metadata.rds")
if (file.exists(.run_metadata_path)) {
  .run_metadata <- tryCatch(readRDS(.run_metadata_path), error = function(e) NULL)
  if (is.list(.run_metadata)) {
    .run_metadata$psu_design <- psu_design
    .run_metadata$psu_design_label <- sae_psu_design_label(psu_design)
    .run_metadata$psu_design_warning <- .psu_overlap_warning
    .run_metadata$mfh_cov_choice <- cov_choice
    .run_metadata$mfh_requested_model <- diag_model_requested
    .run_metadata$mfh_selected_model <- diag_model
    .run_metadata$mfh_inference_status <- .inference_status
    .run_metadata$mfh_covariance_boundary_reason <- .covariance_boundary_reason
    .run_metadata$mfh_inference_warning <- .inference_warning
    .run_metadata$mfh_variance_structure_selection <- list(
      reason_code = .mfh_variance_selection$reason_code,
      reason = .mfh_variance_selection$reason,
      mfh3_converged = .mfh_variance_selection$mfh3_converged,
      test_available = .mfh_variance_selection$test_available,
      adjustment = .mfh_variance_selection$adjustment,
      alpha = .mfh_variance_selection$alpha
    )
    saveRDS(.run_metadata, .run_metadata_path)
  }
}

.selected_refvar <- if (!isTRUE(.model_fit_failed) &&
                        is.list(selected_model$fit) &&
                        !is.null(selected_model$fit$refvar)) {
  suppressWarnings(as.numeric(unlist(selected_model$fit$refvar)))
} else {
  NA_real_
}
# MFH1 and MFH3 estimate one random-effect variance per year (sigma2_1, sigma2_2,
# as in the MFH Convergence Check); MFH2 has one common variance. Report the
# year's own value instead of the average of the two years.
.refvar_for_year <- function(i) {
  if (toupper(diag_model) %in% c("MFH1", "MFH3") &&
      length(.selected_refvar) >= length(mfh_formula)) {
    .selected_refvar[[i]]
  } else {
    .selected_refvar[[1]]
  }
}
mfh_model_diagnostics <- dplyr::bind_rows(lapply(seq_along(mfh_formula), function(i) {
  sae_model_fit_diagnostics(
    method = diag_model,
    year = years_keep[i],
    formula = mfh_formula[[i]],
    data = domain_dt,
    mixed_model = NULL,
    random_variance = .refvar_for_year(i),
    note = "R2 columns are OLS companion diagnostics for the selected formula."
  )
}))
write.csv(
  mfh_model_diagnostics,
  here::here("outputs", "tables", "mfh_model_diagnostics.csv"),
  row.names = FALSE
)

# If the MFH fit failed outright, write the minimal artifacts that the
# Comparison step needs, then raise a typed condition.
if (isTRUE(.model_fit_failed)) {
  direct_long_rate <- dir_est_domain_all_years %>%
    select(domain, all_of(poor_cols)) %>%
    pivot_longer(-domain, names_to = "year_raw", values_to = "direct_rate") %>%
    mutate(year = as.integer(gsub("^.*?(\\d{4})$", "\\1", year_raw))) %>%
    select(domain, year, direct_rate)

  direct_long_mse <- dir_est_domain_all_years %>%
    select(domain, all_of(mse_cols)) %>%
    pivot_longer(-domain, names_to = "year_raw", values_to = "direct_mse") %>%
    mutate(year = as.integer(gsub("^.*?(\\d{4})$", "\\1", year_raw))) %>%
    select(domain, year, direct_mse)

  db_wide_all <- left_join(direct_long_rate, direct_long_mse, by = c("domain", "year")) %>%
    mutate(
      direct_cv   = if_else(direct_rate > 0, sqrt(direct_mse) / direct_rate, NA_real_),
      direct_rmse = sqrt(direct_mse)
    ) %>%
    arrange(year, domain)

  for (.model_name in c(ufh_msae_code, "MFH1", "MFH2", "MFH3")) {
    db_wide_all[[paste0("rate_", .model_name)]] <- NA_real_
    db_wide_all[[paste0("mse_", .model_name)]]  <- NA_real_
    db_wide_all[[paste0("cv_", .model_name)]]   <- NA_real_
    db_wide_all[[paste0("rmse_", .model_name)]] <- NA_real_
  }
  .selected_mfh_cols <- paste0(c("rate_", "mse_", "cv_", "rmse_"), diag_model)
  .all_mfh_cols <- grep("^(rate|mse|cv|rmse)_MFH[123]$", names(db_wide_all),
                        value = TRUE)
  .drop_mfh_cols <- setdiff(.all_mfh_cols, .selected_mfh_cols)
  db_wide_export <- db_wide_all %>%
    select(-any_of(.drop_mfh_cols))
  db_wide_export <- sae_enrich_result_table(
    db_wide_export,
    domain_metadata = domain_metadata,
    population = domain_population,
    poverty_lines = poverty_line_export
  )

  dir.create(here::here("outputs", "data"), showWarnings = FALSE, recursive = TRUE)
  dir.create(here::here("outputs", "tables"), showWarnings = FALSE, recursive = TRUE)
  .write_xlsx_safe(db_wide_export, here::here("outputs", "data", "pov_mfh.xlsx"))

  change_placeholder <- data.frame(
    domain      = sort(unique(as.character(db_wide_all$domain))),
    diff        = NA_real_,
    mse         = NA_real_,
    lb          = NA_real_,
    ub          = NA_real_,
    significant = NA
  )
  write.csv(change_placeholder,
            here::here("outputs", "tables", "comparison_final.csv"),
            row.names = FALSE)
  if (isTRUE(do_benchmark)) {
    write.csv(change_placeholder,
              here::here("outputs", "tables", "comparison_final_bench.csv"),
              row.names = FALSE)
  }
  write.csv(
    data.frame(
      method = character(),
      year = integer(),
      component = character(),
      n = integer(),
      W = numeric(),
      p_value = numeric()
    ),
    here::here("outputs", "tables", "mfh_shapiro_results.csv"),
    row.names = FALSE
  )

  .reason <- sprintf(
    "MFH unavailable: selected model '%s' did not pass the REML convergence check.",
    diag_model
  )
  stop(structure(
    list(message = .reason, call = NULL),
    class = c("sae_mfh_unavailable", "error", "condition")
  ))
}

# Dynamic column names for the selected model
rate_col     <- paste0("rate_", diag_model)
mse_col_diag <- paste0("mse_", diag_model)

domain_vec <- trimws(as.character(domain_dt$domain))

.mfh_output_domains <- function(output_df, model_name, fallback_domains, output_label) {
  output_df <- as.data.frame(output_df)
  fallback_domains <- trimws(as.character(fallback_domains))
  n_out <- nrow(output_df)
  rn <- rownames(output_df)
  has_domain_rownames <- !is.null(rn) &&
    length(rn) == n_out &&
    !all(rn == as.character(seq_len(n_out)))

  if (has_domain_rownames) {
    rn <- trimws(as.character(rn))
    if (any(is.na(rn) | !nzchar(rn))) {
      stop(model_name, " ", output_label, " has missing or blank row names; cannot attach domains safely.")
    }
    if (!all(rn %in% fallback_domains)) {
      bad <- setdiff(rn, fallback_domains)
      stop(
        model_name, " ", output_label,
        " row names do not match the MFH modeling domains. Unmatched row names: ",
        paste(head(bad, 10), collapse = ", ")
      )
    }
    return(rn)
  }

  if (n_out != length(fallback_domains)) {
    stop(
      model_name, " ", output_label, " returned ", n_out,
      " rows, but the MFH modeling data has ", length(fallback_domains),
      " domains. This usually means the model dropped rows internally; ",
      "domain labels cannot be attached safely."
    )
  }

  fallback_domains
}

.mfh_align_direct_rows <- function(output_df, model_name, fallback_domains, output_label) {
  output_domains <- .mfh_output_domains(output_df, model_name, fallback_domains, output_label)
  direct_rows <- domain_dt %>%
    mutate(.mfh_domain_key = trimws(as.character(domain))) %>%
    filter(.mfh_domain_key %in% output_domains) %>%
    arrange(match(.mfh_domain_key, output_domains))

  if (!identical(direct_rows$.mfh_domain_key, output_domains)) {
    missing_direct <- setdiff(output_domains, direct_rows$.mfh_domain_key)
    stop(
      model_name, " ", output_label,
      " domains could not be matched back to the MFH direct estimates: ",
      paste(head(missing_direct, 10), collapse = ", ")
    )
  }

  direct_rows
}

# ---- 1) Helper: convert model outputs (EBLUP + MSE) to long ----
make_long_model <- function(model_obj, model_name, domain_vec) {

  eb  <- as.data.frame(model_obj$eblup)
  mse <- as.data.frame(model_obj$MSE)
  if (model_name %in% c("MFH1", "MFH2", "MFH3")) {
    if (!sae_mfh_fit_usable(model_obj, model_name, mfh_formula, vardir_cols, domain_dt)) {
      mse[,] <- NA_real_
    }
    if (isTRUE(log_transform)) {
      converted <- tryCatch(sae_mfh_estimate_matrix(model_obj, model_name,
        domain_dt, vardir_cols, back_transform = "log", bias_correction = mfh_bias_correction),
        error = function(e) matrix(NA_real_, nrow(eb), ncol(eb)))
      eb[,] <- converted
      # Selected-model MSE comes from the original-scale joint bootstrap below.
      mse[,] <- NA_real_
    }
  } else if (isTRUE(log_transform)) {
    # This auxiliary UFH is diagnostic; the EMDI UFH is in the UFH step.
    eb[,] <- exp(as.matrix(eb))
    mse[,] <- NA_real_
  }
  eb_domains <- .mfh_output_domains(eb, model_name, domain_vec, "EBLUP")
  mse_domains <- .mfh_output_domains(mse, model_name, domain_vec, "MSE")
  if (!identical(eb_domains, mse_domains)) {
    stop(model_name, " EBLUP and MSE outputs have different domain ordering; cannot combine safely.")
  }

  eb_long <- eb %>%
    mutate(domain = eb_domains) %>%
    pivot_longer(-domain, names_to = "year_raw", values_to = "rate")

  mse_long <- mse %>%
    mutate(domain = mse_domains) %>%
    pivot_longer(-domain, names_to = "year_raw", values_to = "mse")

  out <- left_join(eb_long, mse_long, by = c("domain", "year_raw")) %>%
    mutate(
      year  = as.integer(gsub("^.*?(\\d{4})$", "\\1", year_raw)),
      cv    = .safe_cv(mse, rate),
      model = model_name
    ) %>%
    select(domain, year, model, rate, mse, cv)

  out
}

# ---- 2) Stack model results and reshape wide ----
db_long_list <- list(
  make_long_model(model_ufh,  ufh_msae_code,  domain_vec),
  make_long_model(model_mfh1, "MFH1", domain_vec),
  make_long_model(model_mfh2, "MFH2", domain_vec)
)
if (fit_mfh3) db_long_list[["MFH3"]] <- make_long_model(model_mfh3, "MFH3", domain_vec)
db_long <- bind_rows(db_long_list)

db_wide <- db_long %>%
  pivot_wider(
    names_from  = model,
    values_from = c(rate, mse, cv),
    names_sep   = "_"
  ) %>%
  arrange(year, domain)

# ---- 3) Direct estimates for the selected years (Pattern B: no hard-codes) ----
# Assumes upstream:
#   - dir_est_domain_all_years has columns poor_cols (e.g., poor_YYYY) and mse_cols (mse_YYYY)
#   - poor_cols, mse_cols defined from years_keep

direct_long_rate <- dir_est_domain_all_years %>%
  select(domain, all_of(poor_cols)) %>%
  pivot_longer(-domain, names_to = "year_raw", values_to = "direct_rate") %>%
  mutate(year = as.integer(gsub("^.*?(\\d{4})$", "\\1", year_raw)))

direct_long_mse <- dir_est_domain_all_years %>%
  select(domain, all_of(mse_cols)) %>%
  pivot_longer(-domain, names_to = "year_raw", values_to = "direct_mse") %>%
  mutate(year = as.integer(gsub("^.*?(\\d{4})$", "\\1", year_raw)))

direct_long <- left_join(direct_long_rate, direct_long_mse, by = c("domain", "year")) %>%
  mutate(direct_cv = .safe_cv(direct_mse, direct_rate)) %>%
  select(domain, year, direct_rate, direct_mse, direct_cv)

if (isTRUE(log_transform)) {
  direct_long <- direct_arith_domain_long %>%
    transmute(domain, year, direct_rate = direct_arith, direct_mse = SD_arith^2,
              direct_cv = .safe_cv(direct_mse, direct_rate))
}

# ---- 4) Combine model-based + direct into one comparison table ----
# Use full_join so domains excluded from MFH fitting (missing vardir)
# still appear with direct estimates and NA for model columns.
db_wide_all <- direct_long %>%
  full_join(db_wide, by = c("domain", "year")) %>%
  relocate(direct_rate, direct_mse, direct_cv, .after = year)

# ---- Add RMSE columns (sqrt of each MSE) ----
db_wide_all <- db_wide_all %>%
  mutate(
    direct_rmse = sqrt(direct_mse),
    !!.ufh_col("rmse") := sqrt(.data[[.ufh_col("mse")]]),
    rmse_MFH1   = sqrt(mse_MFH1),
    rmse_MFH2   = sqrt(mse_MFH2)
  )
if (fit_mfh3) {
  db_wide_all <- db_wide_all %>% mutate(rmse_MFH3 = sqrt(mse_MFH3))
}

db_wide_all




if (.model_fit_failed) {
  cat(
    "\n--- IMPORTANT ---\n",
    "## MFH model fit failed -- no random effects were estimated\n\n",
    "The selected diagnostic MFH variant (**", diag_model, "**) returned an empty ",
    "model object. `eblupMFH*()` errored out before producing any fit, so:\n\n",
    "- Random effects, EBLUPs, MSEs, and CVs are **not available** for this run.\n",
    "- The robust REML fallback could not run either (it needs a valid input matrix).\n",
    "- Downstream tables and figures based on this MFH variant will show empty / NA values.\n\n",
    "Inspect the rendered errors above for the specific failure. Common causes ",
    "include: the chosen vardir produces a per-domain R that is not positive-definite, ",
    "or the design matrix has rank deficiency. Rerun with a different ",
    "`var_choice` / `cov_choice` combination (the smoothed `rho_*` options ",
    "are the most robust) or revisit the covariate specification.\n",
    "\n",
    sep = ""
  )
}


# Report independently checked refits without treating a failed optimizer as evidence.
.robust_used_models <- names(.robust_used)[.robust_used]
if (length(.robust_used_models)) {
  cat("\n## MFH2 REML refit\n\n",
      "The package fit required a constrained REML refit. Accepted endpoints pass the independent score, curvature and boundary checks. All selected-model predictions and bootstrap refits use the same fitting rule. Models: ",
      paste(.robust_used_models, collapse = ", "), ".\n\n", sep = "")
}
.robust_failed_models <- names(.robust_failed)[.robust_failed]
if (length(.robust_failed_models)) {
  cat("\nThe constrained REML refit failed for: ", paste(.robust_failed_models, collapse = ", "),
      ". Failed fits do not support inference; optimizer failure is not evidence of a zero variance.\n", sep = "")
}

if (.refvar_zero) {
  cat("The selected model has zero random-effect covariance. Synthetic point estimates and benchmarking remain available. Bootstrap uncertainty is computed, but change significance is provisional.\n")
}



# ============================================================
# Regional Benchmarking for the Selected MFH Model
#
# This chunk applies ratio-type regional benchmarking to the
# selected MFH model's EBLUP estimates. When MSE bootstrap is
# enabled, it also computes benchmarked MSE and MCPE that
# respect the temporal covariance structure.
# ============================================================

.read_optional_benchmark_table <- function(path) {
  if (is.null(path) || length(path) == 0 || !nzchar(path)) return(NULL)
  if (!file.exists(path)) stop("Optional benchmarking input not found: ", path)
  ext <- tolower(tools::file_ext(path))
  if (ext == "rds") {
    obj <- readRDS(path)
  } else if (ext %in% c("rda", "rdata")) {
    load_env <- new.env(parent = emptyenv())
    loaded <- load(path, envir = load_env)
    if (length(loaded) != 1) {
      stop("Optional benchmarking .RData/.rda file must contain exactly one object.")
    }
    obj <- load_env[[loaded[1]]]
  } else if (ext %in% c("csv", "txt")) {
    obj <- read.csv(path, check.names = FALSE)
  } else if (ext %in% c("xlsx", "xls")) {
    if (!requireNamespace("readxl", quietly = TRUE)) {
      stop("Package 'readxl' is required to read optional Excel benchmarking inputs.")
    }
    obj <- readxl::read_excel(path)
  } else {
    stop("Unsupported optional benchmarking input format: ", path)
  }
  obj
}

.pick_col <- function(nms, candidates) {
  lower_nms <- tolower(nms)
  hit <- match(tolower(candidates), lower_nms)
  hit <- hit[!is.na(hit)]
  if (length(hit) == 0) NULL else nms[hit[1]]
}

.matrix_from_optional_population <- function(path, domain_vec, years_keep) {
  sae_population_matrix_from_file(path, domain_vec, years_keep)
}

.matrix_from_optional_regional_benchmark <- function(path, region_vec, years_keep, level_col = "") {
  sae_benchmark_targets_from_file(path, region_vec, years_keep, level_col)
}

bench_result <- NULL

# Skip benchmarking when MFH model was not properly executed
if (.model_fit_failed) {
  cat("Grouped benchmarking skipped -- eblupMFH2 did not produce valid random effects.\n")
  do_benchmark <- FALSE
}

if (do_benchmark && !is.null(region_map)) {

  # Prepare inputs for benchmarking
  bench_domains <- domain_dt$domain

  # Region and population size vectors aligned to domain_dt
  bench_region <- region_map$region[match(bench_domains, region_map$domain)]
  bench_Nd_mat <- sae_resolve_population_matrix(
    population_path = population_path,
    survey_data = survey_dt,
    domain_vec = bench_domains,
    years_keep = years_keep,
    hh_size_col = "hh_size",
    context = "MFH benchmarking"
  )
  bench_Nd <- bench_Nd_mat[, 1]

  regional_benchmark_mat <- .matrix_from_optional_regional_benchmark(
    benchmark_target_path,
    region_vec = bench_region,
    years_keep = years_keep,
    level_col = var_map$benchmark_level
  )
  # External mean-welfare targets are in the same prices as the survey's welfare
  # (current prices unless the welfare is already real), so they get the same factors.
  regional_benchmark_mat <- sae_deflate_year_matrix(regional_benchmark_mat, price_factors)
  if (!is.null(regional_benchmark_mat)) {
    cat("Using Benchmark Target Database for MFH benchmarking:", benchmark_target_path, "\n")
  }

  # Direct estimates matrix (D x nT)
  direct_bench_mat <- as.matrix(domain_dt[, poor_cols, drop = FALSE])
  rownames(direct_bench_mat) <- as.character(bench_domains)
  colnames(direct_bench_mat) <- as.character(years_keep)

  # EBLUP matrix from selected model
  eblup_sel <- as.matrix(selected_model$eblup)
  if (nrow(eblup_sel) != length(bench_domains) ||
      ncol(eblup_sel) != length(years_keep)) {
    stop(
      "Selected MFH EBLUP matrix dimensions do not match the domain/year ",
      "benchmarking frame. This would make regional benchmarking unsafe."
    )
  }
  rownames(eblup_sel) <- as.character(bench_domains)
  colnames(eblup_sel) <- as.character(years_keep)

  formula_outcomes <- vapply(mfh_formula, function(f) all.vars(f)[1], character(1))
  if (!identical(unname(as.character(formula_outcomes)), unname(as.character(poor_cols)))) {
    stop(
      "MFH formula outcome order does not match direct benchmark column order: ",
      paste(formula_outcomes, collapse = ", "), " vs ",
      paste(poor_cols, collapse = ", ")
    )
  }

  # Check that all required vectors are complete
  has_region <- !any(is.na(bench_region))
  has_Nd     <- !any(is.na(bench_Nd_mat))

  if (!has_region || !has_Nd) {
    message("Warning: Missing region or population data for some domains. ",
            "Benchmarking skipped.")
    do_benchmark <- FALSE
  } else {

    cat("\n--- Grouped Benchmarking ---\n")
    cat("Model:", diag_model, "\n")
    cat("Domains:", length(bench_domains), "\n")
    cat("Benchmark groups:", length(unique(bench_region)), "\n")
    cat("Bootstrap iterations for MSE:", bench_nB, "\n\n")

    # Print regional benchmark targets
    for (tt in seq_along(poor_cols)) {
      if (!is.null(regional_benchmark_mat)) {
        reg_bench <- data.frame(
          region = rownames(regional_benchmark_mat),
          n_domains = as.integer(table(factor(as.character(bench_region),
                                              levels = rownames(regional_benchmark_mat)))),
          B_r = regional_benchmark_mat[, tt],
          source = "external"
        )
      } else {
        reg_bench <- data.frame(
          domain = bench_domains,
          region = bench_region,
          Nd = bench_Nd_mat[, tt],
          direct = if (isTRUE(log_transform)) exp(direct_bench_mat[, tt]) else direct_bench_mat[, tt],
          eblup = eblup_sel[, tt]
        ) %>%
          filter(is.finite(direct), is.finite(eblup), is.finite(Nd)) %>%
          group_by(region) %>%
          summarize(
            n_domains = n(),
            B_r = weighted.mean(direct, Nd, na.rm = TRUE),
            source = "domain-direct fallback",
            .groups = "drop"
          )
      }
      cat("Benchmark targets for", poor_cols[tt], ":\n")
      print(as.data.frame(reg_bench))
      cat("\n")
    }

    tictoc::tic("MFH grouped benchmarking")

    bench_result <- bench_regional_mfh(
      eblup_mat  = eblup_sel,
      domain_vec = bench_domains,
      region_vec = bench_region,
      Nd_vec     = bench_Nd,
      Nd_mat     = bench_Nd_mat,
      direct_mat = direct_bench_mat,
      regional_benchmark_mat = regional_benchmark_mat,
      model_obj  = selected_model,
      model_type = diag_model,   # dispatch DGP + refit by MFH1/MFH2/MFH3
      formula    = mfh_formula,
      vardir     = vardir_cols,
      data       = domain_dt,
      MSE        = TRUE,
      nB         = bench_nB,
      seed       = analysis_seed + 2000L,
      back_transform = if (isTRUE(log_transform)) "log" else "none",
      bias_correction = mfh_bias_correction
    )

    tictoc::toc()

    cat("\nBenchmarking complete.\n")
    cat("Failed bootstrap iterations:", bench_result$fails, "/", bench_nB, "\n")
    saveRDS(bench_result, here::here("outputs", "data", "mfh_benchmark_bootstrap.rds"))
    write.csv(data.frame(
      domain = rep(bench_domains, length(years_keep)),
      year = rep(years_keep, each = length(bench_domains)),
      mse_mcse = if (is.null(bench_result$mse_mcse)) rep(NA_real_, length(eblup_sel)) else as.vector(bench_result$mse_mcse),
      requested_replicates = bench_nB,
      successful_replicates = bench_result$n_success,
      rejected_refits = bench_result$fails,
      inference_status = bench_result$inference_status %||% "unavailable",
      covariance_boundary_count = bench_result$covariance_boundary_count %||% NA_integer_,
      covariance_boundary_fraction = bench_result$covariance_boundary_fraction %||% NA_real_,
      variance_zero_count = bench_result$variance_zero_count %||% NA_integer_,
      correlation_limit_count = bench_result$correlation_limit_count %||% NA_integer_),
      here::here("outputs", "tables", "mfh_benchmark_precision.csv"), row.names = FALSE)

    # ---- Add benchmarked estimates to the comparison table ----
    bench_long <- tibble(
      domain = rep(bench_domains, ncol(eblup_sel)),
      year   = rep(years_keep, each = length(bench_domains)),
      rate_Bench  = as.vector(bench_result$eblup_bench),
      mse_Bench   = if (is.null(bench_result$mse_bench)) rep(NA_real_, length(eblup_sel)) else as.vector(bench_result$mse_bench)
    ) %>%
      mutate(
        cv_Bench   = .safe_cv(mse_Bench, rate_Bench),
        rmse_Bench = sqrt(mse_Bench)
      )

    db_wide_all <- db_wide_all %>%
      left_join(bench_long, by = c("domain", "year"))
  }
}

if (!do_benchmark || is.null(bench_result)) {
  cat("Grouped benchmarking was not applied.\n")
}



# Estimator and benchmark are already on the original scale.
if (isTRUE(log_transform)) {
  attr(db_wide_all, "log_back_transformed") <- TRUE
  attr(db_wide_all, "bias_correction_method") <-
    if (mfh_bias_correction) "conditional_lognormal" else "none"
}

# Skip MCPE bootstrap when MFH model did not produce valid random effects
if (.model_fit_failed) {
  cat("MCPE bootstrap skipped -- eblupMFH2 was not properly executed.\n")
  mcpe_obj     <- NULL
  mcpemfh2_obj <- NULL
} else {
  # MCPE is available for MFH1, MFH2 and MFH3. The dispatcher picks the
  # right parametric-bootstrap routine based on `diag_model` (and lazily
  # sources the matching `pbmcpeMFH*_with_existing_eblup.R` wrapper) so
  # downstream code is agnostic to which variant was chosen.
  source(here::here("scripts", "pbmcpe_with_existing_dispatch.R"))

  set.seed(analysis_seed + 1000L)
  tictoc::tic(paste0("pbmcpe (", diag_model, ")"))

  mcpe_obj <- tryCatch(
    pbmcpe_with_existing(
      diag_model     = diag_model,
      formula        = mfh_formula,
      vardir         = vardir_cols,
      domain_var     = "domain",
      existing_model = selected_model,
      nB             = mcpe_nB,
      data           = domain_dt,
      seed           = analysis_seed + 1000L,
      back_transform = if (isTRUE(log_transform)) "log" else "none",
      bias_correction = mfh_bias_correction,
      MAXITER        = 100,
      PRECISION      = 1e-04
    ),
    error = function(e) {
      cat(
        "\n**Note:** MCPE bootstrap is not available for this MFH run. ",
        conditionMessage(e),
        "\nChange-analysis outputs will be written with NA placeholders.\n\n",
        sep = ""
      )
      NULL
    }
  )

  if (!is.null(mcpe_obj)) {
    # Save with a model-specific filename so multiple runs can coexist on disk.
    saveRDS(mcpe_obj,
            here::here("outputs", "data", paste0("mcpe_", tolower(diag_model), "_obj.rds")))

    .finite_summary <- function(x, fun, default = NA_real_) {
      x <- suppressWarnings(as.numeric(x))
      x <- x[is.finite(x)]
      if (!length(x)) default else fun(x)
    }
    .relative_mcse <- function(estimate, mcse) {
      estimate <- suppressWarnings(as.numeric(estimate))
      mcse <- suppressWarnings(as.numeric(mcse))
      keep <- is.finite(estimate) & is.finite(mcse) & abs(estimate) > 1e-12
      if (!any(keep)) numeric() else mcse[keep] / abs(estimate[keep])
    }
    .mse_rel_mcse <- .relative_mcse(mcpe_obj$mse, mcpe_obj$mse_mcse)
    .mcpe_rel_mcse <- .relative_mcse(mcpe_obj$mcpe, mcpe_obj$mcpe_mcse)
    write.csv(
      data.frame(
        model = diag_model,
        target_replicates = as.integer(mcpe_obj$target_replicates %||% mcpe_nB),
        successful_replicates = as.integer(mcpe_obj$n_success %||% mcpe_nB),
        failed_refits = as.integer(mcpe_obj$fails %||% 0L),
        attempts = as.integer(mcpe_obj$attempts %||%
                                ((mcpe_obj$n_success %||% mcpe_nB) +
                                   (mcpe_obj$fails %||% 0L))),
        near_pd_adjustments = as.integer(mcpe_obj$near_pd_adjustments %||% 0L),
        seed = as.integer(mcpe_obj$seed %||% (analysis_seed + 1000L)),
        max_mse_mcse = .finite_summary(mcpe_obj$mse_mcse, max),
        median_relative_mse_mcse = .finite_summary(.mse_rel_mcse, stats::median),
        max_mcpe_mcse = .finite_summary(mcpe_obj$mcpe_mcse, max),
        median_relative_mcpe_mcse = .finite_summary(.mcpe_rel_mcse, stats::median),
        inference_status = .inference_status,
        covariance_boundary_reason = .covariance_boundary_reason,
        covariance_boundary_count = mcpe_obj$covariance_boundary_count,
        covariance_boundary_fraction = mcpe_obj$covariance_boundary_fraction,
        variance_zero_count = mcpe_obj$variance_zero_count,
        correlation_limit_count = mcpe_obj$correlation_limit_count,
        assurance_status = "run_diagnostics_only_external_method_validation_still_required",
        stringsAsFactors = FALSE
      ),
      here::here("outputs", "tables", "mfh_mcpe_validation.csv"),
      row.names = FALSE
    )
  }

  # Back-compat alias: older code paths referenced `mcpemfh2_obj`
  mcpemfh2_obj <- mcpe_obj

  tictoc::toc()
}

# Selected annual MSEs use the same joint bootstrap as changes, including boundary fits.
# If bootstrap inference is unavailable, do not substitute interior analytic MSEs.
db_wide_all[[mse_col_diag]] <- NA_real_
if (!is.null(mcpe_obj)) {
  for (.tt in seq_along(years_keep)) {
    .rows <- which(db_wide_all$year == years_keep[.tt])
    .idx <- match(as.character(db_wide_all$domain[.rows]), as.character(mcpe_obj$domain))
    db_wide_all[[mse_col_diag]][.rows] <- mcpe_obj$mse[.idx, .tt]
  }
}
db_wide_all[[paste0("cv_", diag_model)]] <-
  .safe_cv(db_wide_all[[mse_col_diag]], db_wide_all[[rate_col]])
db_wide_all[[paste0("rmse_", diag_model)]] <- sqrt(db_wide_all[[mse_col_diag]])

if (isTRUE(fit_mfh3_requested) && exists("fit_mfh3") && !fit_mfh3) {
  if (identical(.mfh3_failure_type, "non_convergence")) {
    cat(
      "--- WARNING ---\n",
      "## MFH3 Did Not Converge\n\n",
      "The MFH3 (heteroskedastic) model was requested but did not meet its convergence criterion",
      if (is.finite(.mfh3_iterations)) paste0(" after ", .mfh3_iterations, " iterations") else "",
      ". All post-estimation diagnostics, maps, and inference results below are therefore based on the **",
      diag_model, "** model (fallback).\n\n",
      sep = ""
    )
  } else {
    cat(
      "--- WARNING ---\n",
      "## MFH3 Could Not Be Estimated\n\n",
      "The MFH3 (heteroskedastic) model encountered a computational error and is unavailable. ",
      "All post-estimation diagnostics, maps, and inference results below are therefore based on the **",
      diag_model, "** model (fallback). The detailed run log records the technical error.\n\n",
      sep = ""
    )
  }
}

if (diag_model_requested %in% c("AUTO", "MFH3")) {
  cat(
    "## MFH Variance-Structure Selection\n\n",
    .mfh_variance_selection$reason,
    " Raw, Bonferroni-adjusted, and BH-adjusted contrasts are saved in ",
    "`outputs/tables/mfh_variance_structure_selection.csv`.\n\n",
    sep = ""
  )
}


# ============================================================
# Objective: Residual diagnostics for the selected model
#            Compare domain-level residuals (Direct - EBLUP)
#            against EBLUPs for each year to detect outliers,
#            heteroskedasticity, and systematic patterns.
# ============================================================

stopifnot(length(poor_cols) == 2)

# Ensure the same domain ordering used when mapping model outputs
domain_vec <- domain_dt$domain

# Extract EBLUP columns for the two outcomes (years_keep order), aligned by
# domain key so model-internal row drops cannot shift labels silently.
eb <- as.data.frame(selected_model$eblup)
eb_domains <- .mfh_output_domains(eb, diag_model, domain_vec, "EBLUP")
direct_for_eb <- .mfh_align_direct_rows(eb, diag_model, domain_vec, "EBLUP")
missing_in_eb <- setdiff(poor_cols, names(eb))
if (length(missing_in_eb) > 0) {
  stop("EBLUP output is missing expected columns: ", paste(missing_in_eb, collapse = ", "))
}

# Covariance-aware standardization: Var(Direct - EBLUP) = R P R,
# including fitted fixed effects. Components remain correlated: descriptive QA.
.residual_check <- sae_mfh_standardized_residuals(
  selected_model, diag_model, mfh_formula, vardir_cols, domain_dt)
resids_2 <- .residual_check$standardized
write.csv(data.frame(domain = rep(domain_vec, length(years_keep)),
                     year = rep(years_keep, each = length(domain_vec)),
                     residual = as.vector(.residual_check$raw),
                     residual_variance = as.vector(.residual_check$variance),
                     standardized_residual = as.vector(resids_2)),
          here::here("outputs", "tables", "mfh_standardized_residuals.csv"), row.names = FALSE)
cat("Residual diagnostics use covariance-standardized residuals. Shapiro-Wilk and residual-fitted regressions are descriptive because residuals remain correlated.\n")

# Two-panel diagnostic plots -- save to file
# Keep poor_* as internal model keys; display the indicator and working scale.
.diag_fitted_label <- if (isTRUE(log_transform)) {
  "Fitted log mean welfare"
} else if (identical(indicator_type, "mean_welfare")) {
  sub("^Mean", "Fitted mean", pov_lab$axis_label)
} else {
  # UFH's fgt_label() supplies short but not noun_singular. It may already
  # be loaded when the Workbench starts MFH, so support both label schemas.
  paste0("Fitted ", pov_lab$noun_singular %||% tolower(pov_lab$short), " (proportion)")
}
.diag_year_labels <- setNames(as.character(years_keep), poor_cols)
png(here::here("outputs", "figures", "mfh_residual_vs_eblup.png"),
    width = 12, height = 6, units = "in", res = 150)
par(mfrow = c(1, 2))
plot(
  eb[[poor_cols[1]]], resids_2[, 1],
  pch = 19,
  xlab = .diag_fitted_label,
  ylab = "Standardized residuals",
  main = as.character(years_keep[1])
)
plot(
  eb[[poor_cols[2]]], resids_2[, 2],
  pch = 19,
  xlab = .diag_fitted_label,
  ylab = "Standardized residuals",
  main = as.character(years_keep[2])
)
par(mfrow = c(1, 1))
dev.off()


# ============================================================
# Objective: Test for residual--fitted relationships
#            Regress residuals on fitted EBLUPs for each year as
#            a simple check for systematic patterns / misspecification.
# ============================================================

stopifnot(length(poor_cols) == 2)

eb_diag <- as.data.frame(selected_model$eblup)

# Regression of residuals on fitted values for each year (y1 and y2)
lm_resid_fit_y1 <- lm(resids_2[, 1] ~ eb_diag[[poor_cols[1]]])
lm_resid_fit_y2 <- lm(resids_2[, 2] ~ eb_diag[[poor_cols[2]]])

summary(lm_resid_fit_y1)
summary(lm_resid_fit_y2)




# ============================================================
# Objective: Residual normality diagnostics for the selected model
#            Compute residuals (Direct - EBLUP) for each year,
#            run Shapiro--Wilk tests, and visualize distributions
#            using histograms and QQ plots.
# ============================================================

stopifnot(length(poor_cols) == 2)

resid_dt <- as.data.frame(resids_2)
colnames(resid_dt) <- poor_cols

# ---- Safe Shapiro--Wilk wrapper (guards against constant columns) ----
safe_shapiro <- function(x) {
  x <- as.numeric(x)
  x <- x[!is.na(x)]
  if (length(x) < 3) {
    list(statistic = c(W = NA_real_), p.value = NA_real_, note = "Too few values")
  } else if (length(unique(x)) <= 1) {
    list(statistic = c(W = NA_real_), p.value = NA_real_, note = "Constant values")
  } else {
    tryCatch(
      shapiro.test(x),
      error = function(e) list(statistic = c(W = NA_real_), p.value = NA_real_, note = "Test failed")
    )
  }
}

# ---- Shapiro tests by year ----
shapiro_obj <- lapply(resid_dt, safe_shapiro)

resid_shapiro_dt <- data.frame(
  Time    = names(shapiro_obj),
  W       = as.numeric(sapply(shapiro_obj, function(x) x$statistic[[1]])),
  p_value = as.numeric(sapply(shapiro_obj, function(x) x$p.value))
) %>%
  mutate(label = ifelse(is.na(W),
                        "Shapiro-Wilk skipped",
                        paste0("Descriptive W = ", round(W, 3), "\n", "p = ", signif(p_value, 3))))

# ---- Histograms ----
.p_resid_hist <- resid_dt %>%
  as_tibble() %>%
  pivot_longer(cols = everything(), names_to = "Time", values_to = "Residual") %>%
  ggplot(aes(x = Residual)) +
  geom_histogram(bins = 10, color = "white") +
  geom_text(
    data = resid_shapiro_dt,
    aes(x = -Inf, y = Inf, label = label),
    hjust = -0.1, vjust = 1.2, inherit.aes = FALSE, size = 3.5
  ) +
  facet_wrap(~Time, scales = "free", labeller = labeller(Time = .diag_year_labels)) +
  theme_minimal() +
  labs(title = paste0("Standardized residual histograms by year (", diag_model, ")"),
       x = "Standardized residual", y = "Count")
ggsave(here::here("outputs", "figures", "mfh_residual_histogram.png"),
       .p_resid_hist, width = 10, height = 6, dpi = 150)

# ---- QQ plots ----
.p_resid_qq <- resid_dt %>%
  as_tibble() %>%
  pivot_longer(cols = everything(), names_to = "Time", values_to = "Residual") %>%
  ggplot(aes(sample = Residual)) +
  stat_qq() +
  stat_qq_line() +
  facet_wrap(~Time, scales = "free", labeller = labeller(Time = .diag_year_labels)) +
  theme_minimal() +
  labs(title = paste0("QQ plots of standardized residuals by year (", diag_model, ")"),
       x = "Theoretical normal quantile", y = "Standardized residual")
ggsave(here::here("outputs", "figures", "mfh_qq_residual.png"),
       .p_resid_qq, width = 10, height = 6, dpi = 150)



# Extract estimated random effects from the selected model
raneff_dt <- as.data.frame(selected_model$randomEffect)

# If a single vector slipped through, coerce to 1-column data frame
if (is.null(ncol(raneff_dt))) {
  raneff_dt <- data.frame(re = as.numeric(raneff_dt))
}

# Check whether all random effects are zero (boundary refvar = 0)
.re_all_zero <- all(unlist(raneff_dt) == 0, na.rm = TRUE)


if (.re_all_zero) {
  cat(
    "\n--- WARNING ---\n",
    "## Random-effects diagnostics skipped\n\n",
    "All estimated random effects are identically zero because the random-effects ",
    "variance ($\\sigma^2_u$) was estimated at the boundary (zero). ",
    "Normality tests and histogram diagnostics are not applicable.\n",
    "\n",
    sep = ""
  )
}



# Shapiro--Wilk tests by column (e.g., by year/outcome)
# Uses safe_shapiro() defined in the residuals chunk above
shapiro_obj <- lapply(raneff_dt, safe_shapiro)

re_shapiro_dt <- data.frame(
  Time    = names(shapiro_obj),
  W       = as.numeric(sapply(shapiro_obj, function(x) x$statistic[[1]])),
  p_value = as.numeric(sapply(shapiro_obj, function(x) x$p.value))
) %>%
  mutate(label = ifelse(is.na(W),
                        "Shapiro-Wilk skipped",
                        paste0("Descriptive W = ", round(W, 3), "\n", "p = ", signif(p_value, 3))))

# Plot histograms with test annotations
.diag_re_year_labels <- setNames(as.character(years_keep), names(raneff_dt))
.p_re_hist <- raneff_dt %>%
  as_tibble() %>%
  pivot_longer(cols = everything(), names_to = "Time", values_to = "RandEff") %>%
  ggplot(aes(x = RandEff)) +
  geom_histogram(bins = 10, color = "white") +
  geom_text(
    data = re_shapiro_dt,
    aes(x = -Inf, y = Inf, label = label),
    hjust = -0.1, vjust = 1.2, inherit.aes = FALSE, size = 3.5
  ) +
  facet_wrap(~Time, scales = "free", labeller = labeller(Time = .diag_re_year_labels)) +
  theme_minimal() +
  labs(title = paste0("Random-effects histograms by year (", diag_model, ")"),
       x = if (isTRUE(log_transform)) "Random effect (log scale)" else "Random effect",
       y = "Count")
ggsave(here::here("outputs", "figures", "mfh_qq_random_effect.png"),
       .p_re_hist, width = 10, height = 6, dpi = 150)


# ---- Export Shapiro--Wilk results to CSV for the app ----
mfh_shapiro_results <- data.frame(
  year       = rep(years_keep, 2),
  component  = c(rep("residual", length(years_keep)), rep("random_effect", length(years_keep))),
  W          = c(resid_shapiro_dt$W, re_shapiro_dt$W),
  p_value    = c(resid_shapiro_dt$p_value, re_shapiro_dt$p_value),
  model_type = diag_model
)
write.csv(mfh_shapiro_results, file = here::here("outputs", "tables", "mfh_shapiro_results.csv"), row.names = FALSE)


# ============================================================
# Objective: Compare direct vs model-based estimates across domains
#            for a selected year (year_plot), using MSE and levels.
# ============================================================

year_plot <- y1   # switch to y2 if desired

# ---- Build color palette and column lists dynamically ----
method_colors <- c(
  "direct_mse"  = "black",
  "direct_rate" = "black",
  "mse_MFH1"    = "#ff7f0e",
  "rate_MFH1"   = "#ff7f0e",
  "mse_MFH2"    = "#d62728",
  "rate_MFH2"   = "#d62728"
)
method_colors[c(.ufh_col("mse"), .ufh_col("rate"))] <- "#1f77b4"
if (fit_mfh3) {
  method_colors <- c(method_colors, "mse_MFH3" = "#2ca02c", "rate_MFH3" = "#2ca02c")
}

# Column vectors: use any_of() so missing columns are silently skipped
mse_model_cols  <- c(.ufh_col("mse"), "mse_MFH1", "mse_MFH2", if (fit_mfh3) "mse_MFH3")
rate_model_cols <- c(.ufh_col("rate"), "rate_MFH1", "rate_MFH2", if (fit_mfh3) "rate_MFH3")

## ---------- 1) MSE incl direct ----------
plot_mse_all <- db_wide_all %>%
  filter(year == year_plot) %>%
  arrange(direct_mse) %>%
  mutate(domain_order = row_number()) %>%
  select(domain, domain_order, direct_mse, any_of(mse_model_cols)) %>%
  pivot_longer(
    cols = c(direct_mse, any_of(mse_model_cols)),
    names_to = "Method",
    values_to = "MSE"
  )

p1 <- ggplot(plot_mse_all, aes(x = domain_order, y = MSE, color = Method)) +
  geom_point(size = 2) +
  scale_color_manual(values = method_colors) +
  labs(
    title = paste0("MSE comparison (incl direct) - ", year_plot),
    x = "Domain (ordered by increasing direct MSE)",
    y = "MSE"
  ) +
  theme_minimal()

## ---------- 2) MSE models only ----------
plot_mse_models <- db_wide_all %>%
  filter(year == year_plot) %>%
  arrange(.data[[.ufh_col("mse")]]) %>%
  mutate(domain_order = row_number()) %>%
  select(domain, domain_order, any_of(mse_model_cols)) %>%
  pivot_longer(
    cols = any_of(mse_model_cols),
    names_to = "Method",
    values_to = "MSE"
  )

p2 <- ggplot(plot_mse_models, aes(x = domain_order, y = MSE, color = Method)) +
  geom_point(size = 2) +
  scale_color_manual(values = method_colors) +
  labs(
    title = paste0("MSE comparison (models only) - ", year_plot),
    x = paste0("Domain (ordered by increasing ", ufh_msae_label, " MSE)"),
    y = "MSE"
  ) +
  theme_minimal()

## ---------- 3) Poverty rate incl direct ----------
plot_rate_all <- db_wide_all %>%
  filter(year == year_plot) %>%
  arrange(direct_rate) %>%
  mutate(domain_order = row_number()) %>%
  select(domain, domain_order, direct_rate, any_of(rate_model_cols)) %>%
  pivot_longer(
    cols = c(direct_rate, any_of(rate_model_cols)),
    names_to = "Method",
    values_to = "Rate"
  )

p3 <- ggplot(plot_rate_all, aes(x = domain_order, y = Rate, color = Method)) +
  geom_point(size = 2) +
  scale_color_manual(values = method_colors) +
  labs(
    title = paste0(pov_lab$short, " comparison (incl direct) - ", year_plot),
    x = "Domain (ordered by increasing direct value)",
    y = pov_lab$short
  ) +
  theme_minimal()

## ---------- 4) Estimate models only ----------
plot_rate_models <- db_wide_all %>%
  filter(year == year_plot) %>%
  arrange(.data[[.ufh_col("rate")]]) %>%
  mutate(domain_order = row_number()) %>%
  select(domain, domain_order, any_of(rate_model_cols)) %>%
  pivot_longer(
    cols = any_of(rate_model_cols),
    names_to = "Method",
    values_to = "Rate"
  )

p4 <- ggplot(plot_rate_models, aes(x = domain_order, y = Rate, color = Method)) +
  geom_point(size = 2) +
  scale_color_manual(values = method_colors) +
  labs(
    title = paste0(pov_lab$short, " comparison (models only) - ", year_plot),
    x = paste0("Domain (ordered by increasing ", ufh_msae_label, " value)"),
    y = pov_lab$short
  ) +
  theme_minimal()

ggsave(here::here("outputs", "figures", paste0("mfh_mse_all_", year_plot, ".png")), p1, width = 12, height = 6, dpi = 150)
ggsave(here::here("outputs", "figures", paste0("mfh_mse_models_", year_plot, ".png")), p2, width = 12, height = 6, dpi = 150)
ggsave(here::here("outputs", "figures", paste0("mfh_compare_y", match(year_plot, years_keep), ".png")), p3, width = 12, height = 6, dpi = 150)
ggsave(here::here("outputs", "figures", paste0("mfh_rate_models_", year_plot, ".png")), p4, width = 12, height = 6, dpi = 150)

# ---- RMSE color mapping (same hues as MSE columns) ----
rmse_colors <- c(
  "direct_rmse" = "black",
  "rmse_MFH1"   = "#ff7f0e",
  "rmse_MFH2"   = "#d62728"
)
rmse_colors[.ufh_col("rmse")] <- "#1f77b4"
if (fit_mfh3) rmse_colors <- c(rmse_colors, "rmse_MFH3" = "#2ca02c")

rmse_model_cols <- sub("^mse_", "rmse_", mse_model_cols)

## ---------- 5) RMSE incl direct ----------
plot_rmse_all <- db_wide_all %>%
  filter(year == year_plot) %>%
  arrange(direct_rmse) %>%
  mutate(domain_order = row_number()) %>%
  select(domain, domain_order, direct_rmse, any_of(rmse_model_cols)) %>%
  pivot_longer(
    cols      = c(direct_rmse, any_of(rmse_model_cols)),
    names_to  = "Method",
    values_to = "RMSE"
  )

p5 <- ggplot(plot_rmse_all, aes(x = domain_order, y = RMSE, color = Method)) +
  geom_point(size = 2) +
  scale_color_manual(values = rmse_colors) +
  labs(
    title = paste0("RMSE comparison (incl direct) \u2013 ", year_plot),
    x     = "Domain (ordered by increasing direct RMSE)",
    y     = "RMSE"
  ) +
  theme_minimal()

## ---------- 6) RMSE models only ----------
plot_rmse_models <- db_wide_all %>%
  filter(year == year_plot) %>%
  arrange(.data[[.ufh_col("rmse")]]) %>%
  mutate(domain_order = row_number()) %>%
  select(domain, domain_order, any_of(rmse_model_cols)) %>%
  pivot_longer(
    cols      = any_of(rmse_model_cols),
    names_to  = "Method",
    values_to = "RMSE"
  )

p6 <- ggplot(plot_rmse_models, aes(x = domain_order, y = RMSE, color = Method)) +
  geom_point(size = 2) +
  scale_color_manual(values = rmse_colors) +
  labs(
    title = paste0("RMSE comparison (models only) \u2013 ", year_plot),
    x     = paste0("Domain (ordered by increasing ", ufh_msae_label, " RMSE)"),
    y     = "RMSE"
  ) +
  theme_minimal()

ggsave(here::here("outputs", "figures", paste0("mfh_rmse_all_", year_plot, ".png")), p5, width = 12, height = 6, dpi = 150)
ggsave(here::here("outputs", "figures", paste0("mfh_rmse_models_", year_plot, ".png")), p6, width = 12, height = 6, dpi = 150)





# ============================================================
# Objective: Diagnose MFH smoothing by relating the magnitude of
#            model differences to sample size.
#            We plot |selected_model âˆ’ UFH| against N (log scale).
#            Larger differences at small N are consistent with
#            smoothing where direct information is weak.
# ============================================================

stopifnot(length(years_keep) == 2, length(N_cols) == 2)

# 1) Sample sizes to long: (domain, year, N)
n_long <- all_var_hat_domain_dt %>%
  select(domain, all_of(N_cols)) %>%
  pivot_longer(
    cols      = all_of(N_cols),
    names_to  = "year_raw",
    values_to = "N"
  ) %>%
  mutate(year = as.integer(gsub("^N_", "", year_raw))) %>%
  select(domain, year, N)

# 2) Build plotting dataset: UFH vs selected model rates + sample size
plot_dt <- db_wide_all %>%
  select(domain, year, all_of(c(.ufh_col("rate"), rate_col))) %>%
  left_join(n_long, by = c("domain", "year")) %>%
  filter(year %in% years_keep)

# 3) Smoothing diagnostic: absolute difference vs sample size
plot_dt <- plot_dt %>%
  mutate(abs_diff = abs(.data[[rate_col]] - .data[[.ufh_col("rate")]])) %>%
  filter(is.finite(abs_diff), is.finite(N), !is.na(N), N > 0)

ggplot(plot_dt, aes(x = N, y = abs_diff)) +
  geom_point(alpha = 0.7) +
  geom_smooth(method = "loess", se = TRUE) +
  scale_x_log10() +
  labs(
    title = paste0(diag_model, " smoothing diagnostic: |", diag_model, " - ", ufh_msae_label, "| vs sample size"),
    subtitle = "Larger differences at small N indicate stronger smoothing where direct information is weak",
    x = "Sample size (N, log scale)",
    y = paste0("|", diag_model, " - ", ufh_msae_label, "|")
  ) +
  theme_minimal()

ggsave(here::here("outputs", "figures", "mfh_smoothing_diagnostic.png"),
       width = 10, height = 6, dpi = 150)





# Objective:
# This chunk defines a helper function that compares MCPE-based EBLUP
# poverty estimates across two time periods for any MFH variant
# (MFH1/MFH2/MFH3). It computes pairwise differences, constructs
# confidence intervals using the MCPE covariance, and identifies
# domains with statistically significant changes. The function also
# produces a diagnostic plot to visually assess the magnitude and
# significance of intertemporal changes across areas.

#' A function to compare and plot differences from the mcpe object
#'
#' Works for any MFH variant because it only uses the eblup/mse/mcpe
#' slots of the supplied mcpe object, all of which are produced in the
#' same shape by `pbmcpe_with_existing()`.
compare_mfh <- function(period_list = c(1, 2),
                        mcpe_obj = if (exists("mcpe_obj")) mcpe_obj else mcpemfh2_obj,
                        alpha = 0.05,
                        year_labels = NULL,
                        inference_status = "regular", inference_warning = "") {
  stopifnot(length(period_list) == 2)
  
  # Force 2D objects even when there is only 1 column
  eblup_mat <- as.matrix(mcpe_obj$eblup)
  mse_mat   <- as.matrix(mcpe_obj$mse)
  mcpe_mat  <- as.matrix(mcpe_obj$mcpe)
  
  # Column name for covariance (t1,t2)
  col_chr <- paste0("(", period_list[1], ",", period_list[2], ")")
  
  # If mcpe_mat has no colnames (common when nT=2 and earlier code dropped),
  # assume it's the single (1,2) covariance and set the name.
  if (is.null(colnames(mcpe_mat)) && ncol(mcpe_mat) == 1) {
    colnames(mcpe_mat) <- paste0("(", min(period_list), ",", max(period_list), ")")
  }
  
  # If user asks (2,1) but the stored name is (1,2), map it
  if (!(col_chr %in% colnames(mcpe_mat))) {
    alt <- paste0("(", period_list[2], ",", period_list[1], ")")
    if (alt %in% colnames(mcpe_mat)) {
      col_chr <- alt
    } else if (ncol(mcpe_mat) == 1) {
      # last resort: use the only column
      col_chr <- colnames(mcpe_mat)[1]
    } else {
      stop("Requested MCPE column not found. Available: ",
           paste(colnames(mcpe_mat), collapse = ", "))
    }
  }
  
  diff <- eblup_mat[, period_list[2]] - eblup_mat[, period_list[1]]
  # All moments come from identical joint bootstrap error draws. Their
  # difference variance cannot be negative except for floating-point error.
  .mse1 <- mse_mat[, period_list[1]]
  .mse2 <- mse_mat[, period_list[2]]
  .joint <- sae_joint_error_moments(.mse1, .mse2, mcpe_mat[, col_chr])
  mse_indep <- .mse1 + .mse2
  mse_with_cov <- .joint$difference
  use_cov <- .joint$valid & is.finite(mse_with_cov) & mse_with_cov > 0
  mse <- ifelse(use_cov, mse_with_cov, NA_real_)

  df <- tibble::tibble(
    domain = mcpe_obj$domain,  # Added: extract domain from mcpe_obj
    diff = diff,
    mse = mse,
    mse_independence = mse_indep,
    mse_covariance_adjusted = mse_with_cov,
    covariance_estimate = .joint$mcpe,
    annual_mse_y1 = .mse1,
    annual_mse_y2 = .mse2,
    annual_mcpe = .joint$mcpe,
    mse_fallback_used = FALSE,
    mse_rule = ifelse(use_cov, "joint_bootstrap", "unavailable_joint_moments"),
    alpha = rep(alpha, nrow(eblup_mat)),
    zq = qnorm(alpha / 2, lower.tail = FALSE)
  ) |>
    dplyr::mutate(
      lb = diff - zq * sqrt(mse),
      ub = diff + zq * sqrt(mse),
      z_stat = diff / sqrt(mse),
      p_value = 2 * stats::pnorm(abs(z_stat), lower.tail = FALSE),
      p_value_bh = stats::p.adjust(p_value, method = "BH"),
      p_value_bonferroni = stats::p.adjust(p_value, method = "bonferroni"),
      significant_unadjusted = ifelse(p_value < alpha, "Significant", "Not Significant"),
      significant_bh = ifelse(p_value_bh < alpha, "Significant", "Not Significant"),
      significant_bonferroni = ifelse(p_value_bonferroni < alpha, "Significant", "Not Significant"),
      significance_rule = "pointwise_unadjusted",
      significant = significant_unadjusted,
      index = dplyr::row_number()
    )
  
  # Build axis/title labels from year_labels if provided, else use period indices
  if (!is.null(year_labels)) {
    plot_title  <- paste(pov_lab$short, "Changes Between", year_labels[1], "and", year_labels[2])
    y_label     <- paste0("Change in ", pov_lab$short, " (", year_labels[2], " - ", year_labels[1], ")")
  } else {
    plot_title  <- paste0("Change in ", tolower(pov_lab$short),
                           " based on MCPE between period ",
                           period_list[1], " and ", period_list[2])
    y_label     <- "Difference between time periods"
  }

  df$inference_status <- inference_status
  df$inference_warning <- inference_warning
  p1 <- sae_mfh_change_plot(df, plot_title, y_label,
                            inference_status, inference_warning, alpha = alpha)
  
  list(df = df, plot = p1)
}

# Back-compat alias: earlier versions of this pipeline exposed the same
# helper under the MFH2-specific name `compare_mfh2`.
compare_mfh2 <- compare_mfh


if (is.null(mcpe_obj)) {
  comp12_obj <- NULL
} else {
comp12_obj <- compare_mfh(mcpe_obj = mcpe_obj, year_labels = years_keep,
                          inference_status = .inference_status,
                          inference_warning = .inference_warning)



}

if (!is.null(comp12_obj)) {
  print(comp12_obj$plot)
  ggsave(here::here("outputs", "figures", "mfh_change_preview.png"),
         comp12_obj$plot, width = 12, height = 6, dpi = 150)
  print(comp12_obj$df %>% head() %>% kable())
} else {
  cat("Change analysis skipped -- eblupMFH2 was not properly executed.\n")
}



comp12_bench_obj <- NULL

if (do_benchmark && !is.null(bench_result) && !is.null(bench_result$mcpe_bench)) {

  # Build a pseudo mcpe_obj for compare_mfh2() using benchmarked quantities
  bench_mcpe_obj <- list(
    domain = domain_dt$domain,
    eblup  = bench_result$eblup_bench,
    mse    = bench_result$mse_bench,
    mcpe   = bench_result$mcpe_bench
  )

  comp12_bench_obj <- compare_mfh(
    period_list = c(1, 2),
    mcpe_obj    = bench_mcpe_obj,
    year_labels = years_keep,
    inference_status = .inference_status,
    inference_warning = .inference_warning
  )



  cat("### Benchmarked ", diag_model, " Change Analysis\n\n", sep = "")
  .bench_plot <- comp12_bench_obj$plot +
    ggplot2::labs(title = paste("Benchmarked", pov_lab$short, "Changes Between",
                                years_keep[1], "and", years_keep[2]))
  print(.bench_plot)
  ggsave(here::here("outputs", "figures", "mfh_change_bench_preview.png"),
         .bench_plot, width = 12, height = 6, dpi = 150)
  print(comp12_bench_obj$df %>% head() %>% kable())
}

if (is.null(comp12_bench_obj)) {
  cat("Benchmarked change analysis not available ",
      "(benchmarking not applied or MCPE not computed).\n")
}


if (exists("comp12_obj") && !is.null(comp12_obj)) {
  p_change_unbench <- sae_mfh_change_plot(
    comp12_obj$df,
    paste(pov_lab$short, "Changes Between", years_keep[1], "and", years_keep[2],
          "(Without Benchmarking)"),
    paste0("Change in ", pov_lab$short, " (", years_keep[2], " - ", years_keep[1], ")"),
    .inference_status, .inference_warning, model_label = diag_model
  )
  print(p_change_unbench)
  ggsave(here::here("outputs", "figures", "mfh_change_unbench_points.png"),
         p_change_unbench, width = 12, height = 6, dpi = 150)
}


if (exists("comp12_obj") && !is.null(comp12_obj)) {
  p_change_unbench_hist <- sae_mfh_change_plot(
    comp12_obj$df,
    paste0("Distribution of ", pov_lab$short, " Changes (Without Benchmarking)"),
    paste0("Change in ", pov_lab$short, " (", years_keep[2], " - ", years_keep[1], ")"),
    .inference_status, .inference_warning, model_label = diag_model, histogram = TRUE
  )
  print(p_change_unbench_hist)
  ggsave(here::here("outputs", "figures", "mfh_change_unbench_hist.png"),
         p_change_unbench_hist, width = 10, height = 6, dpi = 150)
}


if (exists("comp12_bench_obj") && !is.null(comp12_bench_obj)) {
  p_change_bench <- sae_mfh_change_plot(
    comp12_bench_obj$df,
    paste(pov_lab$short, "Changes Between", years_keep[1], "and", years_keep[2],
          "(With Benchmarking)"),
    paste0("Change in ", pov_lab$short, " (", years_keep[2], " - ", years_keep[1], ")"),
    .inference_status, .inference_warning, model_label = diag_model
  )
  print(p_change_bench)
  ggsave(here::here("outputs", "figures", "mfh_change_bench_points.png"),
         p_change_bench, width = 12, height = 6, dpi = 150)
}


if (exists("comp12_bench_obj") && !is.null(comp12_bench_obj)) {
  p_change_bench_hist <- sae_mfh_change_plot(
    comp12_bench_obj$df,
    paste0("Distribution of ", pov_lab$short, " Changes (With Benchmarking)"),
    paste0("Change in ", pov_lab$short, " (", years_keep[2], " - ", years_keep[1], ")"),
    .inference_status, .inference_warning, model_label = diag_model, histogram = TRUE
  )
  print(p_change_bench_hist)
  ggsave(here::here("outputs", "figures", "mfh_change_bench_hist.png"),
         p_change_bench_hist, width = 10, height = 6, dpi = 150)
}



if (exists("comp12_obj") && !is.null(comp12_obj) &&
    exists("comp12_bench_obj") && !is.null(comp12_bench_obj)) {

  comparison_df <- tibble(
    domain       = comp12_obj$df$domain,
    sig_unbench  = comp12_obj$df$significant,
    sig_bench    = comp12_bench_obj$df$significant,
    diff_unbench = comp12_obj$df$diff,
    diff_bench   = comp12_bench_obj$df$diff
  ) %>%
    mutate(
      status = case_when(
        sig_unbench == "Significant" & sig_bench == "Significant"         ~ "Significant in both",
        sig_unbench == "Not Significant" & sig_bench == "Not Significant" ~ "Not significant in either",
        sig_unbench == "Significant" & sig_bench == "Not Significant"     ~ "Significant only without benchmarking",
        sig_unbench == "Not Significant" & sig_bench == "Significant"     ~ "Significant only with benchmarking"
      )
    )

  cat("Exploratory counts of pointwise results; no familywide interpretation.\n")
  if (nzchar(.inference_warning)) cat(.inference_warning, "\n")
  cat(sprintf("=== Impact of Benchmarking on %s Pointwise Results ===\n\n",
              diag_model))
  status_tbl <- table(comparison_df$status)
  for (s in names(status_tbl)) {
    cat(sprintf("  %s: %d domains\n", s, status_tbl[s]))
  }

  # Descriptive statistics comparison
  desc_stats <- data.frame(
    Statistic = c("Mean difference", "Median difference", "Std. deviation",
                  "Minimum", "Maximum",
                  "Significant domains"),
    Unbench = c(
      mean(comp12_obj$df$diff), median(comp12_obj$df$diff), sd(comp12_obj$df$diff),
      min(comp12_obj$df$diff), max(comp12_obj$df$diff),
      sum(comp12_obj$df$significant == "Significant")
    ),
    Bench = c(
      mean(comp12_bench_obj$df$diff), median(comp12_bench_obj$df$diff),
      sd(comp12_bench_obj$df$diff),
      min(comp12_bench_obj$df$diff), max(comp12_bench_obj$df$diff),
      sum(comp12_bench_obj$df$significant == "Significant")
    )
  )
  names(desc_stats)[2:3] <- c(diag_model, paste0(diag_model, "_Bench"))
  cat("\n")
  suppressWarnings({
    print(kable(desc_stats, digits = 6,
                col.names = c("Statistic",
                              paste0(diag_model, " (Unbenchmarked)"),
                              paste0(diag_model, " Benchmarked")),
                caption = paste0("Descriptive Statistics: ", pov_lab$short, " Changes")))
  })

  # Show domains where significance changed
  changed <- comparison_df %>% filter(sig_unbench != sig_bench)
  if (nrow(changed) > 0) {
    cat("\nDomains where benchmarking changed the significance conclusion:\n")
    suppressWarnings({
      print(kable(changed %>% select(domain, diff_unbench, diff_bench, status),
                  digits = 4,
                  col.names = c("Domain", "Diff (Unbenchmarked)", "Diff (Benchmarked)", "Status"),
                  caption = "Domains with Different Significance Conclusions"))
    })
  } else {
    cat("\nBenchmarking did not change any significance conclusions.\n")
  }
} else {
  cat("Comparison requires both benchmarked and unbenchmarked change analysis.\n")
}



plots <- lapply(X = years_keep,
       FUN = function(x){

         shp_dt |>
           merge(db_wide_all %>%
                   filter(year == x) |>
                   select(domain, modelpov = all_of(rate_col)),
                 by = "domain") |>
           ggplot() +
           geom_sf(aes(fill = modelpov), color = NA) +
            (if (identical(indicator_type, "mean_welfare")) {
              sae_fill_welfare(name = pov_lab$axis_label,
                limits = range(db_wide_all[[rate_col]], na.rm = TRUE))
            } else {
              sae_fill_level(name = pov_lab$short,
                limits = range(db_wide_all[[rate_col]], na.rm = TRUE))
            }) +
            theme_minimal(base_size = 16) +
            labs(
              title = paste0("Spatial Distribution of ", pov_lab$short,
                              " (", diag_model, ") ", x),
              caption = sae_map_caption(.map_attribution, "Data source: Author Calculation")
            ) +
            theme(
              legend.position = "bottom",
              axis.text = element_blank(),
              axis.ticks = element_blank(),
              panel.grid = element_blank()
            )
       })
for (i in seq_along(plots)) {
  ggsave(here::here("outputs", "figures", paste0("mfh_map_y", i, ".png")),
         plots[[i]], width = 12, height = 10, dpi = 150)
}



### lets work with our shapefile
# Extract poverty rates from the selected model
longpov_dt <-
  db_wide_all |>
  select(domain, year, modelpov = all_of(rate_col)) |>
  mutate(
    domain = trimws(as.character(domain)),
    year = as.numeric(year),
    modelpov = as.numeric(modelpov)
  )

### lets perform a regression for each area of poverty rates against year 
### and then we divide the slope variable by the average poverty rate

growth_dt <-
  longpov_dt |>
  group_by(domain) |>
  group_modify(~ {
    x <- .x[is.finite(.x$year) & is.finite(.x$modelpov), , drop = FALSE]
    denom <- mean(x$modelpov, na.rm = TRUE)
    growth <- if (nrow(x) >= 2 && is.finite(denom) && abs(denom) > 1e-12) {
      unname(coef(lm(modelpov ~ year, data = x))[2] / denom)
    } else {
      NA_real_
    }
    tibble(growth_rate = growth)
  }) |>
  ungroup()

shp_dt <- shp_dt |>
  mutate(domain = trimws(as.character(domain))) |>
  left_join(growth_dt, by = "domain")

# Cap growth rates at 1 to reduce the influence of extreme outliers
shp_dt <- shp_dt |>
  mutate(growth_rate_capped = pmin(growth_rate, 1))

.growth_limit_min <- min(shp_dt$growth_rate_capped, na.rm = TRUE)
if (!is.finite(.growth_limit_min)) .growth_limit_min <- 0
.growth_limit_min <- min(.growth_limit_min, 0.5)
if (.growth_limit_min >= 0.5) .growth_limit_min <- 0.5 - 1e-6

p_growth <- ggplot(shp_dt) +
  geom_sf(aes(fill = growth_rate_capped), color = NA) +
  sae_fill_change(
    name   = "Growth Rate (capped at 1)",
    limits = c(.growth_limit_min, 0.5),
    guide = guide_colourbar(
      direction = "horizontal", title.position = "top",
      barwidth = grid::unit(12, "cm"), barheight = grid::unit(0.45, "cm")
    ),
    oob    = squish
  ) +
  labs(
    title    = paste("Spatial Distribution of", pov_lab$short, "Growth Rates"),
    subtitle = "Growth rates capped at 1 to reduce outlier influence",
    caption = sae_map_caption(.map_attribution, "Data source: Author calculation")
  ) +
  theme_minimal(base_size = 16) +
  theme(
    legend.position = "bottom",
    legend.text = element_text(size = 14),
    legend.title = element_text(size = 16),
    plot.title = element_text(size = 18, face = "bold"),
    plot.subtitle = element_text(size = 14),
    plot.caption = element_text(size = 12),
    axis.text       = element_blank(),
    axis.ticks      = element_blank(),
    panel.grid      = element_blank()
  )
print(p_growth)
ggsave(here::here("outputs", "figures", "mfh_growth_rate_map.png"),
       p_growth, width = 12, height = 10, dpi = 150)




# ============================================================
# Save Results: Export estimates and comparison tables
#
# This chunk creates two output files:
# 1. comparison_final.csv: MCPE-based differences with selected
#    model (`diag_model` = MFH1/MFH2/MFH3) and direct estimates
#    by year.
# 2. pov_mfh.xlsx: Estimation results for the selected MFH model,
#    all years, with MSEs and CVs
# ============================================================

# Back-transform / rebenchmark for mean-welfare-with-log was applied
# earlier (right after `db_wide_all` and `bench_result` were finalized,
# before any plotting chunks read those objects). See the
# back-transform-mean-welfare chunk near the bottom of the
# benchmarking section.

# ---- Prepare comparison table ----
# Reshape selected model and direct estimates from long to wide format by year
model_wide <- db_wide_all %>%
  select(domain, year, all_of(rate_col)) %>%
  pivot_wider(
    names_from = year,
    values_from = all_of(rate_col),
    names_prefix = paste0(tolower(diag_model), "_")
  )

direct_wide <- db_wide_all %>%
  select(domain, year, direct_rate) %>%
  pivot_wider(
    names_from = year,
    values_from = direct_rate,
    names_prefix = "direct_"
  )

# Merge MCPE differences with year-specific estimates. MCPE is now
# produced for every MFH variant (MFH1/MFH2/MFH3) by pbmcpe_with_existing(),
# so comparison_final gets the full diff/mse/lb/ub/significant columns
# whenever `comp12_obj` is available.
if (exists("comp12_obj") && !is.null(comp12_obj) && is.data.frame(comp12_obj$df)) {
  comparison_final <- comp12_obj$df %>%
    left_join(model_wide, by = "domain") %>%
    left_join(direct_wide, by = "domain")
} else {
  # The MCPE-based change analysis (`comp12_obj`) is not available. Explain
  # the actual condition rather than assuming that every absence was caused
  # by direct variances or by MFH2.
  .mcpe_unavailable_reason <- if (isTRUE(.model_fit_failed)) {
    sprintf("the selected %s model did not pass the REML convergence check", diag_model)
  } else if (identical(var_choice, "direct")) {
    sprintf(
      "the %s parametric bootstrap did not produce usable MCPE results with raw direct sampling variances",
      diag_model
    )
  } else {
    sprintf("the %s parametric bootstrap did not produce usable MCPE results", diag_model)
  }
  cat(
    "\n**Note:** the MCPE-based change analysis is not available for this run because ",
    .mcpe_unavailable_reason,
    ". The export retains NA placeholders for change, MSE, interval, and significance fields; review the model diagnostics before changing variance or covariance settings.\n\n",
    sep = ""
  )
  comparison_final <- model_wide %>%
    left_join(direct_wide, by = "domain") %>%
    mutate(
      diff        = NA_real_,
      mse         = NA_real_,
      lb          = NA_real_,
      ub          = NA_real_,
      significant = NA
    )
}

# ---- Add benchmarked estimates to comparison_final if available ----
if (do_benchmark && !is.null(bench_result) && "rate_Bench" %in% colnames(db_wide_all)) {
  bench_wide <- db_wide_all %>%
    select(domain, year, rate_Bench) %>%
    pivot_wider(
      names_from = year,
      values_from = rate_Bench,
      names_prefix = "bench_"
    )
  comparison_final <- comparison_final %>%
    left_join(bench_wide, by = "domain")
}



# ---- Export results ----
comparison_final$inference_status <- .inference_status
comparison_final$covariance_boundary_reason <- .covariance_boundary_reason
comparison_final$inference_warning <- .inference_warning
write.csv(
  comparison_final,
  file = here::here("outputs", "tables", "comparison_final.csv"),
  row.names = FALSE
)



# Export benchmarked change analysis if available
if (exists("comp12_bench_obj") && !is.null(comp12_bench_obj)) {
  comp12_bench_obj$df$inference_status <- .inference_status
  comp12_bench_obj$df$covariance_boundary_reason <- .covariance_boundary_reason
  comp12_bench_obj$df$inference_warning <- .inference_warning
  write.csv(
    comp12_bench_obj$df,
    file = here::here("outputs", "tables", "comparison_final_bench.csv"),
    row.names = FALSE
  )
}

# Export complete model comparison results (now includes Bench columns).
# Use writexl rather than openxlsx -- the latter has been observed to
# produce workbooks where the sheet dimension is "A1" and relationships
# point to missing drawing parts even though the cell data is present,
# which causes some downstream readers to open an empty workbook.
# writexl writes a minimal, conformant XLSX that all common readers
# parse cleanly. Strip ggplot/Hmisc attributes that cause writexl to
# refuse columns of class "labelled" or with non-trivial attributes.
.write_xlsx_safe <- function(df, path) {
  if (!requireNamespace("writexl", quietly = TRUE)) {
    install.packages("writexl", repos = "https://cloud.r-project.org")
  }
  df <- as.data.frame(df)
  for (col in names(df)) {
    x <- df[[col]]
    attributes(x) <- NULL
    if (inherits(x, c("haven_labelled", "labelled"))) x <- as.vector(x)
    df[[col]] <- x
  }
  writexl::write_xlsx(df, path = path)
}
.selected_mfh_cols <- paste0(
  rep(c("rate_", "mse_", "cv_", "rmse_"), each = 1),
  diag_model
)
.all_mfh_cols <- grep("^(rate|mse|cv|rmse)_MFH[123]$", names(db_wide_all),
                      value = TRUE)
.drop_mfh_cols <- setdiff(.all_mfh_cols, .selected_mfh_cols)
.mfh_export <- db_wide_all %>%
  select(-any_of(.drop_mfh_cols))
.mfh_export$mfh_inference_status <- .inference_status
.mfh_export$mfh_covariance_boundary_reason <- .covariance_boundary_reason
.mfh_export$mfh_inference_warning <- .inference_warning
.benchmark_export_enabled <- isTRUE(do_benchmark) &&
  exists("bench_result") &&
  !is.null(bench_result)
if (!.benchmark_export_enabled) {
  .benchmark_export_cols <- grep("(^|_)Bench($|_)", names(.mfh_export), value = TRUE)
  .mfh_export <- .mfh_export %>%
    select(-any_of(.benchmark_export_cols))
} else {
  if ("rate_Bench" %in% names(.mfh_export) && !"MFH_Bench" %in% names(.mfh_export)) {
    .mfh_export$MFH_Bench <- .mfh_export$rate_Bench
  }
  if ("mse_Bench" %in% names(.mfh_export) && !"MFH_Bench_MSE" %in% names(.mfh_export)) {
    .mfh_export$MFH_Bench_MSE <- .mfh_export$mse_Bench
  }
  if ("rmse_Bench" %in% names(.mfh_export) && !"MFH_Bench_RMSE" %in% names(.mfh_export)) {
    .mfh_export$MFH_Bench_RMSE <- .mfh_export$rmse_Bench
  }
  if ("cv_Bench" %in% names(.mfh_export) && !"MFH_Bench_CV" %in% names(.mfh_export)) {
    .mfh_export$MFH_Bench_CV <- .mfh_export$cv_Bench
  }
}
.mfh_export <- sae_enrich_result_table(
  .mfh_export,
  domain_metadata = domain_metadata,
  population = domain_population,
  poverty_lines = poverty_line_export
)
.write_xlsx_safe(.mfh_export, here::here("outputs", "data", "pov_mfh.xlsx"))

# ---- Display summary ----
cat("Results exported successfully:\n")
cat("  - comparison_final.csv:", nrow(comparison_final), "domains\n")
if (exists("comp12_bench_obj") && !is.null(comp12_bench_obj)) {
  cat("  - comparison_final_bench.csv:", nrow(comp12_bench_obj$df), "domains (benchmarked)\n")
}
cat("  - pov_mfh.xlsx:", nrow(.mfh_export), "domain-year combinations; selected model =", diag_model, "\n")
