# Audit a deterministic subset of the saved heterogeneous simulation using
# the production endpoint validator. Also verifies complete saved outer runs.
args <- commandArgs(trailingOnly = TRUE)
lib <- grep("^--library=", args, value = TRUE)
if (length(lib)) .libPaths(c(sub("^--library=", "", lib[1]), .libPaths()))
source("tests/qer_simulation_helpers.R")
source("R/mfh_bootstrap_helpers.R")
source("R/mfh_convergence_check.R")
out <- "docs/QER/evidence"
names <- c("identity", "log_realistic", "log_stress", "boundary", "heterogeneous")
for (name in names) {
  des <- read.csv(file.path(out, paste0(name, "_design.csv")))
  tab <- read.csv(file.path(out, paste0(name, "_outer.csv")))
  for (bb in unique(tab$bootstrap)) stopifnot(identical(tab$outer[tab$bootstrap == bb], seq_len(des$outer_replicates)))
  stopifnot(all(is.finite(tab$change_coverage)), all(tab$estimated_mse >= 0),
    all(tab$estimated_change_mse >= 0), all(tab$level_coverage >= 0 & tab$level_coverage <= 1),
    des$helper_md5 == unname(tools::md5sum("tests/qer_simulation_helpers.R")),
    des$runner_md5 == unname(tools::md5sum("tests/run_qer_coverage.R")))
}
n <- 60L; X <- cbind(1, seq(-1, 1, length.out = n))
sc <- read.csv(file.path(out, "heterogeneous_design.csv"))
multiplier <- exp(seq(log(.2), log(5), length.out = n))
R <- cbind(.004 * multiplier, .004 * multiplier * seq(.8, 1.3, length.out = n), 0)
R[, 3] <- .5 * sqrt(R[, 1] * R[, 2])
generate <- function(q, rho, beta1, beta2, draws) {
  u1 <- matrix(rnorm(n * draws), n) * sqrt(q * (1 + rho))
  u2 <- matrix(rnorm(n * draws), n) * sqrt(q * (1 - rho))
  t1 <- as.vector(X %*% beta1) + (u1 + u2) / sqrt(2)
  t2 <- as.vector(X %*% beta2) + (u1 - u2) / sqrt(2)
  e1 <- matrix(rnorm(n * draws), n) * sqrt(R[, 1])
  e2 <- e1 * R[, 3] / R[, 1] + matrix(rnorm(n * draws), n) * sqrt(R[, 2] - R[, 3]^2 / R[, 1])
  list(y1 = t1 + e1, y2 = t2 + e2)
}
rows <- list()
validate <- function(fit, y1, y2, outer, draw) {
  dat <- data.frame(x = X[, 2], y1 = y1, y2 = y2, v1 = R[, 1], v2 = R[, 2], c12 = R[, 3])
  endpoint <- sae_mfh_reml_endpoint(qer_as_production(fit), "MFH2", list(y1 ~ x, y2 ~ x), c("v1", "v2", "c12"), dat)
  data.frame(outer = outer, bootstrap_draw = draw, status = endpoint$status,
    newton_decrement = endpoint$newton_decrement, fitted_q = fit$q, fitted_rho = fit$rho)
}
for (j in seq_len(sc$outer_replicates)) {
  set.seed(sc$seed_base + j)
  y <- generate(sc$q, sc$rho, c(sc$beta1_intercept, sc$beta1_slope), c(sc$beta2_intercept, sc$beta2_slope), 1)
  fit <- qer_block_fit(cbind(y$y1, y$y2), X, R)
  rows[[length(rows) + 1L]] <- validate(fit, y$y1, y$y2, j, 0)
  set.seed(sc$seed_base + j + 1000000L)
  boot <- generate(fit$q, fit$rho, fit$beta1, fit$beta2, sc$bootstrap_replicates)
  for (b in c(1L, sc$bootstrap_replicates)) {
    ff <- qer_block_fit(cbind(boot$y1[, b], boot$y2[, b]), X, R)
    rows[[length(rows) + 1L]] <- validate(ff, boot$y1[, b], boot$y2[, b], j, b)
  }
}
result <- do.call(rbind, rows)
write.csv(result, file.path(out, "heterogeneous_endpoint_audit.csv"), row.names = FALSE)
print(table(result$status))
stopifnot(all(result$status == "ok"))
cat("Evidence completeness, provenance hashes, and all 300 audited endpoints pass.\n")
