# ============================================================
# report_map_picker.R -- method picker for the map grids in the HTML report
# ============================================================
#
# The Comparison step writes one map image per method and year to
# outputs/figures/<family>/grid_panels/, with a colour bar and manifest.csv
# (columns row, method, tag, year, file, saved, legend, caption).
# sae_map_picker_html() turns them into a self-contained HTML block: a
# "Methods" drop-down list with one check box per method, and a table with
# one row per method and one column per year. Unticking a method hides its
# row, so the reader can compare, for example, UFH with UFH benchmarked only.
#
# Images are embedded as data URIs, so the block works in the stand-alone
# HTML report and does not depend on the location of the outputs folder.
# The Word report cannot run the picker: report.Rmd places the block in a
# div of class "sae-html-only", which R/report_word.lua drops, and puts the
# static grid in a div of class "sae-word-only", hidden in the HTML. The
# block is also enclosed in <!--sae-html-only-start/end--> comments, so that
# sae_render_word_report() removes it before Pandoc reads the HTML: its
# embedded images would otherwise add to Pandoc's memory use for nothing.

sae_html_escape <- function(x) {
  x <- gsub("&", "&amp;", as.character(x), fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  gsub("\"", "&quot;", x, fixed = TRUE)
}

sae_map_picker_css <- function() {
  paste(
    "<style>",
    ".sae-word-only{display:none;}",
    ".sae-map-picker{margin:0.5em 0 1.5em 0;}",
    ".sae-map-picker-bar{display:flex;flex-wrap:wrap;align-items:center;gap:0.4em 1em;margin-bottom:0.6em;}",
    ".sae-map-picker-menu{position:relative;display:inline-block;}",
    ".sae-map-picker-menu>summary{cursor:pointer;list-style:none;display:inline-block;padding:0.35em 0.8em;border:1px solid #9aa4ae;border-radius:4px;background:#f7f9fb;font-weight:600;}",
    ".sae-map-picker-menu>summary::-webkit-details-marker{display:none;}",
    ".sae-map-picker-menu>summary::after{content:' \\25BE';}",
    ".sae-map-picker-menu[open]>summary{background:#e9eef3;}",
    ".sae-map-picker-list{position:absolute;z-index:20;top:100%;left:0;margin-top:4px;min-width:16em;padding:0.5em 0.8em;background:#fff;border:1px solid #9aa4ae;border-radius:4px;box-shadow:0 4px 12px rgba(0,0,0,0.15);}",
    ".sae-map-picker-list label{display:block;font-weight:normal;margin:0.25em 0;white-space:nowrap;cursor:pointer;}",
    ".sae-map-picker-list input{margin:0 0.45em 0 0;vertical-align:middle;}",
    ".sae-map-picker-actions{border-top:1px solid #e1e5e9;margin-top:0.4em;padding-top:0.4em;}",
    ".sae-map-picker-actions button{font-size:0.9em;margin-right:0.4em;padding:0.15em 0.6em;border:1px solid #9aa4ae;border-radius:3px;background:#f7f9fb;}",
    ".sae-map-picker-hint{color:#555;font-size:0.92em;}",
    ".sae-map-grid-table{width:100%;border-collapse:collapse;table-layout:fixed;}",
    ".sae-map-grid-table th{text-align:center;font-weight:700;padding:0.3em;}",
    ".sae-map-grid-table th[scope=row]{text-align:left;vertical-align:middle;width:8.5em;padding-right:0.6em;}",
    ".sae-map-grid-table td{padding:0.2em;vertical-align:middle;}",
    ".sae-map-grid-table td img{width:100%;height:auto;display:block;}",
    ".sae-map-grid-table tbody tr{border-top:1px solid #e1e5e9;}",
    ".sae-map-picker-legend{text-align:center;margin-top:0.6em;}",
    ".sae-map-picker-legend img{max-width:30em;width:70%;height:auto;}",
    ".sae-map-picker-caption{text-align:right;color:#555;font-size:0.85em;margin-top:0.3em;}",
    ".sae-map-picker-empty{color:#a33;font-style:italic;}",
    "</style>",
    sep = "\n"
  )
}

sae_map_picker_js <- function(id) {
  sprintf(paste(
    "<script>",
    "(function(){",
    "  var root = document.getElementById('%s'); if (!root) return;",
    "  var menu = root.querySelector('details');",
    "  var boxes = root.querySelectorAll('.sae-map-picker-list input[type=checkbox]');",
    "  var rows = root.querySelectorAll('tr[data-method]');",
    "  var summary = root.querySelector('.sae-map-picker-summary');",
    "  var empty = root.querySelector('.sae-map-picker-empty');",
    "  var table = root.querySelector('table');",
    "  function update(){",
    "    var on = {}, names = [];",
    "    for (var i = 0; i < boxes.length; i++) if (boxes[i].checked) { on[boxes[i].value] = true; names.push(boxes[i].getAttribute('data-label')); }",
    "    for (var j = 0; j < rows.length; j++) rows[j].style.display = on[rows[j].getAttribute('data-method')] ? '' : 'none';",
    "    summary.textContent = names.length === boxes.length ? 'all (' + names.length + ')' : (names.length ? names.join(', ') : 'none');",
    "    empty.style.display = names.length ? 'none' : '';",
    "    table.style.display = names.length ? '' : 'none';",
    "  }",
    "  function setAll(v){ for (var i = 0; i < boxes.length; i++) boxes[i].checked = v; update(); }",
    "  for (var k = 0; k < boxes.length; k++) boxes[k].addEventListener('change', update);",
    "  root.querySelector('[data-action=all]').addEventListener('click', function(){ setAll(true); });",
    "  root.querySelector('[data-action=none]').addEventListener('click', function(){ setAll(false); });",
    "  document.addEventListener('click', function(e){ if (menu.open && !menu.contains(e.target)) menu.open = false; });",
    "  update();",
    "})();",
    "</script>",
    sep = "\n"
  ), id)
}

# Returns the HTML block as one string, or NULL when the panels are missing.
sae_map_picker_html <- function(panel_dir, id, hint = NULL) {
  man_path <- file.path(panel_dir, "manifest.csv")
  if (!file.exists(man_path)) return(NULL)
  man <- tryCatch(utils::read.csv(man_path, stringsAsFactors = FALSE),
                  error = function(e) NULL)
  need <- c("row", "method", "tag", "year", "file")
  if (is.null(man) || !all(need %in% names(man))) return(NULL)
  if ("saved" %in% names(man)) man <- man[as.logical(man$saved) %in% TRUE, , drop = FALSE]
  man <- man[file.exists(file.path(panel_dir, man$file)), , drop = FALSE]
  if (nrow(man) == 0L) return(NULL)
  man <- man[order(man$row, man$year), , drop = FALSE]
  years   <- sort(unique(man$year))
  methods <- man[!duplicated(man$tag), c("row", "method", "tag"), drop = FALSE]
  methods <- methods[order(methods$row), , drop = FALSE]
  id      <- gsub("[^A-Za-z0-9_-]", "-", id)
  if (is.null(hint)) {
    hint <- paste("Choose the methods to compare. Each row is one method and each",
                  "column one year; all panels share one colour scale.")
  }

  checkboxes <- vapply(seq_len(nrow(methods)), function(i) {
    sprintf("<label><input type=\"checkbox\" value=\"%s\" data-label=\"%s\" checked>%s</label>",
            sae_html_escape(methods$tag[i]), sae_html_escape(methods$method[i]),
            sae_html_escape(methods$method[i]))
  }, character(1))
  header <- paste0("<thead><tr><th></th>",
                   paste0("<th>", sae_html_escape(years), "</th>", collapse = ""),
                   "</tr></thead>")
  body_rows <- vapply(seq_len(nrow(methods)), function(i) {
    cells <- vapply(years, function(y) {
      f <- man$file[man$tag == methods$tag[i] & man$year == y]
      if (length(f) == 0L) return("<td></td>")
      sprintf("<td><img src=\"%s\" alt=\"%s, %s\"></td>",
              knitr::image_uri(file.path(panel_dir, f[1])),
              sae_html_escape(methods$method[i]), sae_html_escape(y))
    }, character(1))
    sprintf("<tr data-method=\"%s\"><th scope=\"row\">%s</th>%s</tr>",
            sae_html_escape(methods$tag[i]), sae_html_escape(methods$method[i]),
            paste(cells, collapse = ""))
  }, character(1))

  legend <- if ("legend" %in% names(man)) man$legend[1] else ""
  legend_html <- if (!is.na(legend) && nzchar(legend) && file.exists(file.path(panel_dir, legend))) {
    sprintf("<div class=\"sae-map-picker-legend\"><img src=\"%s\" alt=\"Colour scale\"></div>",
            knitr::image_uri(file.path(panel_dir, legend)))
  } else ""
  caption <- if ("caption" %in% names(man)) man$caption[1] else ""
  caption_html <- if (!is.na(caption) && nzchar(caption)) {
    sprintf("<p class=\"sae-map-picker-caption\">%s</p>", sae_html_escape(caption))
  } else ""

  paste(
    "<!--sae-html-only-start-->",
    sae_map_picker_css(),
    sprintf("<div class=\"sae-map-picker\" id=\"%s\">", id),
    "<div class=\"sae-map-picker-bar\">",
    "<details class=\"sae-map-picker-menu\">",
    "<summary>Methods: <span class=\"sae-map-picker-summary\">all</span></summary>",
    "<div class=\"sae-map-picker-list\">",
    paste(checkboxes, collapse = "\n"),
    "<div class=\"sae-map-picker-actions\"><button type=\"button\" data-action=\"all\">Select all</button><button type=\"button\" data-action=\"none\">Clear</button></div>",
    "</div>",
    "</details>",
    sprintf("<span class=\"sae-map-picker-hint\">%s</span>", sae_html_escape(hint)),
    "</div>",
    sprintf("<table class=\"sae-map-grid-table\">%s<tbody>%s</tbody></table>",
            header, paste(body_rows, collapse = "")),
    "<p class=\"sae-map-picker-empty\" style=\"display:none\">No method selected. Open the Methods list and tick one or more methods.</p>",
    legend_html,
    caption_html,
    "</div>",
    sae_map_picker_js(id),
    "<!--sae-html-only-end-->",
    sep = "\n"
  )
}

# Markdown for one map family in report.Rmd: the picker for the HTML report
# and the static grid for the Word report (see the header of this file).
# Falls back to the static grid alone when the panels are missing.
sae_map_grid_markdown <- function(grid_path, panel_dir, id, label) {
  static <- sprintf("![%s](%s)\n\n", label, grid_path)
  picker <- tryCatch(sae_map_picker_html(panel_dir, id), error = function(e) NULL)
  if (is.null(picker)) return(static)
  paste0(
    "::: {.sae-html-only}\n\n```{=html}\n", picker, "\n```\n\n:::\n\n",
    "::: {.sae-word-only}\n\n", static, ":::\n\n"
  )
}
