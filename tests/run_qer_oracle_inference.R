# Known-parameter inference diagnosis. This does not validate fitted inference.
# Writes only docs/validation/QER/evidence/oracle_inference.csv, using the saved designs.
# Independent precision-addition posterior and analytic unconditional lognormal
# error moments identify approximation error remaining even without estimation.
out <- "docs/validation/QER/evidence"
outer <- 5000L
n <- 60L
X <- cbind(1, seq(-1, 1, length.out = n))
results <- list()
for (name in c("identity", "log_realistic", "log_stress", "boundary")) {
  sc <- read.csv(file.path(out, paste0(name, "_design.csv")))
  set.seed(sc$seed_base + 9000000L)
  G <- sc$q * matrix(c(1, sc$rho, sc$rho, 1), 2)
  R <- sc$r_min * matrix(c(1, sc$sampling_correlation, sc$sampling_correlation, 1), 2)
  C <- solve(solve(G) + solve(R))
  K <- C %*% solve(R)
  mu <- cbind(X %*% c(sc$beta1_intercept, sc$beta1_slope),
              X %*% c(sc$beta2_intercept, sc$beta2_slope))
  samples <- n * outer
  means <- mu[rep(seq_len(n), outer), ]
  theta <- means + matrix(rnorm(samples * 2L), samples) %*% chol(G)
  y <- theta + matrix(rnorm(samples * 2L), samples) %*% chol(R)
  eta <- means + (y - means) %*% t(K)
  if (sc$scale == "none") {
    point <- eta; truth <- theta
    m1 <- rep(C[1, 1], samples); m2 <- rep(C[2, 2], samples); cp <- rep(C[1, 2], samples)
  } else {
    point <- exp(sweep(eta, 2, diag(C) / 2, "+")); truth <- exp(theta)
    # E[(E(theta|y)-theta)^2], integrating both model and sampling errors.
    m1 <- exp(2 * means[, 1] + 2 * G[1, 1]) * -expm1(-C[1, 1])
    m2 <- exp(2 * means[, 2] + 2 * G[2, 2]) * -expm1(-C[2, 2])
    cp <- exp(rowSums(means) + sum(diag(G)) / 2 + G[1, 2]) * -expm1(-C[1, 2])
  }
  e <- point - truth
  summarize <- function(z) {
    clusters <- colMeans(matrix(z, n, outer))
    c(mean = mean(clusters), mcse = sd(clusters) / sqrt(outer))
  }
  lev <- summarize((abs(e[, 1]) <= qnorm(.975) * sqrt(m1)) / 2 +
                   (abs(e[, 2]) <= qnorm(.975) * sqrt(m2)) / 2)
  change <- summarize(abs(e[, 2] - e[, 1]) <= qnorm(.975) * sqrt(m1 + m2 - 2 * cp))
  pct <- c(mean = NA_real_, mcse = NA_real_)
  if (sc$scale == "log") pct <- summarize(abs(log(point[, 2] / point[, 1]) - (theta[, 2] - theta[, 1])) <=
    qnorm(.975) * sqrt(m1 / point[, 1]^2 + m2 / point[, 2]^2 - 2 * cp / (point[, 1] * point[, 2])))
  exact <- summarize(abs((eta[, 2] - eta[, 1]) - (theta[, 2] - theta[, 1])) <=
    qnorm(.975) * sqrt(sum(diag(C)) - 2 * C[1, 2]))
  results[[name]] <- data.frame(scenario = name, seed = sc$seed_base + 9000000L,
    independent_outer = outer, domains = n, parameter_status = "known",
    interval_error_moments = "exact unconditional",
    annual_mse_ratio = mean(c(m1, m2)) / mean(e^2),
    change_mse_ratio = mean(m1 + m2 - 2 * cp) / mean((e[, 2] - e[, 1])^2),
    level_coverage = lev[1], level_coverage_mcse = lev[2],
    change_coverage = change[1], change_coverage_mcse = change[2],
    percentage_coverage = pct[1], percentage_coverage_mcse = pct[2],
    exact_model_change_coverage = exact[1], exact_model_change_mcse = exact[2])
}
tab <- do.call(rbind, results)
write.csv(tab, file.path(out, "oracle_inference.csv"), row.names = FALSE)
print(tab, row.names = FALSE)
