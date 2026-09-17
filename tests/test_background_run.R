# ============================================================
# test_background_run.R -- background run helpers and the driver
#
# Covers the machinery that lets the dashboard run an analysis in a
# separate R process and stop it: status file, PID bookkeeping, process
# checks, the STOP marker, the step wrapper's PID file, and the driver
# script's failure path (no analysis packages needed).
#
# Run from the package root:  Rscript tests/test_background_run.R
# ============================================================

root <- normalizePath(if (file.exists("app_support.R")) "." else "..",
                      winslash = "/", mustWork = TRUE)
setwd(root)
source("app_support.R")

checks <- 0L
ok <- function(cond, msg) {
  checks <<- checks + 1L
  if (!isTRUE(cond)) stop("FAILED: ", msg, call. = FALSE)
  cat("  ok -", msg, "\n")
}
wait_until <- function(cond_fn, timeout = 30, step = 0.25) {
  t0 <- Sys.time()
  while (as.numeric(difftime(Sys.time(), t0, units = "secs")) < timeout) {
    if (isTRUE(tryCatch(cond_fn(), error = function(e) FALSE))) return(TRUE)
    Sys.sleep(step)
  }
  FALSE
}
rscript <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")

run_dir <- tempfile("sae_bg_test_")
dir.create(run_dir)
run_dir <- normalizePath(run_dir, winslash = "/", mustWork = TRUE)

cat("-- status file --\n")
ok(is.null(sae_bg_read_status(run_dir)), "no status before the first write")
ok(isTRUE(sae_bg_write_status(run_dir, state = "running", phase = "UFH")), "status written")
st <- sae_bg_read_status(run_dir)
ok(identical(st$state, "running") && identical(st$phase, "UFH") && nzchar(st$updated_at %||% ""),
   "status read back with a timestamp")
sae_bg_write_status(run_dir, phase = "MFH", extra = 42)
st <- sae_bg_read_status(run_dir)
ok(identical(st$state, "running") && identical(st$phase, "MFH") && identical(st$extra, 42),
   "later writes merge into the existing status")
ok(!file.exists(paste0(sae_bg_status_path(run_dir), ".tmp")), "no temporary file left behind")

cat("-- PID bookkeeping --\n")
ok(length(sae_bg_read_pids(run_dir)) == 0L, "no pids recorded yet")
sae_bg_record_pid(run_dir, "driver", 12345L)
sae_bg_record_pid(run_dir, "step_UFH", 23456L)
pids <- sae_bg_read_pids(run_dir)
ok(identical(unname(pids[c("driver", "step_UFH")]), c(12345L, 23456L)), "pids read back by name")
unlink(list.files(sae_bg_pid_dir(run_dir), full.names = TRUE))

cat("-- process checks --\n")
self_image <- sae_process_image(Sys.getpid())
ok(nzchar(self_image), paste0("own process has an image name (", self_image, ")"))
ok(sae_is_r_process(Sys.getpid()), "own process is recognised as R")
ok(!sae_process_alive(2147483000L), "a non-existent pid is not alive")
ok(identical(sae_process_image(NA), ""), "NA pid gives an empty image")
ok(!sae_kill_r_process(2147483000L), "killing a non-existent pid is refused, no error")

cat("-- STOP marker --\n")
Sys.setenv(SAE_RUN_DIR = run_dir)
ok(!sae_bg_stop_requested(), "no stop requested initially")
ok(!sae_bg_check_stop(), "check_stop is silent without a marker")
writeLines("now", sae_bg_stop_marker(run_dir))
ok(sae_bg_stop_requested(), "stop marker detected")
caught <- tryCatch({ sae_bg_check_stop(); "none" },
                   sae_run_stopped = function(e) "stopped",
                   error = function(e) "other-error")
ok(identical(caught, "stopped"), "check_stop signals a condition of class sae_run_stopped")
msgs <- character()
invisible(tryCatch(sae_bg_check_stop(logger = function(m) msgs <<- c(msgs, m)),
                   sae_run_stopped = function(e) NULL))
ok(any(grepl("Stop requested", msgs)), "check_stop logs the stop")
unlink(sae_bg_stop_marker(run_dir))

