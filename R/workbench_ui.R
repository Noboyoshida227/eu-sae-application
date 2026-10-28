# Shared interface helpers for the EU SAE Workbench (w5o): the application
# name, links to the guides, the About dialog, opening files and
# folders on the user's computer, and the model-run progress/result panel.
# Used by app.R (classic dashboard) and app_wizard.R (guided steps).

SAE_APP_NAME <- "EU SAE Workbench"
SAE_APP_TAGLINE <- "Small area estimation of poverty and welfare"

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x) || length(x) == 0) y else x
}

# ---- Static files: guides and optional logos --------------------------------
# The docs folder is served under /eusae-docs so the guides open from the app;
# logos dropped into www/logos/ (PNG, SVG or JPG) appear on the front page and
# in the About dialog. No logos are shipped yet.
sae_register_static_paths <- function(app_dir) {
  docs <- file.path(app_dir, "docs")
  if (dir.exists(docs)) shiny::addResourcePath("eusae-docs", docs)
  www <- file.path(app_dir, "www")
  if (dir.exists(www)) shiny::addResourcePath("eusae-www", www)
  invisible(TRUE)
}

sae_logo_files <- function(app_dir) {
  dir <- file.path(app_dir, "www", "logos")
  if (!dir.exists(dir)) return(character())
  sort(list.files(dir, pattern = "\\.(png|svg|jpe?g)$", ignore.case = TRUE))
}

sae_logo_strip <- function(app_dir, height = 40) {
  files <- sae_logo_files(app_dir)
  if (!length(files)) return(NULL)
  htmltools::tags$div(
    class = "sae-logos",
    lapply(files, function(f) htmltools::tags$img(
      src = paste0("eusae-www/logos/", utils::URLencode(f)),
      alt = tools::file_path_sans_ext(f), height = height,
      style = "margin: 0 14px 0 0;"))
  )
}

# Sort key that compares the numbers inside file names as numbers, so
# "..._5_14.pdf" sorts after "..._5_9.pdf".
sae_natural_key <- function(x) {
  vapply(x, function(s) {
    m <- gregexpr("[0-9]+", s)[[1]]
    if (m[1] < 0) return(s)
    nums <- regmatches(s, list(m))[[1]]
    regmatches(s, list(m)) <- list(formatC(as.numeric(nums), width = 9, flag = "0", format = "d"))
    s
  }, character(1), USE.NAMES = FALSE)
}

# The shared catalogue selects the current packaged guides. Each entry is
# list(label, href, note); only files that exist are listed.
sae_resource_links <- function(app_dir) {
  catalogue <- file.path(app_dir, "docs", "maintenance", "navigation.json")
  if (!file.exists(catalogue)) return(list())
  data <- jsonlite::fromJSON(catalogue, simplifyVector = FALSE)
  items <- Filter(function(x) isTRUE(x$menu), data$items)
  links <- list()
  if (file.exists(file.path(app_dir, "docs", "INDEX.html"))) {
    links <- list(list(label = "Start here, guides and results",
                       href = "eusae-docs/INDEX.html", note = "", group = ""))
  }
  groups <- c(instructions = "", guidance = "Methods", validation = "Validation",
              maintenance = "Maintainers")
  for (item in items) {
    path <- item$path
    if (!is.character(path) || length(path) != 1L || !startsWith(path, "docs/") ||
        grepl("(^|/)\\.\\.(/|$)", path)) next
    if (grepl("\\.md$", path)) path <- sub("\\.md$", ".html", path)
    if (!file.exists(file.path(app_dir, path))) next
    group <- if (identical(item$group, "instructions")) item$language else groups[[item$group]]
    links[[length(links) + 1L]] <- list(
      label = item$title,
      href = paste0("eusae-docs/", utils::URLencode(sub("^docs/", "", path))),
      note = if (grepl("\\.pdf$", path)) "PDF" else "",
      group = group %||% "")
  }
  order <- match(vapply(links, function(x) x$group, character(1)),
                 c("", "English", "Polish", "Greek", "Methods", "Validation", "Maintainers"))
  links[base::order(order, seq_along(links), na.last = TRUE)]
}
sae_resource_menu <- function(app_dir, button_class = "btn btn-default btn-sm") {
  links <- sae_resource_links(app_dir)
  htmltools::tags$div(
    class = "btn-group sae-resources",
    htmltools::tags$button(
      type = "button", class = paste(button_class, "dropdown-toggle"),
      `data-toggle` = "dropdown", `aria-haspopup` = "true", `aria-expanded` = "false",
      "Guides and notes ", htmltools::tags$span(class = "caret")),
    htmltools::tags$ul(
      class = "dropdown-menu dropdown-menu-right",
      if (!length(links)) htmltools::tags$li(class = "disabled", htmltools::tags$a("No guides found in docs/")),
      sae_resource_items(links)
    )
  )
}

