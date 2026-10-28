# QER evidence experiment. Writes only the explicitly selected evidence folder.
# Same fixed regressors both periods; known sampling covariance; no selection,
# GVF, benchmarking or survey design. These limits are part of the design.
# Rscript tests/run_qer_coverage.R --library=... --mode=equivalence
# Rscript tests/run_qer_coverage.R --mode=balanced --outer=500 --bootstrap=1000
# Rscript tests/run_qer_coverage.R --mode=heterogeneous --outer=100 --bootstrap=500
args <- commandArgs(trailingOnly = TRUE)
option <- function(name, default) {
  z <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (length(z)) sub(paste0("^--", name, "="), "", tail(z, 1)) else default
}
lib <- option("library", "")
if (nzchar(lib)) .libPaths(c(lib, .libPaths()))
mode <- option("mode", "equivalence")
out <- option("output", "docs/validation/QER/evidence")
outer <- as.integer(option("outer", if (mode == "balanced") "500" else "100"))
B <- as.integer(option("bootstrap", if (mode == "balanced") "1000" else "500"))
stopifnot(mode %in% c("equivalence", "balanced", "heterogeneous"), outer >= 2, B >= 30)
dir.create(out, recursive = TRUE, showWarnings = FALSE)
source("tests/qer_simulation_helpers.R")
n <- 60L
X <- cbind(1, seq(-1, 1, length.out = n))
vardir <- c("v1", "v2", "c12")
formula <- list(y1 ~ x, y2 ~ x)

make_case <- function(name) {
  z <- switch(name,
    identity = list(q = .0025, rho = .65, r = .0009, re = .3, beta = c(.20, .04, .22, .05), scale = "none"),
    log_realistic = list(q = .02, rho = .8, r = .004, re = .5, beta = c(9, .15, 9.03, .18), scale = "log"),
    log_stress = list(q = .25 / (1 - .35^2), rho = .35, r = .10, re = .25, beta = c(2, .3, 2.1, .4), scale = "log"),
    boundary = list(q = .002, rho = .8, r = .004, re = .5, beta = c(9, .15, 9.03, .18), scale = "log"),
    heterogeneous = list(q = .02, rho = .8, r = .004, re = .5, beta = c(9, .15, 9.03, .18), scale = "log"),
    zero = list(q = 0, rho = 0, r = .004, re = .5, beta = c(9, .15, 9.03, .18), scale = "log"),
    zero_fixed = list(q = 0, rho = 0, r = .004, re = .5, beta = c(9, .15, 9.03, .18), scale = "log"),
    stop("Unknown scenario"))
  z$R <- cbind(rep(z$r, n), rep(z$r, n), rep(z$r * z$re, n))
  if (name == "heterogeneous") {
    multiplier <- exp(seq(log(.2), log(5), length.out = n))
    z$R[, 1] <- z$r * multiplier
    z$R[, 2] <- z$r * multiplier * seq(.8, 1.3, length.out = n)
    z$R[, 3] <- z$re * sqrt(z$R[, 1] * z$R[, 2])
  }
  z$name <- name
  z
}

generate <- function(q, rho, beta1, beta2, R, draws) {
  up <- matrix(rnorm(n * draws), n) * sqrt(q * (1 + rho))
  um <- matrix(rnorm(n * draws), n) * sqrt(q * (1 - rho))
  t1 <- as.vector(X %*% beta1) + (up + um) / sqrt(2)
  t2 <- as.vector(X %*% beta2) + (up - um) / sqrt(2)
  e1 <- matrix(rnorm(n * draws), n) * sqrt(R[, 1])
  e2 <- e1 * (R[, 3] / R[, 1]) + matrix(rnorm(n * draws), n) *
    sqrt(R[, 2] - R[, 3]^2 / R[, 1])
  list(t1 = t1, t2 = t2, y1 = t1 + e1, y2 = t2 + e2)
}

asdata <- function(y, R) data.frame(id = seq_len(n), x = X[, 2],
  y1 = as.vector(y$y1), y2 = as.vector(y$y2), v1 = R[, 1], v2 = R[, 2], c12 = R[, 3])

