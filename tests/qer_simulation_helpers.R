# Simulation-only MFH2 calculations, independently derived from 2x2 blocks.
# These routines never enter the application. Same regressors in both years.
qer_cap <- 1 - 1e-6

qer_balanced_fit <- function(Y1, Y2, X, r, re) {
  Y1 <- as.matrix(Y1); Y2 <- as.matrix(Y2)
  n <- nrow(X); nu <- n - ncol(X)
  invxx <- solve(crossprod(X))
  zp <- (Y1 + Y2) / sqrt(2); zm <- (Y1 - Y2) / sqrt(2)
  bp <- invxx %*% crossprod(X, zp); bm <- invxx %*% crossprod(X, zm)
  mp <- X %*% bp; mm <- X %*% bm
  ep <- zp - mp; em <- zm - mm
  sp <- colSums(ep^2) / nu; sm <- colSums(em^2) / nu
  rp <- r * (1 + re); rm <- r * (1 - re)
  gp <- pmax(sp - rp, 0); gm <- pmax(sm - rm, 0)
  q <- (gp + gm) / 2
  rho <- ifelse(q > 0, (gp - gm) / (2 * q), 0)
  boundary <- which(abs(rho) > qer_cap)
  for (j in boundary) {
    rr <- sign(rho[j]) * qer_cap
    cc <- c(1 + rr, 1 - rr); rs <- c(rp, rm); ss <- c(sp[j], sm[j])
    objective <- function(qq) sum(log(rs + qq * cc) + ss / (rs + qq * cc))
    upper <- max(ss, rs) * 100
    oo <- optimize(objective, c(0, upper), tol = max(1e-14, upper * 1e-12))
    q[j] <- if (objective(0) <= oo$objective) 0 else oo$minimum
    rho[j] <- if (q[j] > 0) rr else 0
  }
  gp <- q * (1 + rho); gm <- q * (1 - rho)
  hp <- mp + sweep(ep, 2, gp / (gp + rp), "*")
  hm <- mm + sweep(em, 2, gm / (gm + rm), "*")
  cp <- gp * rp / (gp + rp); cm <- gm * rm / (gm + rm)
  list(q = q, rho = rho, beta1 = (bp + bm) / sqrt(2),
       beta2 = (bp - bm) / sqrt(2), eta1 = (hp + hm) / sqrt(2),
       eta2 = (hp - hm) / sqrt(2), c1 = (cp + cm) / 2,
       c2 = (cp + cm) / 2, c12 = (cp - cm) / 2,
       boundary = abs(rho) >= qer_cap | q == 0)
}

qer_block_evaluate <- function(q, rho, Y, X, R, gradient = TRUE) {
  n <- nrow(X); p <- ncol(X)
  aa <- q + R[, 1]; bb <- q * rho + R[, 3]; dd <- q + R[, 2]
  det <- aa * dd - bb^2
  if (any(det <= 0)) return(list(value = Inf, gradient = c(NA_real_, NA_real_)))
  a <- dd / det; b <- -bb / det; d <- aa / det
  cross <- function(w) crossprod(X, X * w)
  block <- function(a, b, d) rbind(cbind(cross(a), cross(b)), cbind(cross(b), cross(d)))
  M <- block(a, b, d); C <- chol(M); Minv <- chol2inv(C)
  rhs <- rbind(crossprod(X, a * Y[, 1] + b * Y[, 2]),
               crossprod(X, b * Y[, 1] + d * Y[, 2]))
  beta <- as.vector(Minv %*% rhs)
  mu <- cbind(X %*% beta[seq_len(p)], X %*% beta[p + seq_len(p)])
  e <- Y - mu
  value <- .5 * (sum(log(det)) + 2 * sum(log(diag(C))) +
                 sum(a * e[, 1]^2 + 2 * b * e[, 1] * e[, 2] + d * e[, 2]^2))
  score <- NULL
  if (gradient) {
    z1 <- a * e[, 1] + b * e[, 2]; z2 <- b * e[, 1] + d * e[, 2]
    score_one <- function(da, db, dc) {
      ua <- da * a^2 + 2 * db * a * b + dc * b^2
      ub <- da * a * b + db * (a * d + b^2) + dc * b * d
      ud <- da * b^2 + 2 * db * b * d + dc * d^2
      .5 * (sum(da * z1^2 + 2 * db * z1 * z2 + dc * z2^2) -
            sum(da * a + 2 * db * b + dc * d) + sum(Minv * block(ua, ub, ud)))
    }
    score <- -c(score_one(1, rho, 1), score_one(0, q, 0))
  }
  k11 <- q * (a + rho * b); k12 <- q * (b + rho * d)
  k21 <- q * (rho * a + b); k22 <- q * (rho * b + d)
  eta <- mu + cbind(k11 * e[, 1] + k12 * e[, 2],
                    k21 * e[, 1] + k22 * e[, 2])
  list(value = value, gradient = score, beta = beta, eta = eta,
       c1 = pmax(0, q - q * (k11 + rho * k12)),
       c2 = pmax(0, q - q * (rho * k21 + k22)),
       c12 = q * rho - q * (rho * k11 + k12))
}

