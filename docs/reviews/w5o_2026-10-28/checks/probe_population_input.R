source('scripts/population_helpers.R')
p <- matrix(c(100,900,900,100),2,dimnames=list(c('A','B'),c('2020','2019')))
path <- 'tmp/w5o_review_20261028/pop_reversed.rds'
saveRDS(p,path)
got <- sae_population_matrix_from_file(path,c('A','B'),c(2019,2020))
expected <- p[,c('2019','2020')]
cat('Expected year-labelled populations:\n'); print(expected)
cat('Actual populations:\n');print(got)
stopifnot(!isTRUE(all.equal(got,expected)))
rates <- c(.1,.5)
cat('2019 weighted model mean: expected',weighted.mean(rates,expected[,'2019']),
    'actual',weighted.mean(rates,got[,'2019']),'\n')
