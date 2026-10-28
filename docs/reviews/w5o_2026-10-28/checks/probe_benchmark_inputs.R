# Read-only production review: extract selected pure helpers without sourcing a pipeline.
extract_functions <- function(path, wanted) {
  env <- new.env(parent = globalenv())
  for (expr in parse(path)) {
    if (is.call(expr) && identical(expr[[1]], as.name("<-")) &&
        is.symbol(expr[[2]]) && as.character(expr[[2]]) %in% wanted) eval(expr, env)
  }
  env
}
ufh <- extract_functions("scripts/01_ufh.R", c(".read_optional_benchmark_table", ".pick_col", ".targets_from_optional_benchmark"))
mfh <- extract_functions("scripts/02_mfh.R", c(".read_optional_benchmark_table", ".pick_col", ".matrix_from_optional_regional_benchmark"))
probe_path <- "tmp/w5o_review_20261028/benchmark_target_probe.rds"
input <- matrix(c(.30, .20), 1L, 2L, dimnames = list("all", c("2013", "2012")))
saveRDS(input, probe_path)
cat("Named input matrix:\n"); print(input)
cat("UFH parsed as 2012, 2013:\n"); print(ufh$.targets_from_optional_benchmark(probe_path, "all", c(2012, 2013)))
cat("MFH parsed as 2012, 2013:\n"); print(mfh$.matrix_from_optional_regional_benchmark(probe_path, "all", c(2012, 2013)))
duplicate <- data.frame(group = "all", year = c(2012, 2012, 2013), target = c(.20, .90, .30))
saveRDS(duplicate, probe_path)
cat("Conflicting duplicate group-year input:\n"); print(duplicate)
cat("UFH silently selects first duplicate:\n"); print(ufh$.targets_from_optional_benchmark(probe_path, "all", c(2012, 2013)))
cat("MFH silently selects first duplicate:\n"); print(mfh$.matrix_from_optional_regional_benchmark(probe_path, "all", c(2012, 2013)))
saveRDS(duplicate[c(2, 1, 3), ], probe_path)
cat("Reversing duplicate rows changes MFH result:\n"); print(mfh$.matrix_from_optional_regional_benchmark(probe_path, "all", c(2012, 2013)))
ratio <- extract_functions("scripts/ufh_functions.R", "sae_ufh_ratio_benchmark")
cat("Positive direct target does not ensure nonnegative individual ratio benchmarks:\n")
print(ratio$sae_ufh_ratio_benchmark(c(-.1, .3), c(.1, .3), c("all", "all"), c(1, 1)))