qer_block_fit <- function(Y, X, R, thorough = FALSE) {
  # Scale-free optimizer in marginal variance and correlation, same constraints
  # as production. All candidate likelihoods include the REML determinant.
  residual <- qr.resid(qr(X), Y)
  base <- max(mean(R[, 1:2]), mean(residual^2), 1e-10)
  q0 <- max(mean(residual^2) - mean(R[, 1:2]), base * .05)
  rho0 <- max(-.95, min(.95, (mean(residual[, 1] * residual[, 2]) - mean(R[, 3])) / q0))
  cached_par <- NULL; cached <- NULL
  evaluate <- function(par) {
    if (!identical(par, cached_par)) {
      cached_par <<- par
      cached <<- qer_block_evaluate(par[1] * base, par[2], Y, X, R)
    }
    cached
  }
  starts <- rbind(c(q0 / base, rho0), c(q0 / base, 0), c(.05, .95), c(.05, -.95))
  if (thorough) starts <- rbind(starts, c(1, .7), c(1, -.7), c(3, 0))
  best <- list(par = c(0, 0), value = qer_block_evaluate(0, 0, Y, X, R)$value)
  for (j in seq_len(nrow(starts))) {
    oo <- tryCatch(optim(starts[j, ], function(par) evaluate(par)$value,
                         function(par) evaluate(par)$gradient * c(base, 1),
                         method = "L-BFGS-B", lower = c(0, -qer_cap),
                         upper = c(Inf, qer_cap),
                         control = list(factr = 1e5, pgtol = 1e-7, maxit = 150)),
                   error = function(e) NULL)
    if (!is.null(oo) && is.finite(oo$value) && oo$value < best$value) best <- oo
  }
  q <- best$par[1] * base; rho <- if (q > 0) best$par[2] else 0
  z <- qer_block_evaluate(q, rho, Y, X, R)
  list(q = q, rho = rho, beta1 = z$beta[seq_len(ncol(X))],
       beta2 = z$beta[ncol(X) + seq_len(ncol(X))],
       eta1 = z$eta[, 1], eta2 = z$eta[, 2], c1 = z$c1,
       c2 = z$c2, c12 = z$c12, nll = z$value,
       boundary = abs(rho) >= qer_cap - 1e-8 | q == 0)
}

qer_as_production <- function(fit) {
  list(eblup = cbind(as.vector(fit$eta1), as.vector(fit$eta2)),
       fit = list(convergence = TRUE, refvar = fit$q * (1 - fit$rho^2),
                  rho = fit$rho, estcoef = matrix(c(fit$beta1, fit$beta2), ncol = 1)))
}
