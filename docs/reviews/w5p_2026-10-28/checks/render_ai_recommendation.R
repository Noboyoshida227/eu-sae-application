# Private verification helper. Run only inside a copied synthetic integration
# folder; this script renders existing numerical artifacts and never fits models.
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 2L, args[1L] %in% c("on", "off", "failure"))
mode <- args[1L]
receipt_dir <- normalizePath(args[2L], winslash = "/", mustWork = TRUE)
stopifnot(file.exists("integration_config.yml"),
          grepl("Synthetic w5p integration fixture", paste(readLines("integration_config.yml"), collapse = "\n"), fixed = TRUE))
Sys.setenv(SAE_APP_CONFIG = normalizePath("integration_config.yml", winslash = "/"))
source("app_support.R")
source("R/comparison_report_ai.R")
prompts <- list()
mock <- list(enabled = TRUE, provider = "deterministic_mock", model = "fixture_only", query = function(prompt, system_prompt) {
  prompts[[length(prompts) + 1L]] <<- list(user = prompt, system = system_prompt)
  if (identical(mode, "failure")) stop("Deterministic test provider unavailable.")
  if (grepl("advisory UFH-versus-MFH recommendation", prompt, fixed = TRUE)) {
    return(paste(
      "Deterministic test recommendation: no clear preference for annual levels. Compare the matched precision summaries and the diagnostic adequacy before choosing UFH or MFH.",
      "For changes within the fitted two-year window, MFH can account for cross-period prediction-error covariance. UFH change uncertainty assumes period independence. These mock sentences are a software fixture, not a statistical recommendation for publication.",
      "This advice requires human review. Check boundary sensitivity, bootstrap diagnostics, data completeness and the publication objective. No model choice or numerical result has been changed.", sep = "\n\n"))
  }
  "Deterministic test commentary only. Review the displayed statistical evidence and its limitations."
})
state <- generate_comparison_ai_interpretations(mock, language = "en",
  indicator_type = "poverty",
  consent_recorded = TRUE, logger = message)
stopifnot(length(state$sections) == length(comparison_ai_sections()))
if (mode == "failure") stopifnot(state$sections$recommendation$status == "failed") else
  stopifnot(state$sections$recommendation$status == "generated")
save_comparison_ai_interpretations(state)
evidence <- load_comparison_ai_recommendation_evidence()
jsonlite::write_json(evidence, file.path(receipt_dir, paste0(mode, "_evidence.json")), pretty = TRUE, auto_unbox = TRUE, na = "null")
jsonlite::write_json(prompts, file.path(receipt_dir, paste0(mode, "_prompts.json")), pretty = TRUE, auto_unbox = TRUE)
result <- render_final_report(include_ai = mode != "off", include_word = TRUE)
stopifnot(result$rendered, file.exists(result$html), file.exists(result$docx))
html <- gsub("[[:space:]]+", " ", paste(readLines(result$html, warn = FALSE), collapse = "\n"))
has_section <- grepl('id="ai-recommendation"', html, fixed = TRUE)
has_heading <- grepl("AI Recommendation: UFH or MFH", html, fixed = TRUE)
if (mode == "off") {
  stopifnot(!has_section, !has_heading, !grepl("Deterministic test recommendation", html, fixed = TRUE))
} else {
  stopifnot(has_section, has_heading,
    grepl("advisory interpretation for analyst review", html, fixed = TRUE),
    grepl("deterministic_mock", html, fixed = TRUE),
    grepl("fixture_only", html, fixed = TRUE))
  if (mode == "on") stopifnot(grepl("Deterministic test recommendation", html, fixed = TRUE)) else
    stopifnot(grepl("Deterministic test provider unavailable", html, fixed = TRUE),
              !grepl("Deterministic test recommendation", html, fixed = TRUE))
}
jsonlite::write_json(list(mode = mode, status = "PASS", provider_calls = length(prompts),
  provider_kind = "deterministic_mock_no_network", ai_off_uses_cached_generated_state = mode == "off",
  recommendation_status = state$sections$recommendation$status,
  recommendation_section_present = has_section, heading_present = has_heading,
  fit_status = evidence$fit, matched_domain_years = evidence$completeness$matched_domain_years,
  result = result), file.path(receipt_dir, paste0(mode, "_result.json")), pretty = TRUE, auto_unbox = TRUE)
cat("REPORT VALIDATION PASS:", mode, "\n")
