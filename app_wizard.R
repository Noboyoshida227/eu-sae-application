# =====================================================================
#  app_wizard.R -- Guided ("wizard") front end of the EU SAE Workbench.
#
#  WHAT THIS IS
#  ------------
#  The classic dashboard (app.R) presents every setting at once in a
#  single long sidebar. This file presents exactly the same settings
#  as seven sequential steps (w5o):
#
#      1. Input data  ->  2. Map variables  ->  3. Configure analysis
#      ->  4. Configure model  ->  5. Add AI assistant (optional)
#      ->  6. Review configuration  ->  7. Run model
#
#  Step 6 holds the configuration summary and "Check data readiness";
#  step 7 starts the run and shows its progress and result (report,
#  output folder, configuration file).
#
#  HOW IT REUSES app.R
#  -------------------
#  This file does NOT duplicate the pipeline. At launch it parses app.R,
#  evaluates every top-level definition EXCEPT the old `ui` object and
#  the launcher block, and then reuses app.R's `server()` function
#  verbatim. Every input ID is preserved, so all of app.R's server logic
#  works unchanged. Fixes made to app.R are inherited automatically.
#  tools/check_ui_parity.R checks that every app.R input/output ID also
#  exists here exactly once.
#
#  KEY DESIGN CONSTRAINT
#  ---------------------
#  The steps are built with tabsetPanel(type = "hidden"). Hidden tab
#  panels remain in the DOM, so an input on step 2 still exists and holds
#  its value while the user is looking at step 5. Rebuilding steps with
#  renderUI/uiOutput would set every off-screen input to NULL and
#  silently break the pipeline. Do not change this.
#
#  GATING
#  ------
#  Gating is deliberately "soft": Next and the breadcrumb are always
#  clickable. Incomplete steps show an amber notice and an amber chip.
#  Only "Run model" on step 7 is genuinely blocked (missing data files);
#  app.R's own run handler also asks for a data readiness check first.
#
#  LAUNCH
#  ------
#      shiny::runApp("app_wizard.R", launch.browser = TRUE)
#  or double-click Start_Here/Start_Wizard.bat
# =====================================================================

library(shiny)

# ---------------------------------------------------------------------
# 1. Load app.R's globals and server() without launching it
# ---------------------------------------------------------------------

# app.R self-launches when run non-interactively. This guard stops that.
Sys.setenv(EU_SAE_APP_LAUNCHED = "1")

.wiz_app_dir <- tryCatch(
  {
    ofiles <- vapply(
      sys.frames(),
      function(env) {
        of <- env$ofile
        if (is.null(of) || length(of) == 0) "" else as.character(of)[1]
      },
      character(1)
    )
    ofiles <- ofiles[nzchar(ofiles)]
    if (length(ofiles) > 0) {
      dirname(normalizePath(tail(ofiles, 1), winslash = "/", mustWork = TRUE))
    } else {
      normalizePath(getwd(), winslash = "/", mustWork = TRUE)
    }
  },
  error = function(e) normalizePath(getwd(), winslash = "/", mustWork = FALSE)
)

.wiz_core <- file.path(.wiz_app_dir, "app.R")
if (!file.exists(.wiz_core)) {
  stop(
    "app_wizard.R must sit in the same folder as app.R. Looked for: ",
    .wiz_core,
    call. = FALSE
  )
}

# Parse app.R and evaluate everything except the pieces that build or
# launch the classic single-page UI.
.wiz_exprs <- parse(.wiz_core, keep.source = FALSE)

.wiz_should_keep <- function(e) {
  if (!is.call(e)) return(TRUE)
  head_sym <- as.character(e[[1]])[1]

  # Drop `ui <- ...`, `.app <- shinyApp(...)`, and the launcher helper.
  if (head_sym %in% c("<-", "=", "<<-") && length(e) >= 2) {
    target <- tryCatch(as.character(e[[2]])[1], error = function(err) "")
    if (target %in% c("ui", ".app", ".run_app_with_port_fallback")) {
      return(FALSE)
    }
  }

  # Drop the trailing auto-launch block.
  if (identical(head_sym, "if")) {
    txt <- paste(deparse(e), collapse = " ")
    if (grepl("EU_SAE_APP_LAUNCHED", txt, fixed = TRUE)) return(FALSE)
  }

  TRUE
}

.wiz_kept <- vapply(as.list(.wiz_exprs), .wiz_should_keep, logical(1))
for (.e in as.list(.wiz_exprs)[.wiz_kept]) {
  eval(.e, envir = globalenv())
}
rm(.e)

if (!exists("server", mode = "function")) {
  stop("Could not load server() from app.R.", call. = FALSE)
}
.wiz_core_server <- get("server", mode = "function")

# Serve www/ under an explicit prefix so static assets resolve however
# the app is launched (runApp on a file, on a directory, or via a
# shinyApp object).
shiny::addResourcePath("wizassets", file.path(.wiz_app_dir, "www"))

# ---------------------------------------------------------------------
# 2. Wizard step definitions
# ---------------------------------------------------------------------

WIZ_STEPS <- list(
  list(id = "data",     num = 1L, short = "Input data",           title = "Step 1 - Input data"),
  list(id = "mapping",  num = 2L, short = "Map variables",        title = "Step 2 - Map variables"),
  list(id = "analysis", num = 3L, short = "Configure analysis",   title = "Step 3 - Configure analysis"),
  list(id = "models",   num = 4L, short = "Configure model",      title = "Step 4 - Configure model"),
  list(id = "ai",       num = 5L, short = "Add AI assistant",     title = "Step 5 - Add AI assistant (optional)"),
  list(id = "review",   num = 6L, short = "Review configuration", title = "Step 6 - Review configuration"),
  list(id = "run",      num = 7L, short = "Run model",            title = "Step 7 - Run model")
)
WIZ_IDS <- vapply(WIZ_STEPS, function(s) s$id, character(1))

# Small helpers used only by the wizard chrome -------------------------

# Label text followed by a red asterisk marking a required field.
wiz_req <- function(text) {
  tagList(text, tags$span(class = "wiz-req", title = "Required", "*"))
}

wiz_step_header <- function(step) {
  tags$div(
    class = "wiz-step-header",
    tags$div(class = "wiz-step-num", sprintf("%d", step$num)),
    tags$div(
      tags$h3(step$title),
      tags$div(class = "wiz-step-sub", uiOutput(paste0("wiz_sub_", step$id), inline = TRUE))
    )
  )
}

wiz_nav <- function(step_id) {
  idx <- match(step_id, WIZ_IDS)
  tags$div(
    class = "wiz-nav",
    if (idx > 1) {
      actionButton(paste0("wiz_back_", step_id), "< Back", class = "btn-default")
    } else {
      tags$span()
    },
    tags$div(class = "wiz-nav-spacer"),
    if (idx < length(WIZ_IDS)) {
      actionButton(paste0("wiz_next_", step_id), "Next >", class = "btn-primary")
    } else {
      tags$span()
    }
  )
}

# A step body: header, amber issue notice, content, nav bar.
wiz_panel <- function(step_id, ...) {
  step <- WIZ_STEPS[[match(step_id, WIZ_IDS)]]
  tabPanel(
    step_id,
    tags$div(
      class = "wiz-step",
      wiz_step_header(step),
      uiOutput(paste0("wiz_issues_", step_id)),
      tags$div(class = "wiz-step-body", ...),
      wiz_nav(step_id)
    )
  )
}

# ---------------------------------------------------------------------
# 3. Shared head: JS handlers + CSS lifted verbatim from app.R, with
#    the wizard chrome appended to the same style block, plus a few
#    extra JS message handlers used only by the wizard.
# ---------------------------------------------------------------------

