# Read an existing w5m artifact without modifying it. Only summary evidence is
# written to the requested new directory; original inputs/outputs stay intact.
# Rscript tools/qer_saved_spain_comparison.R <artifact.rds> <new-evidence-dir>
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 2L)
artifact_path <- normalizePath(args[1L], winslash = "/", mustWork = TRUE)
destination <- args[2L]
if (dir.exists(destination)) stop("Use a new evidence directory.")
source_hash <- digest::digest(file = artifact_path, algo = "sha256", serialize = FALSE)
source("R/msae_compat.R")
source("R/mfh_convergence_check.R")
source("scripts/eblupMFH2_robust.R")
a <- readRDS(artifact_path)
stopifnot(identical(a$diag_model, "MFH2"))
d <- get("domain_dt", environment(a$formula[[1]]), inherits = TRUE)
before <- sae_mfh_reml_endpoint(a$selected_model, "MFH2", a$formula, a$vardir_cols, d)
refit <- eblupMFH2_robust(a$formula, a$vardir_cols, data = d,
                         .orig_fn = sae_patch_msae_function("eblupMFH2"))
after <- attr(refit, ".reml_endpoint")
stopifnot(after$status == "ok", after$reml_loglik >= before$reml_loglik - 1e-8)
old <- as.matrix(a$selected_model$eblup)
new <- as.matrix(refit$eblup)
stopifnot(identical(dim(old), dim(new)), ncol(new) == 2L)
levels <- data.frame(domain = rep(d$domain, 2L),
                      year = rep(a$years_keep, each = nrow(d)),
                      w5m_estimate = as.vector(old), revised_estimate = as.vector(new),
                      difference_percentage_points = 100 * as.vector(new - old))
changes <- data.frame(domain = d$domain,
                       w5m_change_percentage_points = 100 * (old[, 2L] - old[, 1L]),
                       revised_change_percentage_points = 100 * (new[, 2L] - new[, 1L]))
summary <- data.frame(
  comparison = "Saved Spanish poverty fitting frame; formulas and sampling covariance held fixed",
  original_reml = before$reml_loglik, revised_reml = after$reml_loglik,
  original_status = before$status, revised_status = after$status,
  original_rho = a$selected_model$fit$rho$rho, revised_rho = refit$fit$rho$rho,
  revised_innovation_variance = refit$fit$refvar,
  revised_marginal_variance = refit$fit$refvar / (1 - refit$fit$rho$rho^2),
  max_level_shift_pp = max(abs(levels$difference_percentage_points)),
  max_change_shift_pp = max(abs(changes$revised_change_percentage_points - changes$w5m_change_percentage_points)))
dir.create(destination, recursive = TRUE)
write.csv(levels, file.path(destination, "saved_spain_levels.csv"), row.names = FALSE)
write.csv(changes, file.path(destination, "saved_spain_changes.csv"), row.names = FALSE)
write.csv(summary, file.path(destination, "saved_spain_summary.csv"), row.names = FALSE)
writeLines(c(paste("Source artifact SHA256:", source_hash),
             "These are revisions of a saved example fit, not newly validated official statistics.",
             "Covariates were held fixed: differences isolate the variance-parameter estimation repair.",
             "No saved analysis outputs or source microdata were changed."),
           file.path(destination, "saved_spain_provenance.txt"))
print(summary)
