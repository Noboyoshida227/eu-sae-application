# Parametric-bootstrap prediction-error moments for MFH3.
# All variants share the same output-scale estimator and covariance preparation.
if (!exists("sae_mfh_bootstrap", mode = "function")) {
  .mfh_helper <- if (requireNamespace("here", quietly = TRUE)) {
    here::here("R", "mfh_bootstrap_helpers.R")
  } else file.path("R", "mfh_bootstrap_helpers.R")
  source(.mfh_helper)
  rm(.mfh_helper)
}

pbmcpeMFH3_with_existing <- function(formula, vardir, domain_var,
                                         existing_model, nB = 200, data,
                                         max_attempts = NULL, seed = 123L,
                                         back_transform = c("none", "log"),
                                         bias_correction = TRUE,
                                         fit_validator = NULL, ...) {
  sae_mfh_bootstrap(
    model_type = "MFH3", formula = formula, vardir = vardir,
    domain_var = domain_var, existing_model = existing_model, nB = nB,
    data = data, max_attempts = max_attempts, seed = seed,
    back_transform = match.arg(back_transform),
    bias_correction = bias_correction, fit_validator = fit_validator, ...
  )
}