if (mode == "equivalence") {
  stopifnot(requireNamespace("msae", quietly = TRUE))
  source("R/mfh_bootstrap_helpers.R")
  source("R/msae_compat.R"); sae_install_msae_compat_functions()
  source("R/mfh_convergence_check.R")
  source("scripts/eblupMFH2_robust.R")
  .eblupMFH2_patched <- eblupMFH2
  eblupMFH2 <- eblupMFH2_robust
  rows <- list(); k <- 0L
  for (name in c("identity", "log_realistic", "log_stress", "boundary", "heterogeneous", "zero", "zero_fixed")) {
    sc <- make_case(name)
    for (j in seq_len(6L)) {
      seed <- 48100L + 100L * match(name, c("identity", "log_realistic", "log_stress", "boundary", "heterogeneous", "zero", "zero_fixed")) + j
      set.seed(seed)
      y <- generate(sc$q, sc$rho, sc$beta[1:2], sc$beta[3:4], sc$R, 1)
      if (name == "zero_fixed") {
        y$y1 <- y$t1 + .1 * (y$y1 - y$t1); y$y2 <- y$t2 + .1 * (y$y2 - y$t2)
      }
      dat <- asdata(y, sc$R)
      fast <- qer_block_fit(cbind(y$y1, y$y2), X, sc$R, thorough = TRUE)
      balanced <- if (name != "heterogeneous") qer_balanced_fit(y$y1, y$y2, X, sc$r, sc$re) else fast
      prod <- suppressWarnings(eblupMFH2(formula, vardir, data = dat, MAXITER = 300, PRECISION = 1e-5))
      valid <- sae_mfh_fit_usable(prod, "MFH2", formula, vardir, dat)
      fastvalid <- sae_mfh_fit_usable(qer_as_production(fast), "MFH2", formula, vardir, dat)
      bvalid <- sae_mfh_fit_usable(qer_as_production(balanced), "MFH2", formula, vardir, dat)
      rp <- as.numeric(unlist(prod$fit$rho))[1]
      qp <- prod$fit$refvar / (1 - rp^2)
      pe <- qer_block_evaluate(qp, rp, cbind(y$y1, y$y2), X, sc$R)
      k <- k + 1L
      rows[[k]] <- data.frame(scenario = name, seed = seed, production_valid = valid,
        fast_valid = fastvalid, balanced_valid = bvalid,
        production_q = qp, fast_q = fast$q, production_rho = rp, fast_rho = fast$rho,
        production_nll_minus_fast = pe$value - fast$nll,
        point_max_abs_difference = max(abs(prod$eblup - cbind(fast$eta1, fast$eta2))),
        balanced_max_abs_difference = max(abs(cbind(balanced$eta1, balanced$eta2) - cbind(fast$eta1, fast$eta2))),
        fast_boundary = fast$boundary)
    }
    cat("Equivalence completed:", name, "\n"); flush.console()
  }
  table <- do.call(rbind, rows)
  write.csv(table, file.path(out, "mfh2_fitter_equivalence.csv"), row.names = FALSE)
  print(table, row.names = FALSE)
  stopifnot(all(table$production_valid), all(table$fast_valid), all(table$balanced_valid),
            max(abs(table$production_nll_minus_fast)) < 1e-5,
            # Native msae rounds returned predictions to four decimal places.
            max(table$point_max_abs_difference) < 6e-5,
            max(table$balanced_max_abs_difference) < 2e-5)
  # Same bootstrap random numbers and production point/error-moment functions;
  # only the refitting engine differs. Includes a heterogeneous and boundary case.
  checks <- list()
  for (name in c("log_realistic", "boundary", "heterogeneous")) {
    sc <- make_case(name); set.seed(198431L)
    y <- generate(sc$q, sc$rho, sc$beta[1:2], sc$beta[3:4], sc$R, 1)
    dat <- asdata(y, sc$R)
    prod <- suppressWarnings(eblupMFH2(formula, vardir, data = dat, MAXITER = 300, PRECISION = 1e-5))
    fastrefit <- function(formula, vardir, data, ...) {
      Y <- vapply(formula, function(f) model.response(model.frame(f, data)), numeric(nrow(data)))
      qer_as_production(qer_block_fit(Y, model.matrix(formula[[1]], data), as.matrix(data[, vardir])))
    }
    run <- function(refit) suppressWarnings(sae_mfh_bootstrap("MFH2", formula, vardir, "id", prod,
      nB = 30, data = dat, seed = 482711L, back_transform = "log", refit_fn = refit,
      MAXITER = 300, PRECISION = 1e-5))
    aa <- run(eblupMFH2); bb <- run(fastrefit)
    row <- data.frame(scenario = name, draws = 30,
      production_rejected = aa$fails, fast_rejected = bb$fails,
      mse_max_relative_difference = max(abs(bb$mse - aa$mse) / aa$mse),
      mcpe_max_absolute_difference = max(abs(bb$mcpe - aa$mcpe)),
      mcpe_relative_to_mean_mse = max(abs(bb$mcpe - aa$mcpe)) / mean(aa$mse))
    checks[[name]] <- row; print(row)
    stopifnot(aa$fails == bb$fails, row$mse_max_relative_difference < .001,
              row$mcpe_relative_to_mean_mse < .001)
  }
  write.csv(do.call(rbind, checks), file.path(out, "mfh2_bootstrap_equivalence.csv"), row.names = FALSE)
  cat("All independent fitter and bootstrap equivalence checks passed.\n")
  quit(status = 0)
}

