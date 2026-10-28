suppressPackageStartupMessages(library(dplyr))
for (expr in parse('scripts/01_ufh.R')) {
  if (is.call(expr) && identical(expr[[1]], as.name('<-')) &&
      identical(expr[[2]], as.name('build_mse_decomposition'))) eval(expr)
}
do_benchmark <- TRUE
fixture <- list(
  fh_dt=data.frame(domain=c('A','B'),region='all',Nd=1,direct_povrate=c(2,4)),
  fh_model=list(ind=data.frame(Domain=c('A','B'),FH=c(1,3))),
  pov_fh=data.frame(domain=c('A','B'),Direct_MSE=.1,FH_MSE=.05,FH_Bench_MSE=.08))
# External target=5, model average=2: the actual ratio must be 2.5.
external <- build_mse_decomposition(fixture)
cat('External-target diagnostic lambda:', external$lambda_r, '; actual=2.5\n')
stopifnot(all(external$lambda_r == 1.5))
# The stored direct_povrate is a log mean in log runs, but FH is in currency.
fixture$fh_dt$direct_povrate <- log(c(2,4))
logged <- build_mse_decomposition(fixture)
cat('Survey-target log-run diagnostic lambda:', logged$lambda_r, '; actual=1.5\n')
stopifnot(all(abs(logged$lambda_r - mean(log(c(2,4)))/2) < 1e-12))
cat('Confirmed: diagnostic factors ignore external targets and mix scales in log runs.\n')