# Menu entries, with a heading before each language group (Polish, Greek)
# and a divider before the documents that follow them.
sae_resource_items <- function(links) {
  out <- list()
  prev <- ""
  for (l in links) {
    g <- l$group %||% ""
    if (!identical(g, prev)) {
      if (nzchar(g)) {
        out[[length(out) + 1L]] <- htmltools::tags$li(role = "separator", class = "divider")
        out[[length(out) + 1L]] <- htmltools::tags$li(class = "dropdown-header", g)
      } else {
        out[[length(out) + 1L]] <- htmltools::tags$li(role = "separator", class = "divider")
      }
      prev <- g
    }
    out[[length(out) + 1L]] <- htmltools::tags$li(htmltools::tags$a(
      href = l$href, target = "_blank", rel = "noopener",
      l$label,
      if (nzchar(l$note)) htmltools::tags$span(class = "sae-res-note", paste0(" (", l$note, ")"))
    ))
  }
  out
}

# ---- About ----------------------------------------------------------------
# Version shown to users: the wizard release version (WIZARD_VERSION, else
# VERSION) and the release name.
sae_display_version <- function(app_dir) {
  first_line <- function(f) {
    p <- file.path(app_dir, f)
    if (!file.exists(p)) return("")
    trimws(readLines(p, n = 1L, warn = FALSE, encoding = "UTF-8")[1] %||% "")
  }
  v <- first_line("WIZARD_VERSION")
  if (!nzchar(v)) v <- first_line("VERSION")
  rel <- first_line("RELEASE_NAME")
  if (nzchar(rel) && nzchar(v)) paste0(v, " (", rel, ")") else v
}

sae_about_dialog <- function(app_dir, version = sae_display_version(app_dir)) {
  shiny::modalDialog(
    title = paste("About", SAE_APP_NAME),
    easyClose = TRUE, size = "m",
    footer = shiny::modalButton("Close"),
    sae_logo_strip(app_dir, height = 44),
    htmltools::tags$p(htmltools::tags$strong(SAE_APP_NAME), paste0(" \u2014 ", SAE_APP_TAGLINE, "."),
                      if (nzchar(version)) paste0(" Version ", version, ".")),
    htmltools::tags$p("Estimates poverty and mean welfare for small areas with univariate and multivariate Fay\u2013Herriot models, compares two years, and reports uncertainty, diagnostics and benchmarked estimates."),
    # No contributor credits until the review meeting (owner, 13 Oct 2026).
    htmltools::tags$p("Methods: Fay\u2013Herriot area-level models; multivariate models for comparable estimates over time (Molina and Romero, 2025). Software licences: see THIRD_PARTY_NOTICES.md. Map boundaries are attributed under each map in the report."),
    htmltools::tags$p(class = "help-block",
      "Whether to publish estimates as official statistics is for each national statistical office to decide.")
  )
}

# ---- Opening files and folders on the user's computer --------------------
# The app runs locally, so the R process can ask the operating system to open
# a report, a folder or a file with its default program.
sae_open_path <- function(path) {
  if (is.null(path) || !nzchar(path %||% "") || !file.exists(path)) {
    stop("Not found: ", path %||% "(none)", call. = FALSE)
  }
  path <- normalizePath(path, winslash = "\\", mustWork = TRUE)
  sys <- Sys.info()[["sysname"]]
  if (.Platform$OS.type == "windows") {
    shell.exec(path)
  } else if (identical(sys, "Darwin")) {
    system2("open", shQuote(path), wait = FALSE)
  } else {
    system2("xdg-open", shQuote(path), wait = FALSE, stdout = FALSE, stderr = FALSE)
  }
  invisible(path)
}