proof <- file.path(out, "mfh2_bootstrap_equivalence.csv")
if (!file.exists(proof)) stop("Run and pass --mode=equivalence before the coverage study.")
scenario_names <- if (mode == "balanced") c("identity", "log_realistic", "log_stress", "boundary") else "heterogeneous"
only <- option("scenario", "")
if (nzchar(only)) scenario_names <- intersect(scenario_names, only)
stopifnot(length(scenario_names) > 0)
rows <- list(); kk <- 0L
for (name in scenario_names) {
  sc <- make_case(name)
  design <- data.frame(scenario = name, domains = n, regressors_per_year = ncol(X),
    outer_replicates = outer, bootstrap_replicates = B, q = sc$q, rho = sc$rho,
    r_min = min(sc$R[, 1:2]), r_max = max(sc$R[, 1:2]), sampling_correlation = sc$re,
    beta1_intercept = sc$beta[1], beta1_slope = sc$beta[2],
    beta2_intercept = sc$beta[3], beta2_slope = sc$beta[4], scale = sc$scale,
    seed_base = 618000L + 10000L * match(name, c("identity", "log_realistic", "log_stress", "boundary", "heterogeneous")),
    seed_rule = "outer=seed_base+iteration; bootstrap=outer_seed+1000000",
    fitter = if (mode == "balanced") "exact balanced eigenspace REML" else "independent block REML",
    r_version = as.character(getRversion()),
    helper_md5 = unname(tools::md5sum("tests/qer_simulation_helpers.R")),
    runner_md5 = unname(tools::md5sum("tests/run_qer_coverage.R")))
  write.csv(design, file.path(out, paste0(name, "_design.csv")), row.names = FALSE)
  start <- proc.time()[3]
  scenario_rows <- list()
  for (j in seq_len(outer)) {
    seed <- design$seed_base + j
    set.seed(seed)
    y <- generate(sc$q, sc$rho, sc$beta[1:2], sc$beta[3:4], sc$R, 1)
    fit <- if (mode == "balanced") qer_balanced_fit(y$y1, y$y2, X, sc$r, sc$re) else
      qer_block_fit(cbind(y$y1, y$y2), X, sc$R)
    set.seed(seed + 1000000L)
    boot <- generate(fit$q, fit$rho, fit$beta1, fit$beta2, sc$R, B)
    if (mode == "balanced") {
      bf <- qer_balanced_fit(boot$y1, boot$y2, X, sc$r, sc$re)
      c1 <- matrix(rep(bf$c1, each = n), n); c2 <- matrix(rep(bf$c2, each = n), n)
      c12 <- matrix(rep(bf$c12, each = n), n)
    } else {
      fits <- lapply(seq_len(B), function(b) qer_block_fit(cbind(boot$y1[, b], boot$y2[, b]), X, sc$R))
      bf <- list(eta1 = sapply(fits, `[[`, "eta1"), eta2 = sapply(fits, `[[`, "eta2"),
        boundary = vapply(fits, `[[`, logical(1), "boundary"))
      c1 <- sapply(fits, `[[`, "c1"); c2 <- sapply(fits, `[[`, "c2"); c12 <- sapply(fits, `[[`, "c12")
    }
    if (sc$scale == "log") {
      point1 <- exp(fit$eta1 + fit$c1 / 2); point2 <- exp(fit$eta2 + fit$c2 / 2)
      truth1 <- exp(y$t1); truth2 <- exp(y$t2)
      error1 <- exp(bf$eta1 + c1 / 2) - exp(boot$t1)
      error2 <- exp(bf$eta2 + c2 / 2) - exp(boot$t2)
    } else {
      point1 <- fit$eta1; point2 <- fit$eta2; truth1 <- y$t1; truth2 <- y$t2
      error1 <- bf$eta1 - boot$t1; error2 <- bf$eta2 - boot$t2
    }
    ae1 <- as.vector(point1 - truth1); ae2 <- as.vector(point2 - truth2)
    # Prefix 500 versus 1000 uses the identical outer data and random stream.
    for (bb in sort(unique(c(min(500L, B), B)))) {
      use <- seq_len(bb)
      m1 <- rowMeans(error1[, use, drop = FALSE]^2); m2 <- rowMeans(error2[, use, drop = FALSE]^2)
      cross <- rowMeans(error1[, use, drop = FALSE] * error2[, use, drop = FALSE])
      dm <- pmax(0, m1 + m2 - 2 * cross)
      level_cover <- mean(c(abs(ae1) <= qnorm(.975) * sqrt(m1), abs(ae2) <= qnorm(.975) * sqrt(m2)))
      change_cover <- mean(abs(ae2 - ae1) <= qnorm(.975) * sqrt(dm))
      ratio_cover <- NA_real_
      if (sc$scale == "log") {
        rv <- pmax(0, m1 / point1^2 + m2 / point2^2 - 2 * cross / (point1 * point2))
        ratio_cover <- mean(abs(log(point2 / point1) - (y$t2 - y$t1)) <= qnorm(.975) * sqrt(rv))
      }
      # Literature-motivated diagnostic ONLY: studentized model-scale change.
      # Saegusa/Sugasawa/Lahiri (2020), section 2.3. Its positive-definite
      # covariance assumption fails at zero variance; those cases stay missing.
      cv <- c1 + c2 - 2 * c12
      original_cv <- fit$c1 + fit$c2 - 2 * fit$c12
      roots <- ((boot$t2 - boot$t1) - (bf$eta2 - bf$eta1)) / sqrt(cv)
      finite <- apply(is.finite(roots[, use, drop = FALSE]), 1, all) & as.vector(original_cv > 1e-14)
      student_cover <- NA_real_
      if (all(finite)) {
        qs <- t(apply(roots[, use, drop = FALSE], 1, quantile, probs = c(.025, .975), type = 8))
        actual_root <- as.vector((y$t2 - y$t1) - (fit$eta2 - fit$eta1)) / sqrt(original_cv)
        student_cover <- mean(actual_root >= qs[, 1] & actual_root <= qs[, 2])
      }
      row <- data.frame(scenario = name, outer = j, seed = seed, bootstrap = bb,
        fitted_q = fit$q, fitted_rho = fit$rho, fitted_boundary = fit$boundary,
        bootstrap_boundary_fraction = mean(bf$boundary[use]),
        bias = mean(c(ae1, ae2)), realized_mse = mean(c(ae1^2, ae2^2)),
        estimated_mse = mean(c(m1, m2)), realized_change_mse = mean((ae2 - ae1)^2),
        estimated_change_mse = mean(dm), level_coverage = level_cover,
        change_coverage = change_cover, percentage_coverage = ratio_cover,
        diagnostic_studentized_model_change_coverage = student_cover,
        diagnostic_studentized_available = all(finite))
      scenario_rows[[length(scenario_rows) + 1L]] <- row
    }
    # Checkpoint evidence every independent outer sample. No failed samples are
    # silently replaced; a numerical error stops this script with the prefix saved.
    write.csv(do.call(rbind, scenario_rows), file.path(out, paste0(name, "_outer.csv")), row.names = FALSE)
    if (j %% 10L == 0L || j == outer) {
      cat(sprintf("%s %d/%d outer samples; %.1f seconds\n", name, j, outer, proc.time()[3] - start)); flush.console()
    }
  }
  tab <- do.call(rbind, scenario_rows)
  for (bb in unique(tab$bootstrap)) {
    tt <- tab[tab$bootstrap == bb, ]
    se <- function(z) sd(z, na.rm = TRUE) / sqrt(sum(is.finite(z)))
    # Ratio SE uses the delta method across independent outer samples.
    ratio_se <- function(a, b) se(a - mean(a) / mean(b) * b) / mean(b)
    kk <- kk + 1L
    rows[[kk]] <- data.frame(scenario = name, domains = n, outer = nrow(tt), bootstrap = bb,
      bias = mean(tt$bias), bias_mcse = se(tt$bias),
      mse_ratio = mean(tt$estimated_mse) / mean(tt$realized_mse),
      mse_ratio_mcse = ratio_se(tt$estimated_mse, tt$realized_mse),
      change_mse_ratio = mean(tt$estimated_change_mse) / mean(tt$realized_change_mse),
      change_mse_ratio_mcse = ratio_se(tt$estimated_change_mse, tt$realized_change_mse),
      level_coverage = mean(tt$level_coverage), level_coverage_mcse = se(tt$level_coverage),
      change_coverage = mean(tt$change_coverage), change_coverage_mcse = se(tt$change_coverage),
      percentage_coverage = mean(tt$percentage_coverage), percentage_coverage_mcse = se(tt$percentage_coverage),
      fitted_boundary_fraction = mean(tt$fitted_boundary),
      bootstrap_boundary_fraction = mean(tt$bootstrap_boundary_fraction),
      diagnostic_studentized_change_coverage = mean(tt$diagnostic_studentized_model_change_coverage, na.rm = TRUE),
      diagnostic_studentized_change_mcse = se(tt$diagnostic_studentized_model_change_coverage),
      diagnostic_studentized_available_fraction = mean(tt$diagnostic_studentized_available))
  }
  print(rows[[kk]], row.names = FALSE)
  write.csv(do.call(rbind, rows), file.path(out, paste0(mode, if (nzchar(only)) paste0("_", only) else "", "_summary.csv")), row.names = FALSE)
}