wiz_head <- tags$head(
    tags$script(HTML("
      Shiny.addCustomMessageHandler('fadeTransition', function(msg) {
        var hide = document.getElementById(msg.hide);
        var show = document.getElementById(msg.show);
        hide.style.transition = 'opacity 0.45s ease';
        hide.style.opacity = '0';
        setTimeout(function(){
          hide.style.display = 'none';
          hide.style.opacity = '1';
          show.style.opacity = '0';
          show.style.display = (show.id === 'main_app') ? 'block' : 'flex';
          show.style.transition = 'opacity 0.45s ease';
          setTimeout(function(){ show.style.opacity = '1'; }, 30);
          // Tell Shiny the outputs inside are now visible, so they render.
          $(show).trigger('shown');
        }, 450);
      });
      Shiny.addCustomMessageHandler('mappingValidity', function(msg) {
        var group = $('#' + msg.id).closest('.form-group');
        if (!group.length) return;
        if (msg.invalid) {
          group.addClass('mapping-invalid');
          group.attr('title', msg.message || 'Column not found in selected dataset');
        } else {
          group.removeClass('mapping-invalid');
          group.removeAttr('title');
        }
      });
      Shiny.addCustomMessageHandler('clearFileInput', function(id) {
        var input = document.getElementById(id);
        if (input) {
          input.value = '';
          $(input).trigger('change');
        }
        var group = $('#' + id).closest('.form-group');
        group.find('.file-caption-name').attr('title', '').text('No file selected');
        group.find('input[type=text]').val('');
      });
    ")),
    tags$style(HTML("
    #main_app { display: none; }
    #main_app.visible { display: block; }

    /* ---- Tooltips ---- */
    .tt-wrap {
      position: relative;
      display: inline;
    }
    .tt-wrap .tt-icon {
      display: inline-block;
      width: 15px; height: 15px;
      line-height: 15px;
      text-align: center;
      font-size: 10px; font-weight: 700;
      color: #fff;
      background: #6b8db5;
      border-radius: 50%;
      cursor: help;
      margin-left: 3px;
      vertical-align: middle;
    }
    .tt-wrap .tt-text {
      visibility: hidden;
      opacity: 0;
      position: absolute;
      z-index: 1000;
      left: 0; top: 1.6em;
      width: 300px;
      background: #1a2a4a;
      color: #e0ecf8;
      padding: 10px 14px;
      border-radius: 8px;
      font-size: 0.85em;
      font-weight: 400;
      line-height: 1.5;
      box-shadow: 0 4px 20px rgba(0,0,0,0.3);
      border: 1px solid rgba(109,213,237,0.25);
      transition: opacity 0.2s ease, visibility 0.2s ease;
      pointer-events: none;
    }
    .tt-wrap:hover .tt-text {
      visibility: visible;
      opacity: 1;
    }
    .form-group.mapping-invalid label {
      color: #b00020;
    }
    .form-group.mapping-invalid .selectize-input {
      border-color: #b00020 !important;
      box-shadow: 0 0 0 2px rgba(176,0,32,0.12) !important;
    }
    .form-group.mapping-invalid .selectize-input.focus {
      border-color: #b00020 !important;
      box-shadow: 0 0 0 3px rgba(176,0,32,0.18) !important;
    }
    .mapping-validation-summary {
      color: #8a1f11;
      background: #fff3f1;
      border: 1px solid #f1b8b0;
      border-radius: 6px;
      padding: 8px 10px;
      font-size: 12px;
      margin: 4px 0 12px 0;
    }
    .benchmark-format-note {
      color: #445;
      background: #f7f9fc;
      border: 1px solid #d9e2ef;
      border-radius: 6px;
      padding: 10px 12px;
      font-size: 12px;
      line-height: 1.45;
      margin: -4px 0 12px 0;
    }
    .benchmark-format-note .note-title {
      font-weight: 600;
      color: #24324a;
      margin-bottom: 4px;
    }
    .benchmark-format-note p {
      margin: 0 0 6px 0;
    }
    .benchmark-format-note ul {
      margin: 0;
      padding-left: 18px;
    }
    .benchmark-clear-row {
      margin: 2px 0 8px 0;
    }

    /* ================= Wizard chrome ================= */
    /* Shiny hides hidden-type tab navs itself; belt and braces. */
    .nav-hidden { display: none !important; }
    body { background: #f4f6fa; }
    #main_app .container-fluid { max-width: 1180px; }

    .wiz-topbar {
      display: flex; align-items: center; justify-content: space-between;
      flex-wrap: wrap; gap: 10px;
      padding: 12px 18px; margin: 0 0 14px 0;
      background: linear-gradient(135deg, #14264d 0%, #1e4d8f 100%);
      border-radius: 10px; color: #eaf2fb;
      box-shadow: 0 2px 10px rgba(20,38,77,0.18);
    }
    .wiz-topbar .wiz-title {
      font-size: 1.15em; font-weight: 600; letter-spacing: 0.2px;
    }
    .wiz-topbar .wiz-title small {
      display: block; font-size: 0.62em; font-weight: 400;
      color: rgba(200,222,247,0.75); letter-spacing: 0.4px;
    }
    .wiz-topbar .btn { margin-left: 6px; }

    /* ---- Breadcrumb ---- */
    .wiz-crumbs {
      display: flex; flex-wrap: wrap; gap: 8px;
      margin: 0 0 18px 0;
    }
    .wiz-crumb {
      display: inline-flex; align-items: center; gap: 7px;
      padding: 7px 14px 7px 9px;
      border-radius: 40px; border: 1px solid #d5dde8;
      background: #fff; color: #46536b;
      font-size: 0.85em; font-weight: 500;
      text-decoration: none !important; cursor: pointer;
      transition: all 0.18s ease;
      box-shadow: 0 1px 2px rgba(20,38,77,0.05);
    }
    .wiz-crumb:hover {
      border-color: #9db8d8; color: #1e4d8f;
      transform: translateY(-1px);
      box-shadow: 0 3px 8px rgba(20,38,77,0.1);
    }
    .wiz-crumb .wiz-dot {
      display: inline-flex; align-items: center; justify-content: center;
      width: 21px; height: 21px; border-radius: 50%;
      font-size: 0.78em; font-weight: 700; color: #fff;
      background: #b9c4d4; flex: 0 0 21px;
    }
    .wiz-crumb.done { border-color: #b6dfc0; background: #f2fbf4; color: #22683a; }
    .wiz-crumb.done .wiz-dot { background: #2e7d32; }
    .wiz-crumb.todo { border-color: #f0d8a8; background: #fffaf0; color: #8a5a00; }
    .wiz-crumb.todo .wiz-dot { background: #d99b16; }
    .wiz-crumb.current {
      border-color: #1e4d8f; background: #1e4d8f; color: #fff;
      box-shadow: 0 3px 10px rgba(30,77,143,0.28);
    }
    .wiz-crumb.current .wiz-dot { background: rgba(255,255,255,0.28); color: #fff; }

    /* ---- Step card ---- */
    .wiz-step {
      background: #fff; border: 1px solid #e2e8f1; border-radius: 12px;
      padding: 22px 26px 18px; margin-bottom: 18px;
      box-shadow: 0 2px 14px rgba(20,38,77,0.06);
    }
    .wiz-step-header { display: flex; align-items: flex-start; gap: 14px; margin-bottom: 6px; }
    .wiz-step-header h3 { margin: 0 0 2px 0; font-size: 1.28em; font-weight: 600; color: #16233d; }
    .wiz-step-num {
      flex: 0 0 38px; width: 38px; height: 38px; border-radius: 50%;
      background: linear-gradient(135deg, #1e4d8f, #2a6cb0); color: #fff;
      display: flex; align-items: center; justify-content: center;
      font-size: 1.05em; font-weight: 700;
    }
    .wiz-step-sub { font-size: 0.95em; color: #3d4a63; line-height: 1.5; }
    .wiz-step-body { margin-top: 16px; }
    .wiz-step-body hr { margin: 18px 0; border-top: 1px solid #eceff4; }
    .wiz-step-body h4 {
      font-size: 0.86em; font-weight: 700; letter-spacing: 0.9px;
      text-transform: uppercase; color: #34425c;
      margin: 22px 0 10px 0;
    }
    .wiz-step-body h4:first-child { margin-top: 0; }

    /* Two-column field grid; collapses on narrow screens */
    .wiz-grid { display: flex; flex-wrap: wrap; gap: 0 28px; }
    .wiz-grid > .wiz-col { flex: 1 1 320px; min-width: 280px; }

    .wiz-note {
      font-size: 12px; color: #55617a; line-height: 1.5;
      background: #f7f9fc; border: 1px solid #e3e9f2;
      border-left: 3px solid #9db8d8;
      border-radius: 6px; padding: 9px 12px; margin: 0 0 14px 0;
    }

    /* ---- Amber issue notice ---- */
    .wiz-issues {
      background: #fffaf0; border: 1px solid #f0d8a8;
      border-left: 3px solid #d99b16;
      border-radius: 6px; padding: 10px 13px; margin: 12px 0 0 0;
      font-size: 0.86em; color: #7d5300;
    }
    .wiz-issues .wiz-issues-title { font-weight: 700; margin-bottom: 4px; }
    .wiz-issues ul { margin: 0; padding-left: 20px; }
    .wiz-issues li { margin: 2px 0; }
    .wiz-ok {
      background: #f2fbf4; border: 1px solid #b6dfc0;
      border-left: 3px solid #2e7d32;
      border-radius: 6px; padding: 9px 13px; margin: 12px 0 0 0;
      font-size: 0.86em; color: #22683a; font-weight: 500;
    }

    /* ---- Nav bar ---- */
    .wiz-nav {
      display: flex; align-items: center;
      margin-top: 22px; padding-top: 16px;
      border-top: 1px solid #eceff4;
    }
    .wiz-nav-spacer { flex: 1 1 auto; }
    .wiz-nav .btn { min-width: 116px; font-weight: 500; }

    /* ---- Step 6 summary table ---- */
    .wiz-summary { width: 100%; font-size: 0.85em; border-collapse: collapse; }
    .wiz-summary th, .wiz-summary td {
      padding: 6px 10px; border-bottom: 1px solid #eef1f6; vertical-align: top;
    }
    .wiz-summary th {
      text-align: left; font-weight: 600; color: #5c6a83;
      width: 42%; white-space: nowrap;
    }
    .wiz-summary td { color: #22314d; }
    .wiz-summary .wiz-sec td {
      padding-top: 14px; font-weight: 700; color: #16233d;
      text-transform: uppercase; font-size: 0.9em; letter-spacing: 0.8px;
      border-bottom: 1px solid #d8dfea;
    }
    .wiz-run-row { display: flex; gap: 12px; flex-wrap: wrap; align-items: flex-end; margin: 6px 0 2px; }
    .wiz-run-row .form-group { margin-bottom: 0; min-width: 260px; }
    .wiz-run-row .btn { min-width: 170px; }

    /* ---- w5o: larger type, required marks and the new layouts ---- */
    body { font-size: 15px; color: #1f2b42; }
    #main_app .control-label, #main_app label { color: #22314d; }
    #main_app .help-block { color: #4a5875; }
    .wiz-req { color: #c62828; font-weight: 700; margin-left: 2px; }
    .wiz-grid-3 > .wiz-col { flex: 1 1 300px; min-width: 260px; }
    .wiz-grid > .wiz-col.wiz-col-wide { flex: 2 1 520px; }
    .wiz-topbar-right { display: flex; align-items: center; gap: 6px; }
    .wiz-topbar .wiz-top-btn {
      background: rgba(255,255,255,0.12); color: #fff;
      border-color: rgba(255,255,255,0.4);
    }
    .wiz-topbar .wiz-top-btn:hover, .wiz-topbar .wiz-top-btn:focus {
      background: rgba(255,255,255,0.24); color: #fff;
    }
    .wiz-topbar .dropdown-menu a { color: #22314d; }
    .wiz-headrow {
      display: flex; align-items: center; justify-content: space-between;
      flex-wrap: wrap; gap: 10px; margin: 2px 0 12px 0;
    }
    .wiz-h2 { font-size: 1.5em; font-weight: 600; color: #16233d; margin: 0; }
    .wiz-config-actions { display: flex; align-items: center; gap: 8px; }
    .wiz-crumb { font-size: 0.88em; }
    .wiz-hidden { display: none; }
    .wiz-years { display: flex; gap: 14px; flex-wrap: wrap; }
    .wiz-years .form-group { flex: 0 1 150px; min-width: 130px; }
    .wiz-years-hint { font-size: 0.9em; color: #3d4a63; margin: -4px 0 14px 0; }
    .wiz-years-hint.warn { color: #8a5a00; }
    .wiz-narrow { max-width: 680px; }
    .wiz-small { font-size: 0.92em; color: #3d4a63; }
    .wiz-ready { font-size: 0.92em; border-radius: 6px; padding: 8px 11px; margin: 0 0 10px 0; }
    .wiz-ready.ok { background: #f2fbf4; border: 1px solid #b6dfc0; color: #22683a; }
    .wiz-ready.todo { background: #fffaf0; border: 1px solid #f0d8a8; color: #7d5300; }
    #wiz_outstanding { display: block; margin-bottom: 16px; }
    .wiz-log { margin-top: 14px; }
    .wiz-log > summary { cursor: pointer; font-weight: 600; color: #1e4d8f; padding: 4px 0; }
    .wiz-step details.benchmark-format-note > summary { cursor: pointer; }
  ")),
  tags$style(HTML(sae_run_panel_css)),
  tags$script(HTML("
    // ---- Wizard chrome handlers (additional to app.R's) ----
    Shiny.addCustomMessageHandler('wizCrumbState', function(msg) {
      for (var i = 0; i < msg.ids.length; i++) {
        var el = document.getElementById(msg.ids[i]);
        if (!el) continue;
        el.classList.remove('done', 'todo', 'current');
        el.classList.add(msg.states[i]);
      }
    });
    Shiny.addCustomMessageHandler('saeToggleBtn', function(msg) {
      var b = document.getElementById(msg.id);
      if (!b) return;
      if (msg.disabled) {
        b.setAttribute('disabled', 'disabled');
        b.classList.add('disabled');
      } else {
        b.removeAttribute('disabled');
        b.classList.remove('disabled');
      }
    });
    Shiny.addCustomMessageHandler('wizToggleBtn', function(msg) {
      var b = document.getElementById(msg.id);
      if (!b) return;
      if (msg.disabled) {
        b.setAttribute('disabled', 'disabled');
        b.classList.add('disabled');
      } else {
        b.removeAttribute('disabled');
        b.classList.remove('disabled');
      }
    });
    Shiny.addCustomMessageHandler('wizScrollTop', function(msg) {
      window.scrollTo({ top: 0, behavior: 'smooth' });
    });
  "))
)

# ---------------------------------------------------------------------
# 4. Wizard UI
#
#    Every widget below is lifted verbatim from app.R's sidebarPanel --
#    same input IDs, same labels, same tooltips, same conditionalPanel
#    conditions -- only regrouped into six steps and laid out in two
#    columns instead of a narrow sidebar.
# ---------------------------------------------------------------------

ui <- fluidPage(
  title = SAE_APP_NAME,
  wiz_head,

  # ---- Shared landing page ----
  sae_landing_page(wizard = TRUE),

  # ---- Main app ----
  div(id = "main_app",

    # Top bar: name, guides and About (w5o) ------------------------------
    tags$div(class = "wiz-topbar",
      tags$div(class = "wiz-title",
        SAE_APP_NAME,
        tags$small(SAE_APP_TAGLINE)
      ),
      tags$div(class = "wiz-topbar-right",
        sae_resource_menu(.wiz_app_dir, button_class = "btn btn-default btn-sm wiz-top-btn"),
        actionButton("about_btn", "About", class = "btn-default btn-sm wiz-top-btn")
      )
    ),

    # Heading row: configuration actions beside the steps (w5o) -----------
    tags$div(class = "wiz-headrow",
      tags$h2(class = "wiz-h2", "Configure your model run"),
      tags$div(class = "wiz-config-actions",
        actionButton("save_setup_btn", "Save configuration", class = "btn-default btn-sm"),
        tags$div(class = "btn-group",
          tags$button(type = "button", class = "btn btn-default btn-sm dropdown-toggle",
                      `data-toggle` = "dropdown", `aria-haspopup` = "true", `aria-expanded` = "false",
                      "Load configuration ", tags$span(class = "caret")),
          tags$ul(class = "dropdown-menu dropdown-menu-right",
            tags$li(actionLink("load_setup_btn", "Last saved configuration")),
            tags$li(actionLink("load_config_file_btn", "From a file\u2026")),
            tags$li(role = "separator", class = "divider"),
            tags$li(actionLink("reset_setup_btn", "Reset to defaults and clear the saved configuration"))
          )
        )
      )
    ),

    # Breadcrumb ----------------------------------------------------
    # Built statically (not via renderUI) so the actionLink input
    # bindings are never torn down and re-created -- rebinding would
    # reset their click counters and fire spurious navigation. Only the
    # CSS classes are updated, via the wizCrumbState message handler.
    tags$div(class = "wiz-crumbs",
      lapply(WIZ_STEPS, function(s) {
        actionLink(
          paste0("wiz_crumb_", s$id),
          label = tagList(tags$span(class = "wiz-dot", as.character(s$num)), s$short),
          class = "wiz-crumb"
        )
      })
    ),

    # Steps ---------------------------------------------------------
    tabsetPanel(
      id = "wizard", type = "hidden",

      # ============================ STEP 1 ============================
      wiz_panel("data",
        tags$div(class = "wiz-note",
          "Select the files from any folder on your computer. Fields marked ",
          tags$span(class = "wiz-req", "*"), " are required. ",
          tip_label("Accepted formats",
            "Survey and auxiliary files: R (.rds, .RData), CSV/TSV/TXT/DAT, Stata, SPSS, SAS, Parquet/Feather or Excel. Geometry: .rds, GeoPackage, GeoJSON, KML/GML, or one .zip with the ESRI shapefile parts (.shp, .shx and .dbf; the .dbf holds the domain ID). After loading a configuration, its files are shown under each Browse button; browse again only to change a file.")
        ),
        tags$div(class = "wiz-grid wiz-grid-3",
          tags$div(class = "wiz-col",
            h4("Survey and auxiliary data"),
            fileInput("survey_file",
              tip_label(wiz_req("Survey data file"), "Choose the household survey file from any folder on your computer. Accepted formats: .rds, .RData/.rda, .csv, .tsv, .txt, .dat, .dta, .sav, .zsav, .por, .sas7bdat, .xpt, .parquet, .feather, .xlsx, .xls."),
              accept = c(".rds", ".RData", ".rda", ".csv", ".tsv", ".txt", ".dat",
                         ".dta", ".sav", ".zsav", ".por", ".sas7bdat", ".xpt",
                         ".parquet", ".feather", ".xlsx", ".xls")),
            uiOutput("survey_active_file"),
            fileInput("rhs_file",
              tip_label(wiz_req("Auxiliary data file"), "Choose the auxiliary covariates file from any folder on your computer. Accepted formats: .rds, .RData/.rda, .csv, .tsv, .txt, .dat, .dta, .sav, .zsav, .por, .sas7bdat, .xpt, .parquet, .feather, .xlsx, .xls."),
              accept = c(".rds", ".RData", ".rda", ".csv", ".tsv", ".txt", ".dat",
                         ".dta", ".sav", ".zsav", ".por", ".sas7bdat", ".xpt",
                         ".parquet", ".feather", ".xlsx", ".xls")),
            uiOutput("rhs_active_file")
          ),
          tags$div(class = "wiz-col",
            h4("Geometry and population"),
            fileInput("shp_file",
              tip_label(wiz_req("Shapefile/geometries file"), "Choose the geometry file from any folder on your computer. For ESRI shapefiles, upload a single .zip containing all shapefile components, especially .shp, .shx, and .dbf. A .shp file alone is usually not enough because the .dbf stores the domain ID used to join estimates to map polygons. Other accepted formats: .rds, .RData/.rda, .gpkg, .geojson, .json, .kml, .gml."),
              accept = c(".rds", ".RData", ".rda", ".zip", ".gpkg", ".geojson", ".json", ".kml", ".gml")),
            uiOutput("shp_active_file")
            ,
            fileInput("population_file",
              tip_label("Domain population sizes (optional)",
                        "Optional RDS/CSV/XLSX file with domain population sizes. Requires one row per domain/year in long format or one row per domain in wide format. Duplicate keys (including sex/age rows) are rejected; supply aggregate population totals. Named matrix columns match years; completely unnamed columns must follow the selected year order. Leave blank to estimate domain populations from the survey as the sum of the population weights (weight * household size when each row is a household, weight when each row is a person).")),
            uiOutput("population_active_file")
          ),
          tags$div(class = "wiz-col",
            h4("Prices (mean welfare only)"),
            fileInput("cpi_file",
              tip_label("Consumer price index (optional)",
                        "Optional file with one country's consumer price index (CPI or HICP) by year, used only for mean welfare in constant prices (see the indicator settings). One row per year: a year column and one or more CPI columns, for example index levels (2015 = 100), annual indices (previous year = 100) or annual changes in %. Decimal commas are accepted. In the indicator settings (Configure analysis in the guided version) you choose the columns and say how the CPI is organised. Accepted formats: .csv, .tsv, .txt, .xlsx, .xls, .rds, .dta, .sav and the other table formats."),
              accept = c(".rds", ".RData", ".rda", ".csv", ".tsv", ".txt", ".dat",
                         ".dta", ".sav", ".zsav", ".por", ".sas7bdat", ".xpt",
                         ".parquet", ".feather", ".xlsx", ".xls")),
            uiOutput("cpi_active_file")
          )
        )
      ),

      # ============================ STEP 2 ============================
      wiz_panel("mapping",
        uiOutput("mapping_validation_summary"),
        tags$div(class = "wiz-grid wiz-grid-3",
          tags$div(class = "wiz-col",
            h4("Survey design"),
            mapping_selectize("var_year",
              tip_label(wiz_req("year"), "Column name in the survey data that identifies the year. Search the survey columns or type the column name."),
              "year"),
            mapping_selectize("var_domain",
              tip_label(wiz_req("domain"), "Column name in the survey data that identifies the small area domain (e.g. NUTS-3 province). Search the survey columns or type the column name."),
              "prov"),
            mapping_selectize("var_psu",
              tip_label(wiz_req("psu"), "Column name for the Primary Sampling Unit. Used to compute design-based sampling variances. Search the survey columns or type the column name."),
              "ea_id"),
            mapping_selectize("var_weight",
              tip_label(wiz_req("weight"), "Column name for the survey sampling weight. Search the survey columns or type the column name."),
              "weight"),
            mapping_selectize("var_strata",
              tip_label("strata", "Optional strata ID column for survey-design variance estimation. Search the survey columns or type the column name. Leave blank if the survey design has no strata or strata are unavailable."),
              "")
          ),
          tags$div(class = "wiz-col",
            h4("Households and welfare"),
            survey_unit_input(),
            conditionalPanel(
              condition = "input.survey_unit != 'person'",
              mapping_selectize("var_hh_size",
                tip_label(wiz_req("household size"), "Column name for household size. With one row per household, direct estimates use population_weight = weight * household size; when no population file is uploaded, benchmarking also estimates domain populations as sum(weight * household size) by domain and year. Not used when each row is a person."),
                "hhsize")
            ),
            mapping_selectize("var_hh_id",
              tip_label("household ID (optional)", "Optional column identifying the household. It is used only to check that the rows match the survey unit chosen above: a file with several rows per household, as many as the household size, has one row per person."),
              ""),
            mapping_selectize("var_welfare",
              tip_label(wiz_req("welfare"), "Column name for the welfare variable (e.g. income or consumption) used to determine poverty status. Search the survey columns or type the column name."),
              "income")
          ),
          tags$div(class = "wiz-col",
            h4("Join keys"),
            mapping_selectize("rhs_domain",
              tip_label(wiz_req("Auxiliary covariates domain field"), "Column name in the auxiliary covariates file that identifies the domain. Search the auxiliary columns or type the column name. Used to join covariates to survey data."),
              "prov"),
            mapping_selectize("shp_domain",
              tip_label(wiz_req("Shapefile domain field"), "Column name in the shapefiles/geometries file that identifies the domain. Search the geometry columns or type the column name. Used to join estimates to map polygons."),
              "prov")
          )
        )
      ),

      # ============================ STEP 3 ============================
      wiz_panel("analysis",
        tags$div(class = "wiz-grid",
          tags$div(class = "wiz-col",
            h4("Analysis"),
            tags$div(class = "wiz-years",
              selectizeInput("year_1", wiz_req("First year"), choices = NULL,
                             options = list(create = TRUE, placeholder = "Year")),
              selectizeInput("year_2", wiz_req("Second year"), choices = NULL,
                             options = list(create = TRUE, placeholder = "Year"))
            ),
            uiOutput("wiz_years_hint"),
            # The pipeline reads the two years from this hidden field.
            tags$div(class = "wiz-hidden",
              textInput("years", "Analysis years", value = "2012,2013")),
            textInput("country_name",
              tip_label("Country or territory", "Used only in report and brief titles; it does not affect estimation."),
              value = ""),
            numericInput("analysis_seed",
              tip_label("Analysis seed", "Controls LASSO folds and the UFH, MFH and benchmarking bootstrap draws. Identical inputs, settings and package versions reproduce the same results."),
              value = 123, min = 0, step = 1)
          ),
          tags$div(class = "wiz-col",
            h4("Indicator"),
            selectInput("indicator_type",
              tip_label("Indicator",
                        "What is being modelled. 'Poverty (FGT)' uses welfare + a poverty line to compute headcount, gap, or severity. 'Mean welfare' uses the population-weighted mean of the welfare variable directly."),
              choices  = c("Poverty (FGT)" = "poverty",
                           "Mean welfare"  = "mean_welfare"),
              selected = "poverty"),

            # ---- Poverty line (only shown for poverty indicator) ----
            conditionalPanel(
              condition = "input.indicator_type == 'poverty'",
              radioButtons("povline_type",
                tip_label("Poverty line source",
                          "Choose whether the poverty line comes from a column in the survey data or from numeric values entered separately for each analysis year."),
                choices  = c("Column in data" = "column", "Numeric value" = "numeric"),
                selected = "column", inline = TRUE),
              conditionalPanel(
                condition = "input.povline_type == 'column' && input.indicator_type == 'poverty'",
                mapping_selectize("var_povline",
                  tip_label("povline", "Column name for the poverty line. Search the survey columns or type the column name."),
                  "povline")
              ),
              conditionalPanel(
                condition = "input.povline_type == 'numeric' && input.indicator_type == 'poverty'",
                uiOutput("povline_numeric_by_year_ui")
              ),

              # ---- FGT indicator ----
              selectInput("fgt_alpha",
                tip_label("Poverty measure",
                          "FGT(0) = headcount ratio (share below the line). FGT(1) = poverty gap (average depth of shortfall). FGT(2) = poverty severity (squared gap, emphasises the poorest)."),
                choices = c("FGT(0) \u2013 Headcount ratio" = "0",
                            "FGT(1) \u2013 Poverty gap"      = "1",
                            "FGT(2) \u2013 Poverty severity"  = "2"),
                selected = "0")
            ),

            # ---- Mean welfare options (only shown for mean indicator) ----
            # Note: the log/no choice now lives in the UFH "Transformation"
            # dropdown below (which becomes context-aware when the indicator
            # is mean welfare). The standalone "Log-transform welfare"
            # checkbox has been removed in favor of that single source of
            # truth -- it was replicating the same setting in two places.
            conditionalPanel(
              condition = "input.indicator_type == 'mean_welfare'",
              textInput("currency_symbol",
                tip_label("Currency symbol",
                          "Short label appended to axis titles and table headers for mean welfare estimates."),
                value = "EUR"),
              # Prices of welfare (mean welfare only): convert current prices to
              # constant prices of a base year with a price index
              # (sae_apply_price_index(), R/pipeline_helpers.R), leave them as they
              # are, or record that the survey's welfare is already in constant (real)
              # prices, in which case no price index is needed or applied.
              radioButtons("welfare_prices",
                tip_label("Welfare in the survey data is in",
                          "Household-survey incomes and expenditures are usually in current (nominal) prices, so a change in mean welfare would include inflation. 'Current prices: convert with a price index' expresses welfare in constant prices: enter a consumer price index (for example the CPI or HICP) below, typed in or from the CPI file; welfare is multiplied by the price level of the base year / the price level of the year its incomes refer to (the survey year, or the calendar year before it), so all mean-welfare levels are in prices of the base year and changes between years are real changes. 'Current prices: no conversion' leaves welfare as it is, so changes include inflation. Choose 'Constant (real) prices already' when the survey's income or expenditure has already been adjusted for inflation: no price index is needed or applied, and you can give the year of those prices for the labels."),
                choices = c("current prices: convert with a price index" = "convert",
                            "current prices: no conversion (changes include inflation)" = "current",
                            "constant (real) prices already: no price index needed" = "real"),
                selected = "current"),
              conditionalPanel(
                condition = "input.welfare_prices == 'real' && input.indicator_type == 'mean_welfare'",
                numericInput("real_price_year",
                  tip_label("Year of those prices (optional)",
                            "Year whose prices the survey's welfare is in, for example 2017. Used only in labels (for example 'constant 2017 prices'); leave it empty if it is not known."),
                  value = NA, min = 1900, max = 2100, step = 1)
              ),
              conditionalPanel(
                condition = "input.welfare_prices == 'convert' && input.indicator_type == 'mean_welfare'",
                price_index_inputs(),
                uiOutput("price_index_by_year_ui"),
                uiOutput("price_base_index_ui")
              )
            )
          )
        )
      ),

      # ============================ STEP 4 ============================
      wiz_panel("models",
        checkboxGroupInput("steps",
          tip_label("Pipeline steps", "UFH fits a univariate Fay-Herriot model per year. MFH fits multivariate models (MFH1, MFH2, MFH3) that borrow strength across time. Comparison merges both results side by side with maps and precision metrics."),
          choices = c("UFH", "MFH", "Comparison"),
          selected = c("UFH", "MFH", "Comparison"),
          inline = TRUE
        ),
        tags$div(class = "wiz-grid wiz-grid-3",
          tags$div(class = "wiz-col",
            h4("UFH options"),
            # Transformation dropdown: choices are context-aware.
            #   - poverty indicator: arcsin / no
            #   - mean_welfare      : log    / no
            # The actual choice list is updated by an observer on input$indicator_type
            # (see server logic below). We seed it with the poverty defaults here.
            selectInput("ufh_transformation",
              tip_label("Transformation",
                        paste(
                          "Transformation of the direct estimates before model fitting.",
                          "For poverty rates: 'arcsin' constrains estimates to [0,1] and stabilizes variances.",
                          "For mean welfare: 'log' models the logarithm of each area's direct arithmetic mean, with its sampling variance transformed by the delta method. Predictions return to currency units using the correction selected below.",
                          "'no' fits on the original scale.")),
              choices = c("arcsin", "no"), selected = "arcsin"),
            # Bias correction is meaningful under arcsin AND log. For arcsin, it
            # corrects the non-linearity of arcsine; for log, it corrects the
            # Jensen-inequality bias of exp(eta_hat). The available options
            # depend on the chosen transformation (set dynamically server-side).
            conditionalPanel(
              condition = "input.ufh_transformation == 'arcsin' || input.ufh_transformation == 'log'",
              selectInput("ufh_backtrans",
                tip_label("Bias Correction",
                          paste(
                            "How the model estimates are bias-corrected when back-transforming to the original scale.",
                            "For arcsin: 'bc' uses the correction implemented by emdi; inspect reported boundary cautions. 'none' returns the naive sin^2(eta_hat).",
                            "For log: 'bc_sm' uses the Slud-Maiti correction implemented by emdi, with maximum-likelihood variance estimation. 'none' uses exp(eta_hat) without bias correction. Both target the area's arithmetic mean welfare; the naive prediction can be biased downwards. Corrected predictions are unavailable for areas without a direct estimate.")),
                choices = c("bc", "none"), selected = "bc")
            ),
            # Identity and log models honor the selected variance policy.
            # Arcsin instead uses effective-sample-size working variances.
            conditionalPanel(
              condition = "input.ufh_transformation == 'no' || input.ufh_transformation == 'log'",
            selectInput("ufh_var_choice",
              tip_label("Variance option (UFH)", "Sampling variance input for identity or log UFH. The default 'sm_out' keeps survey variances and replaces only missing/non-finite or below-0.001 values with GVF predictions. 'sm_all' replaces all working variances with GVF predictions from sample size alone, which can overstate variances where poverty rates are low; 'direct' retains survey variances except missing/zero safety backfills. Under log, the selected policy applies to log-scale variances. Arcsin uses effective-sample-size working variance 1/(4*n_eff) independently of this choice. Raw Direct uncertainty is reported separately."),
                choices = c("sm_out", "sm_all", "direct"), selected = "sm_out")
            ),
            ic_criterion_input("ufh", selected = "BIC",
              tip_text = "Information criterion used for stepwise covariate selection. BIC penalizes complexity more heavily and tends to select simpler models. AIC favours predictive accuracy. Not used when covariates are entered for both years with LASSO off."),
            checkboxInput("ufh_lasso_enabled",
              tip_label("Use LASSO screening",
                        "Optionally screens numeric covariates with LASSO before the AIC/BIC stepwise stage. The final model is still chosen by stepwise selection."),
              value = FALSE),
            conditionalPanel(
              condition = "input.ufh_lasso_enabled",
              selectInput("ufh_lasso_lambda",
                tip_label("LASSO lambda",
                          "lambda.1se is more conservative; lambda.min may retain more predictors."),
                choices = c("lambda.1se", "lambda.min"), selected = "lambda.1se")
            ),
            textInput("ufh_candidates_y1",
              tip_label("UFH covariates for Year 1 (comma-separated, optional)",
                        "If LASSO is on, these variables define the candidate pool for the first analysis year. If LASSO is off, they define the fixed UFH specification. Leave blank to use the eligible auxiliary variables."),
              value = ""),
            textInput("ufh_candidates_y2",
              tip_label("UFH covariates for Year 2 (comma-separated, optional)",
                        "If LASSO is on, these variables define the candidate pool for the second analysis year. If LASSO is off, they define the fixed UFH specification. Leave blank to use the eligible auxiliary variables."),
              value = "")
          ),
          tags$div(class = "wiz-col",
            h4("MFH options"),
            # Transformation choice for MFH. Independent from UFH so the two
            # models can run on different scales if needed (rare, but
            # supported -- e.g. UFH on identity, MFH on log).
            #   - poverty: hidden (MFH never used arcsin; identity scale only)
            #   - mean_welfare: log / no, default log
            # The bias-correction subchoice mirrors the UFH menu but only
            # offers conditional lognormal correction for log; arcsin is not an MFH
            # option and so 'bc' (integration-based) is not exposed here.
            conditionalPanel(
              condition = "input.indicator_type == 'mean_welfare'",
              selectInput("mfh_transformation",
                tip_label("Transformation (MFH)",
                          paste(
                            "Transformation applied to the MFH model. Independent of the UFH choice above.",
                            "'log' models the logarithm of each area's direct arithmetic mean in each year. Annual MSE and cross-year prediction-error moments are estimated jointly by refitting bootstrap samples and back-transforming their predictions to currency units. The report expresses mean-welfare changes as percentages.",
                            "'no' fits on the identity scale.")),
                choices = c("log", "no"), selected = "log"),
              conditionalPanel(
                condition = "input.mfh_transformation == 'log'",
                selectInput("mfh_backtrans",
                  tip_label("Bias Correction (MFH)",
                            paste(
                              "Bias correction for the log -> currency back-transform.",
                              "'Conditional lognormal' uses exp(eta_hat + v/2), where v is the conditional prediction variance under the fitted MFH model. Parameter estimation is included in the bootstrap uncertainty. This is a model-based extension for MFH log predictions.",
                              "'none' returns the naive exp(eta_hat), which is downward-biased for the mean.")),
                  choices = c("Conditional lognormal" = "conditional_lognormal", "none" = "none"), selected = "conditional_lognormal")
              )
            ),
            ic_criterion_input("mfh", selected = "AIC",
              tip_text = "Information criterion used for stepwise covariate selection. AIC favours predictive accuracy; BIC penalizes complexity more and selects sparser models. Not used when covariates are entered for both years with LASSO off."),
            checkboxInput("mfh_lasso_enabled",
              tip_label("Use LASSO screening",
                        "Optionally screens numeric covariates with LASSO before the AIC/BIC stepwise stage. The final model is still chosen by stepwise selection."),
              value = FALSE),
            conditionalPanel(
              condition = "input.mfh_lasso_enabled",
              selectInput("mfh_lasso_lambda",
                tip_label("LASSO lambda",
                          "lambda.1se is more conservative; lambda.min may retain more predictors."),
                choices = c("lambda.1se", "lambda.min"), selected = "lambda.1se")
            ),
            selectInput("mfh_var_choice",
              tip_label("Variance option (MFH)", "Sampling variance input: the default 'sm_out' keeps survey variances and replaces only missing/non-finite or below-0.001 values with GVF predictions; 'sm_all' replaces all variances with GVF predictions from sample size alone, which can overstate variances where poverty rates are low; 'direct' retains survey variances except missing/zero safety backfills. For log means, the policy applies on the log-mean variance scale. The covariance options below update automatically to match."),
              choices = c("sm_out", "sm_all", "direct"), selected = "sm_out"),
            selectInput("mfh_cov_choice",
              tip_label("Covariance option", "How the covariance of sampling errors over time is estimated. Available options depend on the variance choice above. 'rho_sm_out' multiplies the national average autocorrelation with outlier-smoothed variances (available with sm_out). 'rho_sm_all' multiplies it with fully smoothed variances (available with sm_all). 'rho_dir' multiplies it with direct variances. 'direct' uses the direct variance-covariance matrix. 'zero' assumes no cross-year sampling correlation."),
              choices = c("rho_sm_out", "direct", "zero"), selected = "rho_sm_out"),
            selectInput("mfh_diag_model",
              tip_label("Selected MFH model", "MFH2 is the package default. If MFH3 is selected, the package follows Molina and Romero: fit MFH3, use MFH2 if MFH3 does not converge or errors, and otherwise use the MFH3 random-effect variance homogeneity test to choose MFH3 or MFH2. MFH1 remains an additional sensitivity model."),
              choices = c(
                "MFH1 (additional sensitivity model)" = "MFH1",
                "MFH2 (default)" = "MFH2",
                "MFH3 candidate (Molina-Romero test and fallback)" = "MFH3"
              ), selected = "MFH2"),
            checkboxInput("fit_mfh3",
              tip_label("Also fit MFH3 for sensitivity", "When MFH1 or MFH2 is selected, this optional checkbox fits MFH3 for comparison diagnostics without changing the selected model. Selecting MFH3 above always fits it and applies the Molina-Romero test and MFH2 fallback."),
              value = FALSE),
            conditionalPanel(
              condition = "input.mfh_diag_model == 'MFH3' || input.fit_mfh3",
              selectInput("mfh_refvar_adjustment",
                tip_label("MFH3 reference-variance test adjustment", "This setting applies only to the pairwise time-variance contrasts returned when MFH3 is fitted. It does not adjust poverty-change tests across geographic domains. Bonferroni is the conservative model-selection default; BH is a less-conservative sensitivity option. With two years there is only one contrast, so both give the same p-value."),
                choices = c("Bonferroni (recommended)" = "bonferroni",
                            "Benjamini-Hochberg (sensitivity)" = "BH"),
                selected = "bonferroni")
            ),
            numericInput("mcpe_bootstrap_replicates",
              tip_label("Bootstrap replicates", "Controls UFH bootstrap MSE, MFH annual and change uncertainty, and benchmarking. The default is 500. Smaller counts are for quick checks; inspect Monte Carlo precision before interpreting inference. More draws reduce simulation noise but do not guarantee interval coverage."),
              value = 500, min = 50, step = 50),
            textInput("mfh_candidates_y1",
              tip_label("MFH covariates for Year 1 (comma-separated, optional)",
                        "If LASSO is on, these variables define the candidate pool for the first analysis year. If LASSO is off, they define the fixed MFH specification. Leave blank to use the eligible auxiliary variables."),
              value = ""),
            textInput("mfh_candidates_y2",
              tip_label("MFH covariates for Year 2 (comma-separated, optional)",
                        "If LASSO is on, these variables define the candidate pool for the second analysis year. If LASSO is off, they define the fixed MFH specification. Leave blank to use the eligible auxiliary variables."),
              value = "")
          ),
          tags$div(class = "wiz-col",
            h4("Benchmarking"),
            checkboxInput("do_benchmark",
              tip_label("Apply benchmarking", "If checked, UFH and MFH estimates are benchmarked. If unchecked, uploaded benchmark files and benchmark-level mappings are ignored for the next run."),
              value = FALSE),
            conditionalPanel(
              condition = "input.do_benchmark",
              radioButtons(
                "benchmark_level",
                tip_label(
                  "Benchmarking level",
                  "National benchmarking makes the population-weighted average of the domain estimates equal the direct national estimate. Grouped benchmarking applies the constraint separately within each selected higher-level area."
                ),
                choices = c(
                  "National" = "national",
                  "Grouped by a survey variable" = "custom"
                ),
                selected = "national"
              ),
              conditionalPanel(
                condition = "input.benchmark_level == 'national' && (input.var_benchmark_level || '').trim() !== ''",
                tags$p(class = "help-block",
                       "A grouped benchmark variable is still selected but is not used: National ",
                       "benchmarking applies one national constraint. Choose \"Grouped by a survey ",
                       "variable\" to use it, or clear the variable.")
              ),
              fileInput("regional_benchmark_file",
                tip_label("Benchmark Target Database (optional)",
                          "Optional RDS/CSV/XLSX file with one target per group/year (or one per year nationally). Duplicate keys are rejected, even when values agree. Named matrix columns match years; completely unnamed columns must follow the selected year order. Leave blank to estimate targets from the survey with the population weights (weight * household size when each row is a household, weight when each row is a person).")),
              tags$details(
                class = "benchmark-format-note",
                tags$summary(class = "note-title", "External benchmark file format"),
                tags$p(
                  "Upload this file only when you have external benchmark targets. ",
                  "Leave it blank to estimate targets from the survey."
                ),
                tags$ul(
                  tags$li("National benchmarking: include a year column and a target column."),
                  tags$li("Grouped benchmarking: also include the benchmark-level column selected below."),
                  tags$li("Name the target column benchmark or target (also accepted: B_r, benchmark_target, regional_benchmark, direct, direct_rate, poverty_rate)."),
                  tags$li("Accepted file types: .rds, .RData/.rda, .csv, .txt, .xlsx, or .xls.")
                )
              ),
              tags$div(
                class = "benchmark-clear-row",
                actionButton("clear_benchmark_file",
                  "Clear selected file",
                  class = "btn-default btn-sm")
              ),
              uiOutput("benchmark_active_file"),
              conditionalPanel(
                condition = "input.benchmark_level == 'custom'",
                mapping_selectize("var_benchmark_level",
                  tip_label("Grouped benchmark variable",
                            "Survey column defining the higher-level benchmark groups, such as region, NUTS2, or voivodeship."),
                  "")
              )
            ),
            h4("Data assessment"),
            checkboxInput("psu_consistent",
            tip_label("PSU codes are consistent over time", "Check this if the same PSU identifiers refer to the same sampling units across years. The answer is recorded with the run settings; it does not change the estimates (the cross-year covariance of sampling errors is computed from the PSU codes in the data)."),
            value = FALSE)
          )
        )
      ),

      # ============================ STEP 5 ============================
      wiz_panel("ai",
        tags$div(class = "wiz-note",
          tags$strong("This step is optional."),
          " Leave the assistant disabled and press Next to continue \u2014 the model run is identical without it. ",
          "Only aggregate statistics are ever sent to the API; never raw microdata."
        ),
        tags$div(class = "wiz-narrow",
          uiOutput("llm_consent_ui"),
          checkboxInput("llm_enabled",
            tip_label("Enable AI Assistant", "Enable an AI-powered assistant that interprets diagnostics, evaluates normality assumptions, and enriches the analysis brief. Supports Anthropic (Claude) and OpenAI (ChatGPT) API keys."),
            value = FALSE),
          conditionalPanel(
            condition = "input.llm_enabled",
            checkboxInput("llm_external_consent",
              "I understand that aggregate estimates, uncertainty measures, diagnostics, and analysis context will be sent to the selected external AI provider. Geographic identifiers are removed from comparison prompts; raw microdata are not sent.",
              value = FALSE),
            passwordInput("api_key",
              tip_label("API Key", "Enter your Anthropic (sk-ant-...) or OpenAI (sk-...) API key. Only aggregate statistics are sent to the API \u2014 never raw microdata."),
              value = ""),
            selectInput("language",
              tip_label("Language", "Switch language of AI-assisted interpretation. All 24 official EU languages are supported, plus Arabic."),
              choices = supported_languages(),
              selected = "en")
          )
        )
      ),

      # ============================ STEP 6 ============================
      wiz_panel("review",
        uiOutput("wiz_outstanding"),
        tags$div(class = "wiz-grid",
          tags$div(class = "wiz-col wiz-col-wide",
            h4("Configuration summary"),
            uiOutput("wiz_summary")
          ),
          tags$div(class = "wiz-col",
            h4("Data files of the configuration"),
            uiOutput("saved_setup_status"),
            h4("Data readiness"),
            uiOutput("wiz_ready_status"),
            tags$p(class = "wiz-small",
                   "Check the data before running the model. Errors must be fixed; warnings and notes are for review."),
            actionButton("check_btn", "Check data readiness", class = "btn-primary")
          )
        ),
        tabsetPanel(
          id = "main_tabs",
          tabPanel("Preflight",
            h4("Startup Preflight"),
            p("Review these checks before running the pipeline. This panel updates automatically as you change inputs."),
            uiOutput("preflight_ui"),
            h4("Recommended actions"),
            verbatimTextOutput("preflight_actions")
          ),

          # ---- Tab: Data Readiness ----
          tabPanel("Data Readiness",
            h4("Data Readiness Assessment"),
            p("Press 'Check data readiness' on this step to generate the diagnostics. ",
              "Review the results here before running the model."),
            verbatimTextOutput("readiness_messages"),
            h4("National Poverty Headcount Rates"),
            tableOutput("readiness_national"),
            h4("Domain Consistency"),
            tableOutput("readiness_domains"),
            h4("Missing Poverty Rates"),
            tableOutput("readiness_missing"),
            h4("Auxiliary Covariate Summary"),
            p("Means, standard errors, domain counts, and Pearson correlations with the domain-level target indicator (poverty rate or mean welfare, matching the Indicator selector), shown for each year separately and pooled over all years. The p-value tests whether the correlation differs from zero (two-sided); significance codes: *** p < 0.001, ** p < 0.01, * p < 0.05, . p < 0.1. Variables are listed from the most to the least significant pooled correlation."),
            tableOutput("readiness_aux")
          )
        )
      ),

      # ============================ STEP 7 ============================
      wiz_panel("run",
        tags$div(class = "wiz-run-row",
          textInput("run_label",
            tip_label("Run label (optional)", "Short label appended to the run folder under app_runs/, so outputs from different runs are easier to tell apart."),
            value = ""),
          actionButton("run_btn",  "Run model", class = "btn-primary btn-lg"),
          actionButton("stop_btn", "Stop",      class = "btn-danger btn-lg",
                       disabled = "disabled",
                       title = "End the running model run")
        ),
        uiOutput("wiz_run_hint"),
        uiOutput("run_progress_panel"),
        tags$details(class = "wiz-log",
          tags$summary("Run log and output files"),
          h4("Current step"),
          textOutput("status"),
          h4("Run folder"),
          verbatimTextOutput("run_location"),
          h4("Run log"),
          verbatimTextOutput("logs"),
          h4("Expected outputs"),
          tableOutput("outputs")
        )
      )
    )
  ) # end main_app
)

# ---------------------------------------------------------------------
# 5. Wizard server layer
#
#    wizard_server() first runs app.R's server() verbatim -- registering
#    every output, observer and reactive the pipeline needs -- and then
#    adds the navigation, breadcrumb state and soft-gating on top.
#
#    The gating checks below deliberately re-derive their answers from
#    input$ values rather than reaching into app.R's internal reactives
#    (which are not exported). They are cheap, and keeping them separate
#    means app.R needs no modification at all.
# ---------------------------------------------------------------------

wiz_is_blank <- function(x) {
  !length(x) || is.null(x) || !nzchar(trimws(as.character(x)[1]))
}

wizard_server <- function(input, output, session) {

  # ---- Everything from the classic dashboard, unchanged --------------
  .wiz_core_server(input, output, session)

  # Shared with app.R's server (w5o): the data files of the configuration
  # that is loaded (none for a new model run), whether data readiness has
  # been confirmed for the current settings, and a counter that increases
  # each time a configuration is loaded.
  active_files  <- session$userData$active_setup_files
  readiness_ok  <- session$userData$readiness_checked
  config_loaded <- session$userData$config_loaded

  wiz_config_file_ok <- function(key) {
    ref <- tryCatch(active_files()[[key]], error = function(e) NULL)
    if (wiz_is_blank(ref)) return(FALSE)
    isTRUE(tryCatch(setup_file_exists(ref), error = function(e) FALSE))
  }

  wiz_have_file <- function(file_input, key) {
    !is.null(file_input) || wiz_config_file_ok(key)
  }

  wiz_file_label <- function(file_input, key) {
    if (!is.null(file_input)) return(basename(file_input$name[1]))
    if (wiz_config_file_ok(key)) {
      return(paste0(basename(active_files()[[key]]), " (from the loaded configuration)"))
    }
    "(not selected)"
  }

  # ===================================================================
  # Analysis years: two selectors on step 3, kept in step with the hidden
  # `years` field that app.R's server and the pipeline read.
  # ===================================================================

  # Years present in the survey file (needs the file and its year column).
  wiz_survey_years <- reactive({
    path <- tryCatch(session$userData$survey_input_path(), error = function(e) NULL)
    ycol <- trimws(as.character(input$var_year %||% ""))
    if (is.null(path) || !nzchar(path %||% "") || !file.exists(path) || !nzchar(ycol)) {
      return(integer())
    }
    df <- tryCatch(
      suppressMessages(suppressWarnings(sae_read_table_input(path, "survey data file"))),
      error = function(e) NULL
    )
    if (is.null(df) || !ycol %in% names(df)) return(integer())
    yrs <- suppressWarnings(as.integer(as.character(unique(df[[ycol]]))))
    sort(unique(yrs[!is.na(yrs)]))
  })

  wiz_picked_years <- function() {
    parse_years(paste(c(input$year_1 %||% "", input$year_2 %||% ""), collapse = ","))
  }

  # Selectors -> years (user choices).
  observeEvent(list(input$year_1, input$year_2), {
    picked <- wiz_picked_years()
    if (!identical(picked, parse_years(input$years))) {
      updateTextInput(session, "years", value = paste(picked, collapse = ","))
    }
  }, ignoreInit = TRUE, ignoreNULL = FALSE)

  # years (defaults, a loaded configuration) and the survey's years -> selectors.
  # When the selectors already hold the target years, only the list of choices
  # is refreshed and each selector keeps its own value: re-sorting them here
  # would move the user's first choice into the second box, and the next pick
  # would then overwrite it.
  wiz_last_year_choices <- NULL
  observe({
    target  <- parse_years(input$years)
    choices <- as.character(sort(unique(c(wiz_survey_years(), target))))
    cur1 <- isolate(input$year_1) %||% ""
    cur2 <- isolate(input$year_2) %||% ""
    picked <- isolate(wiz_picked_years())
    if (identical(picked, target)) {
      if (identical(choices, wiz_last_year_choices)) return()
      wiz_last_year_choices <<- choices
      updateSelectizeInput(session, "year_1", choices = choices,
                           selected = if (nzchar(cur1)) cur1 else character(0))
      updateSelectizeInput(session, "year_2", choices = choices,
                           selected = if (nzchar(cur2)) cur2 else character(0))
      return()
    }
    wiz_last_year_choices <<- choices
    sel <- as.character(target)
    updateSelectizeInput(session, "year_1", choices = choices,
                         selected = if (length(sel) >= 1L) sel[1] else character(0))
    updateSelectizeInput(session, "year_2", choices = choices,
                         selected = if (length(sel) >= 2L) sel[2] else character(0))
  })

  output$wiz_years_hint <- renderUI({
    avail  <- wiz_survey_years()
    chosen <- parse_years(input$years)
    two    <- if (length(chosen) == 2L) NULL else " Choose two different years."
    if (length(avail)) {
      missing <- setdiff(chosen, avail)
      return(tags$div(
        class = paste("wiz-years-hint", if (length(missing) || !is.null(two)) "warn" else ""),
        sprintf("Years in the survey file: %s.", paste(avail, collapse = ", ")),
        if (length(missing)) sprintf(" Not in the survey file: %s.", paste(missing, collapse = ", ")),
        two
      ))
    }
    tags$div(
      class = paste("wiz-years-hint", if (!is.null(two)) "warn" else ""),
      "The years in the survey file are listed here once the file is selected (step 1) and its year column mapped (step 2).",
      two
    )
  })

  # ===================================================================
  # Per-step outstanding issues
  #
  # Each returns character(0) when the step is complete. These drive the
  # amber notices, the breadcrumb colours and the review step. They never
  # block navigation.
  # ===================================================================

  issues_data <- reactive({
    msgs <- character()
    if (!wiz_have_file(input$survey_file, "survey_file")) {
      msgs <- c(msgs, "Survey data file not selected.")
    }
    if (!wiz_have_file(input$rhs_file, "rhs_file")) {
      msgs <- c(msgs, "Auxiliary data file not selected.")
    }
    if (!wiz_have_file(input$shp_file, "shp_file")) {
      msgs <- c(msgs, "Shapefile/geometries file not selected.")
    }
    msgs
  })

  issues_mapping <- reactive({
    required <- c(
      var_year    = "year",
      var_domain  = "domain",
      var_psu     = "psu",
      var_weight  = "weight",
      var_hh_size = "household size",
      var_welfare = "welfare",
      rhs_domain  = "auxiliary covariates domain field",
      shp_domain  = "shapefile domain field"
    )
    # With one row per person household size is not used.
    if (identical(input$survey_unit %||% "household", "person")) {
      required <- required[names(required) != "var_hh_size"]
    }
    msgs <- character()
    for (id in names(required)) {
      if (wiz_is_blank(input[[id]])) {
        msgs <- c(msgs, sprintf("No column mapped for %s.", required[[id]]))
      }
    }
    # strata and household ID are optional and deliberately not checked here.
    msgs
  })

  issues_years <- reactive({
    if (length(parse_years(input$years)) != 2L) "Choose two different analysis years." else character()
  })

  issues_analysis <- reactive({
    msgs <- issues_years()
    seed <- suppressWarnings(as.numeric(input$analysis_seed))
    if (length(seed) != 1L || !is.finite(seed) || seed < 0 || seed != floor(seed)) {
      msgs <- c(msgs, "Analysis seed must be a non-negative whole number.")
    }
    ind <- input$indicator_type %||% "poverty"
    if (identical(ind, "poverty")) {
      if (identical(input$povline_type %||% "column", "column")) {
        if (wiz_is_blank(input$var_povline)) {
          msgs <- c(msgs, "No column mapped for the poverty line.")
        }
      } else {
        for (yr in parse_years(input$years)) {
          val <- input[[paste0("povline_numeric_", yr)]]
          if (is.null(val) || !is.finite(suppressWarnings(as.numeric(val)))) {
            msgs <- c(msgs, sprintf("No numeric poverty line entered for %s.", yr))
          }
        }
      }
    } else if (identical(input$welfare_prices, "convert")) {
      # Mean welfare in constant prices: every needed index value present.
      cfg <- session$userData$get_price_index_config()
      probs <- sae_price_index_problems(cfg, parse_years(input$years))
      if (length(probs)) msgs <- c(msgs, paste0("Price index: ", probs, "."))
    }
    msgs
  })

  issues_models <- reactive({
    msgs <- character()
    if (length(input$steps) == 0L) {
      msgs <- c(msgs, "Select at least one pipeline step (UFH, MFH or Comparison).")
    }
    if (isTRUE(input$do_benchmark) &&
        identical(input$benchmark_level %||% "national", "custom") &&
        wiz_is_blank(input$var_benchmark_level)) {
      msgs <- c(msgs, "Grouped benchmarking requires a benchmark-level survey variable.")
    }
    n_boot <- suppressWarnings(as.numeric(input$mcpe_bootstrap_replicates))
    if (length(n_boot) != 1L || !is.finite(n_boot) || n_boot < 50 || n_boot != floor(n_boot)) {
      msgs <- c(msgs, "Bootstrap replicates must be a whole number of at least 50.")
    }
    msgs
  })

  issues_ai <- reactive({
    msgs <- character()
    if (isTRUE(input$llm_enabled) && !isTRUE(input$llm_external_consent)) {
      msgs <- c(msgs, "The AI assistant is enabled but external-transfer consent has not been acknowledged.")
    }
    if (isTRUE(input$llm_enabled) && wiz_is_blank(input$api_key)) {
      msgs <- c(msgs, "The AI assistant is enabled but no API key has been entered.")
    }
    msgs
  })

  issues_review <- reactive({
    if (isTRUE(readiness_ok())) return(character())
    "Data readiness has not been confirmed for this configuration: press 'Check data readiness' and fix any ERROR items."
  })

  wiz_issue_map <- reactive({
    list(
      data     = issues_data(),
      mapping  = issues_mapping(),
      analysis = issues_analysis(),
      models   = issues_models(),
      ai       = issues_ai(),
      review   = issues_review(),
      run      = character()
    )
  })

  # ===================================================================
  # Notices, subtitles and breadcrumb state
  # ===================================================================

  wiz_issue_box <- function(msgs, ok_text) {
    if (length(msgs) == 0L) {
      return(tags$div(class = "wiz-ok", ok_text))
    }
    tags$div(
      class = "wiz-issues",
      tags$div(class = "wiz-issues-title",
               "Still outstanding on this step - you can continue anyway:"),
      tags$ul(lapply(msgs, tags$li))
    )
  }

  local({
    ok_texts <- list(
      data     = "All required data files are selected.",
      mapping  = "All required columns are mapped.",
      analysis = "The analysis years and the indicator are set.",
      models   = "Model options are set.",
      ai       = "Nothing outstanding - the AI assistant is optional."
    )
    subs <- list(
      data     = "Select the survey, auxiliary and geometry files. The population and price-index files are optional.",
      mapping  = "Tell the app which column in each file holds which variable. Fields in red name columns that are not in the selected file.",
      analysis = "Choose the two years to compare and what is estimated: a poverty measure (FGT) or mean welfare.",
      models   = "Fay-Herriot model settings, covariate selection and benchmarking. All have defaults.",
      ai       = "Optional. Adds AI-written interpretation of the results to the report.",
      review   = "Check the configuration, then check the data before running the model.",
      run      = "Start the model run. Its progress and result appear below; open the report from here when it is complete."
    )
    for (sid in WIZ_IDS) {
      local({
        this_id <- sid
        output[[paste0("wiz_issues_", this_id)]] <- renderUI({
          # The review step lists everything itself; the run step has its hint.
          if (this_id %in% c("review", "run")) return(NULL)
          wiz_issue_box(wiz_issue_map()[[this_id]], ok_texts[[this_id]])
        })
        output[[paste0("wiz_sub_", this_id)]] <- renderUI({
          HTML(subs[[this_id]])
        })
      })
    }
  })

  # Breadcrumb colours. Pushed as CSS classes rather than re-rendering
  # the links, so the action-button bindings survive untouched.
  observe({
    issues <- wiz_issue_map()
    current <- input$wizard %||% "data"
    states <- vapply(WIZ_IDS, function(id) {
      if (identical(id, current)) "current"
      else if (length(issues[[id]]) == 0L) "done"
      else "todo"
    }, character(1))
    session$sendCustomMessage("wizCrumbState", list(
      ids    = as.list(paste0("wiz_crumb_", WIZ_IDS)),
      states = as.list(unname(states))
    ))
  })

  # ===================================================================
  # Navigation
  # ===================================================================

  go_to <- function(step_id) {
    if (!step_id %in% WIZ_IDS) return(invisible(NULL))
    updateTabsetPanel(session, "wizard", selected = step_id)
    session$sendCustomMessage("wizScrollTop", list(x = TRUE))
  }

  for (sid in WIZ_IDS) {
    local({
      this_id <- sid
      idx <- match(this_id, WIZ_IDS)

      observeEvent(input[[paste0("wiz_crumb_", this_id)]], {
        go_to(this_id)
      }, ignoreInit = TRUE)

      if (idx > 1L) {
        observeEvent(input[[paste0("wiz_back_", this_id)]], {
          go_to(WIZ_IDS[idx - 1L])
        }, ignoreInit = TRUE)
      }
      if (idx < length(WIZ_IDS)) {
        observeEvent(input[[paste0("wiz_next_", this_id)]], {
          go_to(WIZ_IDS[idx + 1L])
        }, ignoreInit = TRUE)
      }
    })
  }

  # A loaded configuration (last saved or from a file, on the front page or
  # from the "Load configuration" menu) fills in every step at once, so show
  # the review step rather than making the user click through.
  observeEvent(config_loaded(), { go_to("review") }, ignoreInit = TRUE)
  observeEvent(input$reset_setup_btn, { go_to("data") }, ignoreInit = TRUE)
  observeEvent(input$wiz_go_review, { go_to("review") }, ignoreInit = TRUE)
  observeEvent(input$wiz_go_run, { go_to("run") }, ignoreInit = TRUE)

  # ===================================================================
  # Step 6: outstanding items, configuration summary, readiness status
  # ===================================================================

  output$wiz_outstanding <- renderUI({
    issues <- wiz_issue_map()
    labels <- vapply(WIZ_STEPS, function(s) s$short, character(1))
    names(labels) <- WIZ_IDS
    check_ids <- setdiff(WIZ_IDS, c("review", "run"))

    open_steps <- check_ids[vapply(check_ids, function(id) length(issues[[id]]) > 0L, logical(1))]
    if (length(open_steps) == 0L) {
      return(tags$div(class = "wiz-ok", "Steps 1 to 5 are complete."))
    }
    tags$div(
      class = "wiz-issues",
      tags$div(class = "wiz-issues-title", "Outstanding items"),
      tags$ul(lapply(open_steps, function(id) {
        tags$li(
          tags$strong(sprintf("Step %d, %s: ", match(id, WIZ_IDS), labels[[id]])),
          paste(issues[[id]], collapse = " ")
        )
      }))
    )
  })

  output$wiz_ready_status <- renderUI({
    if (isTRUE(readiness_ok())) {
      tags$div(class = "wiz-ready ok",
               "Data readiness checked: no blocking errors. Review any warnings below, then go to ",
               actionLink("wiz_go_run", "step 7, Run model"), ".")
    } else {
      tags$div(class = "wiz-ready todo",
               "Not yet checked for the current configuration (or the last check found errors).")
    }
  })

  wiz_fmt <- function(x, blank = "(not set)") {
    if (wiz_is_blank(x)) return(blank)
    paste(as.character(x), collapse = ", ")
  }

  output$wiz_summary <- renderUI({
    row  <- function(k, v) tags$tr(tags$th(k), tags$td(v))
    sec  <- function(k) tags$tr(class = "wiz-sec", tags$td(colspan = 2, k))

    ind <- input$indicator_type %||% "poverty"
    person <- identical(input$survey_unit %||% "household", "person")
    n_boot <- suppressWarnings(as.numeric(input$mcpe_bootstrap_replicates))

    rows <- list(
      sec("1. Input data"),
      row("Survey file", wiz_file_label(input$survey_file, "survey_file")),
      row("Auxiliary file", wiz_file_label(input$rhs_file, "rhs_file")),
      row("Geometry file", wiz_file_label(input$shp_file, "shp_file")),
      row("Population file", wiz_file_label(input$population_file, "population_file")),
      row("CPI file", wiz_file_label(input$cpi_file, "cpi_file")),

      sec("2. Map variables"),
      row("year / domain", paste(wiz_fmt(input$var_year), "/", wiz_fmt(input$var_domain))),
      row("psu / weight", paste(wiz_fmt(input$var_psu), "/", wiz_fmt(input$var_weight))),
      row("strata", wiz_fmt(input$var_strata, "(none)")),
      row("Each row of the survey file is", if (person) "a person" else "a household"),
      row("household size", if (person) "not used (one row per person)" else wiz_fmt(input$var_hh_size)),
      row("household ID", wiz_fmt(input$var_hh_id, "(none)")),
      row("welfare", wiz_fmt(input$var_welfare)),
      row("auxiliary / shapefile domain", paste(wiz_fmt(input$rhs_domain), "/", wiz_fmt(input$shp_domain))),

      sec("3. Configure analysis"),
      row("Analysis years", wiz_fmt(paste(parse_years(input$years), collapse = ", "))),
      row("Country or territory", wiz_fmt(input$country_name, "Not specified")),
      row("Analysis seed", wiz_fmt(input$analysis_seed, "123")),
      row("Indicator", if (identical(ind, "poverty")) "Poverty (FGT)" else "Mean welfare")
    )

    if (identical(ind, "poverty")) {
      rows <- c(rows, list(
        row("Poverty measure", sprintf("FGT(%s)", wiz_fmt(input$fgt_alpha, "0"))),
        row("Poverty line source",
            if (identical(input$povline_type %||% "column", "column")) {
              paste("column:", wiz_fmt(input$var_povline))
            } else {
              yrs <- parse_years(input$years)
              vals <- vapply(yrs, function(yr) {
                sprintf("%s = %s", yr, wiz_fmt(input[[paste0("povline_numeric_", yr)]]))
              }, character(1))
              paste("numeric:", paste(vals, collapse = "; "))
            })
      ))
    } else {
      rows <- c(rows, list(
        row("Currency symbol", wiz_fmt(input$currency_symbol)),
        row("Prices", sae_price_basis_label(session$userData$get_price_index_config(),
                                            parse_years(input$years), "mean_welfare"))
      ))
    }

    rows <- c(rows, list(
      sec("4. Configure model"),
      row("Pipeline steps", wiz_fmt(input$steps, "(none selected)")),
      row("UFH transformation / criterion",
          paste(wiz_fmt(input$ufh_transformation), "/",
                sae_ic_criterion_label(input$ufh_ic_criterion,
                                       isTRUE(input$ufh_lasso_enabled),
                                       split_csv(input$ufh_candidates_y1),
                                       split_csv(input$ufh_candidates_y2)))),
      row("UFH LASSO screening", if (isTRUE(input$ufh_lasso_enabled)) wiz_fmt(input$ufh_lasso_lambda) else "off"),
      row("MFH model / criterion",
          paste(wiz_fmt(input$mfh_diag_model), "/",
                sae_ic_criterion_label(input$mfh_ic_criterion,
                                       isTRUE(input$mfh_lasso_enabled),
                                       split_csv(input$mfh_candidates_y1),
                                       split_csv(input$mfh_candidates_y2)))),
      row("MFH variance / covariance",
          paste(wiz_fmt(input$mfh_var_choice), "/", wiz_fmt(input$mfh_cov_choice))),
      row("MFH LASSO screening", if (isTRUE(input$mfh_lasso_enabled)) wiz_fmt(input$mfh_lasso_lambda) else "off"),
      row("Fit MFH3", if (isTRUE(input$fit_mfh3) || input$mfh_diag_model %in% c("AUTO", "MFH3")) "yes" else "no"),
      row(
        "MFH3 reference-variance test adjustment",
        if (identical(input$mfh_diag_model, "MFH3") || isTRUE(input$fit_mfh3)) {
          wiz_fmt(input$mfh_refvar_adjustment, "bonferroni")
        } else {
          "not applied (MFH3 not requested)"
        }
      ),
      row("Poverty-change inference", "pointwise primary; BH and Bonferroni sensitivities reported"),
      row("Bootstrap replicates",
          if (length(n_boot) == 1L && is.finite(n_boot) && n_boot < 500) {
            sprintf("%s (below the default of 500: suitable for quick checks; check Monte Carlo precision before interpreting results)",
                    wiz_fmt(input$mcpe_bootstrap_replicates))
          } else wiz_fmt(input$mcpe_bootstrap_replicates, "500")),
      row("Benchmarking",
          if (isTRUE(input$do_benchmark)) {
            lvl <- if (identical(input$benchmark_level %||% "national", "national")) {
              "national"
            } else {
              paste("by", wiz_fmt(input$var_benchmark_level, "(variable not selected)"))
            }
            paste("on -", lvl)
          } else "off"),
      row("PSU codes consistent over time", if (isTRUE(input$psu_consistent)) "yes" else "no"),

      sec("5. AI assistant"),
      row("Enabled", if (isTRUE(input$llm_enabled)) "yes" else "no"),
      row("External-transfer consent", if (isTRUE(input$llm_external_consent)) "acknowledged" else "not acknowledged"),
      row("API key", if (wiz_is_blank(input$api_key)) "(not entered)" else "entered"),
      row("Language", wiz_fmt(input$language, "en"))
    ))

    tags$table(class = "wiz-summary", tags$tbody(rows))
  })

  # ===================================================================
  # Step 7: run gate and hint
  # ===================================================================

  # Run gate. Only the genuinely fatal prerequisites block the button:
  # the three data files and two analysis years. app.R's own run handler
  # additionally asks for a data readiness check; everything else is a
  # hint, so an expert user is never trapped by a validation rule.
  wiz_run_blockers <- reactive({ c(issues_data(), issues_years()) })

  observe({
    session$sendCustomMessage("wizToggleBtn", list(
      id = "run_btn",
      disabled = length(wiz_run_blockers()) > 0L
    ))
  })

  output$wiz_run_hint <- renderUI({
    # While a run is in progress the progress panel says it all.
    if (identical(session$userData$run_panel()$state, "running")) return(NULL)
    blockers <- wiz_run_blockers()
    if (length(blockers) > 0L) {
      return(tags$div(
        class = "wiz-issues",
        tags$div(class = "wiz-issues-title", "Run model is disabled until these are set:"),
        tags$ul(lapply(blockers, tags$li))
      ))
    }
    if (!isTRUE(readiness_ok())) {
      return(tags$div(
        class = "wiz-issues",
        tags$div(class = "wiz-issues-title", "Check data readiness first"),
        "The data have not been checked for the current configuration. Go to ",
        actionLink("wiz_go_review", "step 6, Review configuration"),
        " and press ", tags$strong("Check data readiness"), "."
      ))
    }
    other <- unlist(wiz_issue_map()[setdiff(WIZ_IDS, c("data", "review", "run"))])
    if (length(other) > 0L) {
      return(tags$div(
        class = "wiz-note",
        "You can run now, but some steps still have outstanding items (listed in step 6)."
      ))
    }
    tags$div(class = "wiz-ok", "Ready to run.")
  })
}

# ---------------------------------------------------------------------
# 6. Launch
#
# Mirrors app.R's behaviour: when sourced non-interactively (i.e. from
# Start_Here/Start_Wizard.bat) the app is launched explicitly; inside RStudio the
# shinyApp object is simply returned so "Run App" works. The guard
# environment variable prevents re-entry if the file is sourced twice.
# ---------------------------------------------------------------------

.wiz_app <- shinyApp(ui, wizard_server)

.wiz_run <- function(preferred = 7788L) {
  for (port in c(preferred, preferred + 1L, preferred + 2L, preferred + 3L)) {
    ok <- tryCatch({
      shiny::runApp(.wiz_app, host = "127.0.0.1", port = port,
                    launch.browser = TRUE)
      TRUE
    }, error = function(e) {
      if (grepl("port|address|in use", conditionMessage(e), ignore.case = TRUE)) {
        message(sprintf("Port %d unavailable, trying the next one...", port))
        FALSE
      } else {
        stop(e)
      }
    })
    if (isTRUE(ok)) return(invisible(TRUE))
  }
  # Last resort: let Shiny pick any free port.
  shiny::runApp(.wiz_app, host = "127.0.0.1", launch.browser = TRUE)
  invisible(TRUE)
}

if (!interactive() && !nzchar(Sys.getenv("EU_SAE_WIZARD_LAUNCHED"))) {
  Sys.setenv(EU_SAE_WIZARD_LAUNCHED = "1")
  .wiz_run()
} else {
  .wiz_app
}