cat("-- step wrapper records and removes its pid file --\n")
step_script <- file.path(run_dir, "fake_step.R")
writeLines(c(
  'pidf <- file.path(Sys.getenv("SAE_RUN_DIR"), "pids", "step_TEST.pid")',
  'cat("pid file present during step:", file.exists(pidf), "\\n")',
  'if (file.exists(pidf)) cat("pid matches:", identical(trimws(readLines(pidf, warn = FALSE)), as.character(Sys.getpid())), "\\n")'
), step_script)
cfg_stub <- file.path(run_dir, "app_config.yml")
writeLines("years_keep: [2022, 2023]", cfg_stub)
res <- .pipeline_run_step("TEST", step_script, cfg_stub, logger = function(m) NULL)
ok(identical(res$status, 0L) && isTRUE(res$completed), "fake step completes")
ok(any(grepl("pid file present during step: TRUE", res$output, fixed = TRUE)),
   "child wrote its pid file before the step ran")
ok(any(grepl("pid matches: TRUE", res$output, fixed = TRUE)), "pid file holds the child's own pid")
ok(!file.exists(file.path(run_dir, "pids", "step_TEST.pid")), "pid file removed after the step")
Sys.unsetenv("SAE_RUN_DIR")
res2 <- .pipeline_run_step("TEST", step_script, cfg_stub, logger = function(m) NULL)
ok(identical(res2$status, 0L) && isTRUE(res2$completed) &&
     any(grepl("pid file present during step: FALSE", res2$output, fixed = TRUE)),
   "without SAE_RUN_DIR the wrapper writes no pid file and runs as before")

cat("-- stopping a running R child --\n")
pid_file <- file.path(run_dir, "sleeper.pid")
sleeper <- file.path(run_dir, "sleeper.R")
writeLines(c(sprintf('writeLines(as.character(Sys.getpid()), "%s")', pid_file),
             'Sys.sleep(120)'), sleeper)
system2(rscript, c("--vanilla", shQuote(sleeper)), stdout = FALSE, stderr = FALSE, wait = FALSE)
ok(wait_until(function() file.exists(pid_file)), "sleeper child started")
sleeper_pid <- as.integer(readLines(pid_file, warn = FALSE))
ok(sae_process_alive(sleeper_pid), "sleeper is alive")
ok(sae_is_r_process(sleeper_pid), "sleeper is recognised as an R process")
sae_bg_record_pid(run_dir, "step_UFH", sleeper_pid)
sae_bg_record_pid(run_dir, "driver", 2147483000L)
killed <- sae_bg_stop(run_dir)
ok(identical(killed, "step_UFH"), "sae_bg_stop ends the step child and leaves the driver alone")
ok(file.exists(sae_bg_stop_marker(run_dir)), "sae_bg_stop writes the STOP marker")
ok(wait_until(function() !sae_process_alive(sleeper_pid), timeout = 15), "sleeper is gone")
unlink(list.files(sae_bg_pid_dir(run_dir), full.names = TRUE))
unlink(sae_bg_stop_marker(run_dir))

cat("-- driver: failure path end to end --\n")
# The job points at a configuration the pipeline cannot use; the driver
# must record the failure in run_status.rds and run.log and exit.
driver_run <- file.path(run_dir, "driver_run")
dir.create(driver_run)
writeLines("not: a valid config", file.path(driver_run, "app_config.yml"))
saveRDS(list(config_path = normalizePath(file.path(driver_run, "app_config.yml"), winslash = "/"),
             run_id = "test", steps = c("UFH"), ai = list(requested = FALSE)),
        file.path(driver_run, "job.rds"))
driver_log <- sae_bg_launch(driver_run, api_key = NULL)
ok(identical(Sys.getenv("SAE_LLM_API_KEY", unset = "unset"), "unset"),
   "API key is not left in this process's environment")
st0 <- sae_bg_read_status(driver_run)
ok(identical(st0$state, "starting"), "launch writes the initial 'starting' status")
ok(wait_until(function() identical(sae_bg_read_status(driver_run)$state, "failed"), timeout = 90),
   "driver ends in state 'failed' for an unusable configuration")
st <- sae_bg_read_status(driver_run)
ok(is.character(st$err_msg) && nzchar(st$err_msg), paste0("failure reason recorded: ", substr(st$err_msg, 1, 60)))
ok(is.numeric(st$driver_pid) && st$driver_pid > 0, "driver recorded its pid in the status")
ok(wait_until(function() !sae_process_alive(st$driver_pid), timeout = 15), "driver process has exited")
log_txt <- paste(readLines(file.path(driver_run, "run.log"), warn = FALSE), collapse = "\n")
ok(grepl("Background analysis process started", log_txt) && grepl("ERROR:", log_txt),
   "run.log has the start line and the error")
ok(file.exists(driver_log), "driver_output.log exists")

unlink(run_dir, recursive = TRUE, force = TRUE)
cat(sprintf("All %d background-run checks passed.\n", checks))