# ---- Model-run progress and result panel ----------------------------------
# `st` is a list with state ("idle", "running", "finished", "failed",
# "stopped"), stages, current, started_at, finished_at, run_dir, report_path,
# config_path, report_missing, report_reason and error. Buttons inside the
# panel are open_report_btn, open_outputs_btn, view_config_btn and
# open_run_folder_btn (handled in app.R).
sae_run_panel_ui <- function(st) {
  tags <- htmltools::tags
  state <- st$state %||% "idle"
  if (identical(state, "idle")) {
    return(tags$div(class = "sae-run-panel sae-run-idle",
                    "No model run has been started in this session."))
  }
  stages <- as.character(st$stages %||% character())
  current <- st$current %||% ""
  pos <- match(current, stages)
  if (is.na(pos)) pos <- 0L
  stage_items <- lapply(seq_along(stages), function(i) {
    cls <- if (identical(state, "finished") || i < pos) "done"
           else if (i == pos && identical(state, "running")) "current"
           else if (i == pos) "stopped" else "todo"
    mark <- switch(cls, done = "\u2713", current = "\u25cf", stopped = "\u25a0", "\u25cb")
    tags$li(class = paste("sae-stage", cls), tags$span(class = "sae-stage-mark", mark), stages[i])
  })
  pct <- if (identical(state, "finished")) 100 else if (length(stages)) round(100 * max(pos - 1, 0) / length(stages)) else 0
  started <- if (!is.null(st$started_at)) format(st$started_at, "%H:%M:%S") else ""
  head <- switch(state,
    running  = tags$div(class = "sae-run-head running",
                        sprintf("Model run in progress: %s", if (nzchar(current)) current else "starting"),
                        if (nzchar(started)) tags$span(class = "sae-run-time", paste("started", started))),
    finished = if (isTRUE(st$report_missing)) {
                 tags$div(class = "sae-run-head warn", "Model run completed, but the report could not be created",
                          if (nzchar(st$report_reason %||% "")) tags$div(class = "sae-run-detail", st$report_reason))
               } else tags$div(class = "sae-run-head ok", "Model run completed successfully"),
    failed   = tags$div(class = "sae-run-head fail", "Model run failed",
                        if (nzchar(st$error %||% "")) tags$div(class = "sae-run-detail", st$error),
                        tags$div(class = "sae-run-detail", "The run log below has the details.")),
    stopped  = tags$div(class = "sae-run-head stopped", "Model run stopped"),
    tags$div(class = "sae-run-head", state)
  )
  buttons <- list()
  if (identical(state, "finished")) {
    if (!is.null(st$report_path) && file.exists(st$report_path)) {
      buttons <- c(buttons, list(shiny::actionButton("open_report_btn", "Open the report", class = "btn-primary")))
    }
    buttons <- c(buttons, list(shiny::actionButton("open_outputs_btn", "Open the output folder", class = "btn-default")))
  }
  if (state %in% c("failed", "stopped") && !is.null(st$run_dir)) {
    buttons <- c(buttons, list(shiny::actionButton("open_run_folder_btn", "Open the run folder", class = "btn-default")))
  }
  if (!identical(state, "running") && !is.null(st$config_path) && file.exists(st$config_path)) {
    buttons <- c(buttons, list(shiny::actionButton("view_config_btn", "View the configuration", class = "btn-default")))
  }
  tags$div(
    class = paste("sae-run-panel", paste0("sae-run-", state)),
    head,
    if (identical(state, "running") || length(stages)) tags$div(
      class = "progress sae-run-progress",
      tags$div(class = paste("progress-bar", if (identical(state, "running")) "progress-bar-striped active" else ""),
               role = "progressbar", style = sprintf("width: %d%%;", as.integer(pct)),
               `aria-valuenow` = pct, `aria-valuemin` = 0, `aria-valuemax` = 100,
               sprintf("%d%%", as.integer(pct)))),
    if (length(stages)) tags$ol(class = "sae-stages", stage_items),
    if (length(buttons)) tags$div(class = "sae-run-buttons", buttons),
    if (!is.null(st$run_dir) && !identical(state, "running"))
      tags$div(class = "sae-run-folder", "Run folder: ", tags$code(st$run_dir))
  )
}

sae_run_panel_css <- "
.sae-run-panel { border: 1px solid #d5dde8; border-radius: 10px; padding: 14px 16px; margin: 10px 0 16px; background: #fff; }
.sae-run-idle { color: #4a5875; background: #f7f9fc; }
.sae-run-head { font-size: 1.12em; font-weight: 700; margin-bottom: 10px; color: #16233d; }
.sae-run-head.ok { color: #1b5e20; }
.sae-run-head.warn { color: #7a4f00; }
.sae-run-head.fail { color: #a10e1a; }
.sae-run-head.stopped { color: #4a5875; }
.sae-run-head .sae-run-time { font-weight: 400; font-size: 0.82em; color: #4a5875; margin-left: 10px; }
.sae-run-detail { font-weight: 400; font-size: 0.9em; color: #3a4660; margin-top: 4px; white-space: pre-wrap; }
.sae-run-panel.sae-run-finished { border-color: #9fd3a8; background: #f4fbf5; }
.sae-run-panel.sae-run-failed { border-color: #f0a8ae; background: #fff6f6; }
.sae-run-progress { height: 22px; margin: 6px 0 12px; }
.sae-run-progress .progress-bar { line-height: 22px; font-weight: 600; }
.sae-stages { list-style: none; padding: 0; margin: 0 0 10px; display: flex; flex-wrap: wrap; gap: 8px 18px; }
.sae-stage { color: #6a7792; }
.sae-stage .sae-stage-mark { display: inline-block; width: 1.2em; }
.sae-stage.done { color: #1b5e20; }
.sae-stage.current { color: #1e4d8f; font-weight: 700; }
.sae-stage.stopped { color: #a10e1a; font-weight: 700; }
.sae-run-buttons { display: flex; gap: 10px; flex-wrap: wrap; margin: 6px 0 8px; }
.sae-run-folder { font-size: 0.9em; color: #4a5875; }
.sae-res-note { color: #6a7792; font-size: 0.9em; }
"
