# Historical w5o reproduction, retained as audit evidence, not a w5p acceptance test.
# Use normal library discovery or set R_LIBS_USER before starting Rscript.
suppressPackageStartupMessages({library(dplyr);library(tidyr);library(data.table);library(survey)})
source('scripts/ufh_functions.R');source('R/pipeline_helpers.R');source('R/variance_policy.R')
for (e in parse('scripts/01_ufh.R')) {
  if(is.call(e) && identical(e[[1]],as.name('<-')) && is.symbol(e[[2]]) && as.character(e[[2]]) %in% c('run_fh_year','make_sae_design','.safe_cv')) eval(e)
}
indicator_type <- 'poverty';fgt_alpha <- 0L;log_transform <- FALSE;use_strata <- FALSE
ufh_bias_correction <- TRUE;ufh_bootstrap_nB <- 4L;analysis_seed <- 123L;ufh_ic_criterion <- 'BIC'
set.seed(238)
s <- do.call(rbind,lapply(1:24,function(i) {
  n <- 20+3*i;data.frame(domain=sprintf('D%02d',i),year=2019,psu=paste(i,seq_len(n),sep='_'),weight=1,hh_size=1,population_weight=1,welfare=ifelse(seq_len(n) <= ceiling(n*(.15+.4*i/24)),0,2),povline=1)
}))
rhs <- data.frame(domain=sprintf('D%02d',1:24),year=2019,x=1:24)
s$pov_indicator <- as.numeric(s$welfare<s$povline)
raw <- survey::svyby(~pov_indicator,~domain,make_sae_design(s),survey::svymean,na.rm=TRUE)
for (choice in c('direct','sm_all','sm_out')) {
  fit <- suppressWarnings(run_fh_year(2019,s,rhs,NULL,c(2019,2020),NULL,transformation='no',formula_override=direct_povrate~x,var_choice=choice))
  cat('\nCHOICE:',choice,'\n');print(data.frame(domain=fit$pov_fh$domain,raw_var=as.numeric(SE(raw))^2,exported_direct_MSE=fit$pov_fh$Direct_MSE)[1:5,]);
  cat('max difference',max(abs(as.numeric(SE(raw))^2-fit$pov_fh$Direct_MSE)),'\n')
}

# A domain present only in year 1 triggers an earlier GVF failure in MFH:
cat('\nMISSING YEAR GVF:\n')
print(try(varsmoothie_king(c('A','B'),c(.01,NA),c(10,NA)),silent=TRUE))
# And the downstream direct covariance fallback indexes a 1x1 result:
ss <- transform(s,poor=as.numeric(welfare<povline)); ds<-svydesign(ids=~psu,weights=~population_weight,data=ss)
V <- try(vcov(svyby(~as.numeric(poor),~year,subset(ds,domain=='D01'),svymean,covmat=TRUE,na.rm=TRUE)),silent=TRUE)
print(V)

# Execute unchanged production expressions from MFH year normalization through GVF.
suppressPackageStartupMessages(library(purrr))
survey_dt <- bind_rows(s,transform(s,year=2020)) |> filter(!(domain=='D24' & year==2020))
years_keep <- c(2019,2020)
source('R/validation_checks.R')
readiness <- assess_data_readiness(survey_dt,bind_rows(rhs,transform(rhs,year=2020)),save_to=NULL)
cat('\nREADINESS MESSAGES:\n');cat(readiness$messages,sep='\n');cat('\n')
parsed <- parse('scripts/02_mfh.R')
is_assign <- function(e,name) is.call(e) && identical(e[[1]],as.name('<-')) && identical(e[[2]],as.name(name))
from <- which(vapply(parsed,function(e)is_assign(e,'years_keep') && grepl('sort',paste(deparse(e),collapse='')),logical(1)))[1]
to <- which(vapply(parsed,function(e)is_assign(e,'var_smooth_long'),logical(1)))[1]
cat('\nACTUAL MFH CHUNK WITH D24 MISSING IN 2020:\n')
print(try(for (i in seq.int(from,to)) eval(parsed[[i]]),silent=TRUE))
