# Synthetic survey-design regressions: no confidential data or saved runs.
local({
  source("app_support.R", local = TRUE)
  source("R/brief_generator.R", local = TRUE)
  verify <- function(ok, label) {
    if (!isTRUE(ok)) stop(label, call. = FALSE)
    cat("PASS -", label, "\n")
  }
  near <- function(x, y) isTRUE(all.equal(unname(x), unname(y), tolerance = 1e-10))
  cfg <- list(years_keep = c(2019L, 2020L), run = list(steps = "MFH"))
  verify(!validate_app_config(cfg)$valid, "missing PSU choice blocks MFH")
  cfg$mfh <- list(psu_consistent = FALSE)
  verify(!validate_app_config(cfg)$valid, "legacy unchecked choice blocks MFH")
  cfg$mfh$psu_consistent <- TRUE
  verify(validate_app_config(cfg)$valid, "legacy checked choice means linked")
  cfg$mfh <- list(psu_design = "not_specified", psu_consistent = TRUE)
  verify(!validate_app_config(cfg)$valid, "explicit unspecified overrides legacy checked")
  cfg$run$steps <- "UFH"
  verify(validate_app_config(cfg)$valid, "unspecified choice permits UFH")
  for (choice in c("linked", "independent")) {
    cfg$run$steps <- "MFH"
    cfg$mfh <- list(psu_design = choice)
    verify(validate_app_config(cfg)$valid, paste("explicit design accepted:", choice))
  }
  verify(grepl("ERROR", sae_psu_readiness_messages("not_specified", "MFH")) &&
           !grepl("ERROR", sae_psu_readiness_messages("not_specified", "UFH")),
         "readiness blocks only MFH when design is unspecified")
  d <- expand.grid(hh = 1:3, psu = 1:4, strata = 1:2, year = 2019:2020)
  d$population_weight <- 1 + (seq_len(nrow(d)) %% 7) / 3
  d$poor <- (d$psu + d$hh + d$strata + (d$year - 2019) * d$psu) / 20
  d$domain <- ifelse(d$hh == 1, "A", "B")
  d$poor[c(2, 37)] <- NA_real_
  # Unequal PSU counts across years catch pooled-design variance corrections.
  d <- d[!(d$year == 2020 & d$psu == 4), ]
  for (stratified in c(FALSE, TRUE)) {
    independent <- sae_mfh_survey_design(d, "independent", stratified)
    joint <- survey::svyby(~poor, ~year, independent, survey::svymean,
                           na.rm = TRUE, covmat = TRUE)
    verify(abs(vcov(joint)[1, 2]) < 1e-12, "independent design has zero cross-year covariance")
    for (i in 1:2) {
      dy <- d[d$year == 2018 + i, ]
      separate <- if (stratified) survey::svydesign(ids = ~psu, strata = ~strata,
        weights = ~population_weight, data = dy, nest = TRUE) else
        survey::svydesign(ids = ~psu, weights = ~population_weight, data = dy)
      estimate <- survey::svymean(~poor, separate, na.rm = TRUE)
      verify(near(as.numeric(coef(joint)[i]), as.numeric(coef(estimate))) &&
               near(vcov(joint)[i, i], as.numeric(vcov(estimate))),
             paste("independent mean and variance match separate-year design", stratified, i))
    }
    linked <- sae_mfh_survey_design(d, "linked", stratified)
    original <- if (stratified) survey::svydesign(ids = ~psu, strata = ~strata,
      weights = ~population_weight, data = d, nest = TRUE) else
      survey::svydesign(ids = ~psu, weights = ~population_weight, data = d)
    linked_fit <- survey::svyby(~poor, ~year, linked, survey::svymean, na.rm = TRUE, covmat = TRUE)
    old_fit <- survey::svyby(~poor, ~year, original, survey::svymean, na.rm = TRUE, covmat = TRUE)
    verify(near(coef(linked_fit), coef(old_fit)) && near(vcov(linked_fit), vcov(old_fit)),
           "linked design preserves existing estimates and covariance")
    verify(abs(vcov(linked_fit)[1, 2]) > 1e-10, "linked fixture retains nonzero sampling covariance")
    domain_fit <- survey::svyby(~poor, ~year, subset(independent, domain == "A"),
                               survey::svymean, na.rm = TRUE, covmat = TRUE)
    verify(abs(vcov(domain_fit)[1, 2]) < 1e-12, "independence also holds within domains")
    renamed <- d
    renamed$psu[renamed$year == 2020] <- renamed$psu[renamed$year == 2020] + 100
    renamed_fit <- survey::svyby(~poor, ~year, sae_mfh_survey_design(renamed, "independent", stratified),
                                survey::svymean, na.rm = TRUE, covmat = TRUE)
    verify(near(vcov(joint), vcov(renamed_fit)), "independent results ignore accidental PSU code overlap")
  }
  verify(inherits(try(sae_mfh_survey_design(d, "not_specified"), silent = TRUE), "try-error"),
         "direct survey-design helper rejects unknown overlap")
  # Execute actual top-level script assignments to check non-UI enforcement.
  ast <- as.list(parse("scripts/02_mfh.R", encoding = "UTF-8"))
  assignment <- function(name) Filter(function(x) is.call(x) &&
    identical(x[[1]], as.name("<-")) && identical(x[[2]], as.name(name)), ast)[[1]]
  cfg <- list(mfh = list(psu_consistent = FALSE))
  verify(inherits(try(eval(assignment("psu_design")), silent = TRUE), "try-error"),
         "MFH script rejects legacy unchecked configuration")
  for (requested in c("direct", "rho_dir", "rho_sm_out", "rho_sm_all", "zero")) {
    cfg <- list(mfh = list(psu_design = "independent"))
    eval(assignment("psu_design"))
    mfh_cfg <- list(cov_choice = requested)
    var_choice <- "sm_out"
    eval(assignment("cov_choice"))
    verify(identical(cov_choice, "zero"), paste("MFH script enforces independence over", requested))
  }
  for (choice in c("linked", "independent", "not_specified")) {
    note <- generate_data_note(list(summary = list(), flags = character()), list(), psu_design = choice)
    verify(grepl(sae_psu_design_label(choice), note, fixed = TRUE), paste("data note records", choice))
  }
  note <- generate_data_note(list(summary = list(), flags = character()), list(),
    mfh_options = list(cov_choice = "direct"), psu_design = "independent")
  verify(grepl("**Covariance option:** zero", note, fixed = TRUE),
         "data note reports effective rather than overridden covariance")
})
