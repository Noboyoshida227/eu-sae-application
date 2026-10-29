# Default-policy regressions. Run from the repository root using the locked
# library through normal R discovery or R_LIBS_USER. No saved runs are edited.
local({
  checks <- 0L
  verify <- function(ok, label) {
    checks <<- checks + 1L
    if (exists("check", mode = "function", inherits = TRUE)) {
      get("check", mode = "function", inherits = TRUE)(ok, label)
    } else {
      if (!isTRUE(ok)) stop(label, call. = FALSE)
      cat("PASS -", label, "\n")
    }
  }
  source("app_support.R", local = TRUE)
  source("R/brief_generator.R", local = TRUE)
  app_ast <- parse("app.R", encoding = "UTF-8")
  ufh_ast <- parse("scripts/01_ufh.R", encoding = "UTF-8")
  mfh_ast <- parse("scripts/02_mfh.R", encoding = "UTF-8")
  find_calls <- function(ast, predicate) {
    hits <- list()
    visit <- function(node) {
      if (missing(node)) return(invisible(NULL))
      if (is.call(node)) {
        if (isTRUE(predicate(node))) hits[[length(hits) + 1L]] <<- node
        for (i in seq_along(node)[-1L]) {
          if (!identical(node[[i]], quote(expr = ))) visit(node[[i]])
        }
      } else if (is.expression(node)) for (child in node) visit(child)
    }
    visit(ast)
    hits
  }
  is_assignment <- function(node, lhs) {
    is.call(node) && identical(node[[1L]], as.name("<-")) &&
      identical(paste(deparse(node[[2L]]), collapse = ""), lhs)
  }
  assignment <- function(ast, lhs) {
    hits <- find_calls(ast, function(x) is_assignment(x, lhs))
    if (!length(hits)) stop("Missing production assignment: ", lhs)
    hits[[1L]]
  }
  for (name in c("dashboard_setup_defaults", "apply_dashboard_setup", "sae_sanitize_setup",
                 "sae_setup_variance_notice", "collect_dashboard_setup")) eval(assignment(app_ast, name))

  # Execute the actual setup-collection/restoration prefixes, stopping before
  # unrelated browser/file controls. The UI callbacks are harmless stubs.
  prefix <- function(fun, last_assignment, result) {
    statements <- as.list(body(fun))[-1L]
    last <- which(vapply(statements, is_assignment, logical(1), lhs = last_assignment))[1L]
    stopifnot(is.finite(last))
    body(fun) <- as.call(c(list(as.name("{")), statements[seq_len(last)],
                          list(call("return", as.name(result)))))
    fun
  }
  restore <- prefix(apply_dashboard_setup, "x", "x")
  collect <- prefix(collect_dashboard_setup, "inputs$mfh_cov_choice", "inputs")
  session <- list(onFlushed = function(...) invisible(NULL))
  restoring_setup <- active_setup_files <- benchmark_upload_cleared <-
    setup_status_text <- function(...) invisible(NULL)
  notices <- character()
  showNotification <- function(ui, ...) notices <<- c(notices, as.character(ui))
  defaults <- dashboard_setup_defaults()$inputs
  verify(identical(defaults$ufh_var_choice, "sm_out") &&
           identical(defaults$mfh_var_choice, "sm_out") &&
           identical(defaults$mfh_cov_choice, "rho_sm_out"),
         "fresh dashboard configuration defaults to selective smoothing and matching covariance")
  for (missing in list(NULL, character(), NA_character_, "", "  ")) {
    restored <- restore(list(inputs = list(ufh_var_choice = missing,
      mfh_var_choice = missing, mfh_cov_choice = missing)))
    verify(identical(restored$ufh_var_choice, "sm_out") &&
             identical(restored$mfh_var_choice, "sm_out") &&
             identical(restored$mfh_cov_choice, "rho_sm_out"),
           "missing or blank saved policy fields resolve to selective smoothing")
    cfg <- list(years_keep = c(2019L, 2020L),
      ufh = list(var_choice = missing),
      mfh = list(var_choice = missing, cov_choice = missing))
    verify(isTRUE(validate_app_config(cfg)$valid),
           "configuration validation accepts missing-policy defaults consistently")
    ufh_cfg <- cfg$ufh
    mfh_cfg <- cfg$mfh
    eval(assignment(ufh_ast, "ufh_var_choice"))
    eval(assignment(mfh_ast, "var_choice"))
    eval(assignment(mfh_ast, "cov_choice"))
    verify(identical(ufh_var_choice, "sm_out") && identical(var_choice, "sm_out") &&
             identical(cov_choice, "rho_sm_out"),
           "direct script entry resolves missing settings to the same defaults")
  }
  cov_for <- c(sm_all = "rho_sm_all", sm_out = "rho_sm_out", direct = "rho_dir")
  for (choice in names(cov_for)) {
    input <- list(ufh_transformation = "log", ufh_var_choice = choice,
                  mfh_var_choice = choice)
    collected <- collect()
    restored <- restore(list(inputs = input))
    verify(identical(collected$ufh_var_choice, choice) &&
             identical(restored$ufh_var_choice, choice) &&
             identical(restored$mfh_var_choice, choice) &&
             identical(collected$mfh_cov_choice, unname(cov_for[choice])) &&
             identical(restored$mfh_cov_choice, unname(cov_for[choice])),
           paste("saved-setup collection/restoration preserves", choice, "and pairs missing covariance"))
  }
  for (choice in c("direct", "zero", "rho_sm_out")) {
    input <- list(ufh_var_choice = "sm_out", mfh_var_choice = "sm_out",
                  mfh_cov_choice = choice)
    verify(identical(restore(list(inputs = input))$mfh_cov_choice, choice) &&
             identical(collect()$mfh_cov_choice, choice),
           paste("explicit saved covariance survives setup round trip:", choice))
  }
  verify(identical(sae_covariance_choice("rho_sm", "sm_out"), "rho_sm_out"),
         "legacy rho_sm alias retains selective-smoothing meaning")
  for (choice in c("sm_all", "direct")) {
    legacy <- list(inputs = list(ufh_transformation = "log", ufh_var_choice = choice))
    notices <- character()
    restored <- restore(legacy)
    verify(identical(restored$ufh_var_choice, choice) && length(notices) == 1L &&
             grepl("older dashboard versions always applied sm_out", notices, fixed = TRUE) &&
             grepl("Select sm_out", notices, fixed = TRUE),
           paste("legacy hidden log choice", choice, "is preserved with a load-time reproducibility notice"))
    legacy$variance_policy_ui_version <- 2L
    notices <- character()
    restore(sae_sanitize_setup(legacy))
    verify(length(notices) == 0L,
           paste("newly saved visible log choice", choice, "does not receive a legacy notice"))
  }
  verify(!nzchar(sae_setup_variance_notice(list(inputs = list(
    ufh_transformation = "log", ufh_var_choice = "sm_out")))) &&
    !nzchar(sae_setup_variance_notice(list(inputs = list(
      ufh_transformation = "no", ufh_var_choice = "direct")))),
    "unchanged old log policies and identity setups do not receive the legacy-log notice")

  # Exercise the production variance observer, including covariance choices
  # that should survive a variance change rather than being reset.
  observer <- find_calls(app_ast, function(x) identical(x[[1L]], as.name("observeEvent")) &&
    identical(paste(deparse(x[[2L]]), collapse = ""), "input$mfh_var_choice"))[[1L]][[3L]]
  isolate <- function(x) x
  updateSelectInput <- function(session, inputId, choices, selected) {
    updated <<- list(id = inputId, choices = choices, selected = selected)
  }
  for (choice in names(cov_for)) for (current in c("direct", "zero", "stale")) {
    input <- list(mfh_var_choice = choice, mfh_cov_choice = current)
    eval(observer)
    expected <- if (current == "stale") unname(cov_for[choice]) else current
    verify(identical(updated$selected, expected) &&
             identical(updated$choices, c(unname(cov_for[choice]), "direct", "zero")),
           paste("variance observer pairs", choice, "while retaining compatible covariance", current))
  }

  # Render the actual controls from each interface and evaluate their display
  # condition for each transformation; no browser or application is started.
  tip_label <- function(label, ...) label
  selectInput <- shiny::selectInput
  for (file in c("app.R", "app_wizard.R")) {
    ast <- parse(file, encoding = "UTF-8")
    for (id in c("ufh_var_choice", "mfh_var_choice", "mfh_cov_choice")) {
      control <- find_calls(ast, function(x) identical(x[[1L]], as.name("selectInput")) &&
        identical(x[[2L]], id))[[1L]]
      rendered <- xml2::read_html(as.character(eval(control)))
      selected <- xml2::xml_attr(xml2::xml_find_first(rendered, ".//option[@selected]"), "value")
      verify(identical(selected, if (id == "mfh_cov_choice") "rho_sm_out" else "sm_out"),
             paste(file, id, "renders the selective-smoothing default"))
    }
    panel <- find_calls(ast, function(x) identical(x[[1L]], as.name("conditionalPanel")) &&
      length(find_calls(x, function(y) identical(y[[1L]], as.name("selectInput")) &&
        identical(y[[2L]], "ufh_var_choice"))) > 0L)[[1L]]
    condition <- gsub("input.ufh_transformation", "transformation", panel$condition, fixed = TRUE)
    visible <- vapply(c("no", "log", "arcsin"), function(transformation)
      eval(parse(text = condition)), logical(1))
    verify(identical(unname(visible), c(TRUE, TRUE, FALSE)),
           paste(file, "shows the variance menu for identity/log and retains separate arcsine behavior"))
  }

  # Execute the same serialization expressions used by Run Analysis and then
  # round-trip YAML. This prevents a displayed log choice being pinned on wire.
  scratch <- tempfile("variance_defaults_")
  dir.create(scratch)
  on.exit(unlink(scratch, recursive = TRUE), add = TRUE)
  for (choice in c(NA_character_, "sm_all", "sm_out", "direct")) {
    input <- list(ufh_transformation = "log", ufh_var_choice = choice,
                  mfh_var_choice = choice)
    for (name in c("ufh_var_val", "mfh_var_val", "mfh_cov_val")) eval(assignment(app_ast, name))
    ufh_wire <- list(var_choice = eval(assignment(app_ast, "ufh_cfg")[[3L]]$var_choice))
    mfh_wire <- list(var_choice = eval(assignment(app_ast, "mfh_cfg")[[3L]]$var_choice),
                     cov_choice = eval(assignment(app_ast, "mfh_cfg")[[3L]]$cov_choice))
    wire <- list(ufh = ufh_wire, mfh = mfh_wire)
    write_app_config(wire, file.path(scratch, "config.yml"))
    saved <- yaml::read_yaml(file.path(scratch, "config.yml"))
    expected <- sae_variance_choice(choice)
    verify(identical(saved$ufh$var_choice, expected) &&
             identical(saved$mfh$var_choice, expected) &&
             identical(saved$mfh$cov_choice, unname(cov_for[expected])),
           paste("log UI serialization preserves effective policy:", expected))
    note <- generate_data_note(list(summary = list(), flags = character()), list(),
      ufh_options = list(transformation = "log", var_choice = saved$ufh$var_choice),
      mfh_options = saved$mfh)
    verify(grepl(paste0("**Variance option:** ", expected, " (log-scale variances)"), note, fixed = TRUE) &&
             grepl(paste0("**Covariance option:** ", cov_for[expected]), note, fixed = TRUE),
           paste("generated brief reports the actual log policy and covariance:", expected))
  }
  arcsin_note <- generate_data_note(list(summary = list(), flags = character()), list(),
    ufh_options = list(transformation = "arcsin", var_choice = "sm_all"), steps = "UFH")
  verify(grepl("1/(4*n_eff)", arcsin_note, fixed = TRUE) &&
           !grepl("**Variance option:** sm_all", arcsin_note, fixed = TRUE),
         "arcsine brief discloses its distinct effective-sample-size variance")

  # Evaluate the MFH production column selection against distinguishable
  # variance/covariance columns, including explicit old alternatives.
  for (choice in names(cov_for)) {
    mfh_cfg <- if (choice == "sm_out") list() else list(var_choice = choice)
    for (name in c("var_menu", "cov_menu", "var_choice", "cov_choice", "vardir_cols"))
      eval(assignment(mfh_ast, name))
    expected_variances <- switch(choice, sm_all = c("v1_sm_all", "v2_sm_all"),
      sm_out = c("v1_sm_out", "v2_sm_out"), direct = c("v1_direct", "v2_direct"))
    expected_covariance <- switch(choice, sm_all = "v12_d_ncsm_all", sm_out = "v12_d_ncsm", direct = "v12_d_nc")
    verify(identical(vardir_cols, c(expected_variances, expected_covariance)),
           paste("MFH runtime selects matching diagonal/off-diagonal columns for", choice))
  }

  # Fit the production UFH function with omitted versus explicit settings.
  # Existing selective-smoothing fixtures remain unchanged elsewhere.
  suppressPackageStartupMessages({ library(dplyr); library(tidyr); library(data.table); library(survey) })
  source("scripts/ufh_functions.R", local = TRUE)
  for (name in c("run_fh_year", "make_sae_design", ".safe_cv", ".safe_cv_from_mse",
                 ".targets_from_optional_benchmark")) eval(assignment(ufh_ast, name))
  write.csv <- function(x, file, ...) utils::write.csv(x, file.path(scratch, basename(file)), ...)
  use_strata <- FALSE
  ufh_bias_correction <- TRUE
  ufh_bootstrap_nB <- 8L
  analysis_seed <- 123L
  ufh_ic_criterion <- "BIC"
  fgt_alpha <- 0L
  price_factors <- setNames(c(1, 1), c("2019", "2020"))
  survey_input <- do.call(rbind, lapply(seq_len(24), function(i) {
    n <- 20 + 3 * i
    data.frame(domain = sprintf("D%02d", i), year = 2019L,
      psu = paste(i, seq_len(n), sep = "_"), weight = 1, hh_size = 1, population_weight = 1,
      welfare = ifelse(seq_len(n) <= ceiling(n * (.15 + .4 * i / 24)), 0, 2), povline = 1)
  }))
  rhs <- data.frame(domain = sprintf("D%02d", seq_len(24)), year = 2019L, x = seq_len(24))
  fit <- function(choice = NULL, transformation = "no") {
    args <- list(yr = 2019L, survey_all = survey_input, rhs_dt_raw = rhs, shp_dt = NULL,
      years_keep = c(2019L, 2020L), region_map = NULL, transformation = transformation,
      formula_override = direct_povrate ~ x, do_benchmark = FALSE)
    if (!is.null(choice)) args$var_choice <- choice
    result <- NULL
    invisible(capture.output(result <- suppressWarnings(do.call(run_fh_year, args))))
    result
  }
  for (scale in c("identity", "log")) {
    indicator_type <- if (scale == "identity") "poverty" else "mean_welfare"
    log_transform <- scale == "log"
    if (log_transform) survey_input$welfare <- ifelse(survey_input$welfare == 0, 1, 50) +
      as.numeric(sub("D", "", survey_input$domain)) * .25
    default_fit <- fit()
    full_fit <- fit("sm_all")
    direct_fit <- fit("direct")
    selective_fit <- fit("sm_out")
    verify(isTRUE(all.equal(default_fit$fh_model$ind, selective_fit$fh_model$ind)) &&
             isTRUE(all.equal(default_fit$variance_audit, selective_fit$variance_audit)) &&
             all(default_fit$variance_audit$variance_policy == "sm_out"),
           paste("omitted UFH policy fits exactly as explicit selective smoothing on", scale, "scale"))
    verify(any(abs(full_fit$variance_audit$working_variance - default_fit$variance_audit$working_variance) > 1e-10),
           paste("explicit full smoothing changes actual working variances on", scale, "scale"))
    verify(all(direct_fit$variance_audit$variance_policy == "direct") &&
             all(selective_fit$variance_audit$variance_policy == "sm_out") &&
             isTRUE(all.equal(selective_fit$variance_audit$working_variance,
               sae_sm_out_variance(direct_fit$variance_audit$working_variance,
                                    full_fit$variance_audit$working_variance))),
           paste("explicit old policies retain actual working-variance behavior on", scale, "scale"))
    verify(isTRUE(all.equal(default_fit$pov_fh$Direct_MSE, direct_fit$pov_fh$Direct_MSE)) &&
             isTRUE(all.equal(default_fit$pov_fh$Direct_MSE, selective_fit$pov_fh$Direct_MSE)),
           paste("raw Direct uncertainty remains independent of selected working policy on", scale, "scale"))
  }
  indicator_type <- "poverty"
  log_transform <- FALSE
  survey_input$welfare <- ifelse(survey_input$welfare < 10, 0, 2)
  arcsin_default <- fit(transformation = "arcsin")
  arcsin_direct <- fit("direct", transformation = "arcsin")
  verify(isTRUE(all.equal(arcsin_default$variance_audit, arcsin_direct$variance_audit)) &&
           all(arcsin_default$variance_audit$variance_policy == "effective_sample_size") &&
           isTRUE(all.equal(arcsin_default$fh_model$ind, arcsin_direct$fh_model$ind)),
         "arcsine keeps its distinct working variance regardless of the variance default")
  cat(sprintf("All %d variance-default checks passed.\n", checks))
})
