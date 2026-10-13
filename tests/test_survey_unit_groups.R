# Survey unit (household or person rows), benchmark-group conflicts and the
# value-free data overview in logs (w5o). Synthetic data only: the cases mimic
# the two problems found in a country team's run (a person-level file read as
# households, and one domain coded in two benchmark groups in one year).
source("R/pipeline_helpers.R")

local({
  checks <- 0L
  ok <- function(value, label) {
    if (!isTRUE(value)) stop("FAILED: ", label, call. = FALSE)
    checks <<- checks + 1L
    cat("PASS -", label, "\n")
  }
  set.seed(42)
  n_hh <- 60L
  size <- sample(1:5, n_hh, replace = TRUE)
  hh <- data.frame(year = 2022L, hh_id = sprintf("H%03d", seq_len(n_hh)),
                   domain = rep(c("D1", "D2", "D3"), length.out = n_hh),
                   weight = 100, hh_size = size, stringsAsFactors = FALSE)
  persons <- hh[rep(seq_len(n_hh), size), , drop = FALSE]
  rownames(persons) <- NULL

  ok(sae_survey_unit(NULL) == "household" && sae_survey_unit("Person") == "person" &&
       sae_survey_unit("other") == "household", "survey unit defaults to household")
  ok(identical(sae_check_survey_unit(hh, "household")$status, "ok"),
     "household file declared as households passes")
  chk <- sae_check_survey_unit(persons, "household")
  ok(identical(chk$status, "error") && grepl("one row per person", chk$message, fixed = TRUE),
     "person file declared as households is an error")
  ok(identical(sae_check_survey_unit(persons, "person")$status, "ok"),
     "person file declared as persons passes")
  hh_as_person <- hh
  hh_as_person$hh_size <- 1
  ok(identical(sae_check_survey_unit(hh_as_person, "person")$status, "warning"),
     "household file declared as persons is a warning, even with household size set to 1")
  odd <- hh
  odd <- rbind(odd, odd[1:10, ])
  ok(identical(sae_check_survey_unit(odd, "household")$status, "warning"),
     "duplicated household rows that do not match household size are a warning")
  no_id <- hh[, setdiff(names(hh), "hh_id")]
  ok(identical(sae_check_survey_unit(no_id, "household")$status, "ok"),
     "no household ID means no row-type check")

  # Person rows: household size 1, so population_weight = weight.
  out <- NULL
  txt <- capture.output(out <- sae_apply_survey_unit(persons, "person", "test"))
  ok(all(out$hh_size == 1) && any(grepl("Survey rows are persons", txt)),
     "person rows set household size to 1")
  ok(identical(sae_apply_survey_unit(hh, "household"), hh), "household rows are unchanged")
  ok(identical(sae_unit_rename_cols(list(hh_size = "hhs", hh_id = "id"), c("hhs", "id"), "person"),
               c(hh_id = "id")) &&
       identical(sae_unit_rename_cols(list(hh_size = "hhs", hh_id = ""), c("hhs"), "household"),
                 c(hh_size = "hhs")),
     "rename map uses household size only for household rows")

  # Weighted totals: the person file analysed as households inflates the
  # population by the average household size (each person counted size times).
  m_wrong <- sae_readiness_unit_messages(persons, "household", 2022L)
  m_right <- sae_readiness_unit_messages(sae_apply_survey_unit(persons, "person"), "person", 2022L)
  ok(any(grepl("^Test 0f: ERROR --", m_wrong)) &&
       any(grepl(format(sum(persons$weight * persons$hh_size), big.mark = ","), m_wrong, fixed = TRUE)),
     "readiness reports the inflated total and blocks the run")
  ok(!any(grepl("ERROR", m_right)) &&
       any(grepl(format(sum(persons$weight), big.mark = ","), m_right, fixed = TRUE)) &&
       isTRUE(all.equal(sum(persons$weight), sum(hh$weight * hh$hh_size))),
     "person rows give the same population as household rows times household size")
  ok(any(grepl("No household ID is mapped", sae_readiness_unit_messages(no_id, "household"), fixed = TRUE)),
     "readiness notes when no household ID is mapped")

  # Benchmark groups: one domain coded in two groups in one year.
  s <- data.frame(year = rep(c(2021L, 2022L), each = 30),
                  domain = rep(c("A1", "A2", "B1"), 20),
                  region = rep(c("A", "A", "B"), 20), stringsAsFactors = FALSE)
  ok(nrow(sae_benchmark_group_conflicts(s)) == 0L &&
       grepl("^Test 0g: Each domain belongs", sae_readiness_benchmark_group_messages(s, "NUTS2 group")),
     "consistent benchmark groups pass")
  bad <- s
  bad$region[bad$year == 2022L & bad$domain == "B1"][1] <- "A"
  conf <- sae_benchmark_group_conflicts(bad)
  ok(nrow(conf) == 3L && all(conf$domain == "B1") &&
       identical(sort(unique(conf$group)), c("A", "B")),
     "conflicts list the domain, both groups and the years")
  msg <- sae_benchmark_group_message(conf, "NUTS2 group")
  ok(grepl("B1 in B (2021: 10 rows, 2022: 9 rows) and A (2022: 1 row)", msg, fixed = TRUE) &&
       grepl("national benchmarking", msg, fixed = TRUE),
     "conflict message names the codes, years and row counts")
  ok(grepl("^Test 0g: ERROR --", sae_readiness_benchmark_group_messages(bad, "NUTS2 group")),
     "readiness blocks a benchmark-group conflict")
  ok(!grepl("ERROR", sae_readiness_benchmark_group_messages(bad, "NUTS2 group", years = 2021L)),
     "conflicts outside the analysis years are not reported")
  ok(inherits(try(sae_stop_on_benchmark_group_conflicts(bad, "NUTS2 group", "UFH"), silent = TRUE),
              "try-error") && isTRUE(sae_stop_on_benchmark_group_conflicts(s)),
     "the pipelines stop on a conflict")

  na_g <- s
  na_g$region[na_g$domain == "A1"][1] <- NA
  ok(grepl("A1 in A (2021: 9 rows, 2022: 10 rows) and (missing) (2021: 1 row)",
           sae_benchmark_group_message(sae_benchmark_group_conflicts(na_g), "group"), fixed = TRUE),
     "a missing group code is reported as its own value")
  many <- data.frame(year = 2022L, domain = rep(sprintf("D%02d", 1:10), each = 10),
                     region = as.character(1:100), stringsAsFactors = FALSE)
  m2 <- sae_benchmark_group_message(sae_benchmark_group_conflicts(many), "group")
  ok(grepl("and 5 more domain(s)", m2, fixed = TRUE) && grepl("and 6 other values", m2, fixed = TRUE) &&
       nchar(m2) < 1500L,
     "long conflict lists are shortened")
  fy <- bad
  fy$year <- factor(fy$year)
  ok(grepl("^Test 0g: ERROR", sae_readiness_benchmark_group_messages(fy, "group", years = 2022L)) &&
       !grepl("ERROR", sae_readiness_benchmark_group_messages(fy, "group", years = 2021L)),
     "years stored as a factor are matched by value")

  # A configuration file is untrusted: damaged parts are dropped, not fatal.
  env <- new.env()
  env$`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
  wanted <- c("dashboard_setup_defaults", "sae_sanitize_setup")
  for (e in Filter(function(x) is.call(x) && identical(x[[1]], as.name("<-")) &&
                     as.character(x[[2]]) %in% wanted, parse("app.R", encoding = "UTF-8"))) {
    eval(e, env)
  }
  ok(is.null(env$sae_sanitize_setup(list(a = 1))) && is.null(env$sae_sanitize_setup("text")) &&
       is.null(env$sae_sanitize_setup(list(inputs = "x"))),
     "a file without an inputs section is not a configuration")
  bad_cfg <- list(saved_at = c("a", "b"), data_files = "none",
                  inputs = list(years = "2019,2022", steps = c("UFH", "MFH"),
                                survey_unit = list(1, 2), analysis_seed = c(1, 2),
                                unknown_key = "x"))
  clean <- env$sae_sanitize_setup(bad_cfg)
  ok(is.null(clean$saved_at) && length(clean$data_files) == 0L &&
       identical(clean$inputs$years, "2019,2022") && identical(clean$inputs$steps, c("UFH", "MFH")) &&
       is.null(clean$inputs$survey_unit) && is.null(clean$inputs$analysis_seed) &&
       is.null(clean$inputs$unknown_key),
     "malformed configuration values are dropped and valid ones kept")

  # Logs show names and types, never values.
  secret <- data.frame(id = "SECRET-123", income = 98765.4321, stringsAsFactors = FALSE)
  out <- capture.output(sae_log_data_overview(secret, "Survey"))
  ok(any(grepl("Survey: 1 rows, 2 columns", out, fixed = TRUE)) &&
       any(grepl("id <character>", out, fixed = TRUE)) &&
       !any(grepl("SECRET|98765", out)),
     "data overview prints names and types without record values")
  for (src in c("scripts/01_ufh.R", "scripts/02_mfh.R")) {
    code <- readLines(src, warn = FALSE)
    ok(!any(grepl("glimpse\\(", code)) &&
         any(grepl("sae_stop_on_benchmark_group_conflicts(", code, fixed = TRUE)) &&
         any(grepl("sae_check_survey_unit(", code, fixed = TRUE)),
       paste(src, "uses the w5o checks and logs no record values"))
  }
  cat(sprintf("All %d survey-unit and benchmark-group checks passed.\n", checks))
})
