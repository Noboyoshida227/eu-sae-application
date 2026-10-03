# ============================================================
# report_map_picker.R -- method pickers for the HTML report: the map grids
# and the box plots of changes and their RMSEs (second half of this file)
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

# ---- Box plots of changes and their RMSEs, with a Methods list --------------
# The Comparison step writes outputs/tables/change_rmse_by_method.csv: one row
# per domain and method (Direct, UFH, UFH benchmarked, the MFH model, MFH
# benchmarked) with the change between the two years and the RMSE of that
# change, the method colour (sae_method_colors(), R/change_comparison.R) and
# the panel titles. sae_box_picker_html() embeds those values as
# JSON and draws two box plots side by side in one row (the change, then its
# RMSE) as inline SVG, one box per ticked method. Each point is one domain
# (hover for its name and value); boxes show the median and interquartile
# range and whiskers reach the most extreme value within 1.5 times the
# interquartile range (as ggplot2::geom_boxplot). The vertical axes are fitted
# to the methods shown, so dropping, say, the direct estimates zooms in on the
# model-based ones. The Word report shows the static change_rmse_boxplots.png
# instead (sae_box_picker_markdown()).

sae_box_picker_css <- function() {
  paste(
    "<style>",
    ".sae-box-row{display:flex;flex-wrap:wrap;gap:0.8em 1.6em;align-items:flex-start;}",
    ".sae-box-panel{flex:1 1 300px;min-width:280px;}",
    ".sae-box-title{font-weight:700;font-size:0.98em;margin:0 0 0.2em 0;color:#0b0b0b;}",
    ".sae-box-panel svg{width:100%;height:auto;display:block;overflow:visible;}",
    ".sae-box-panel svg text{font-family:inherit;}",
    ".sae-box-note{color:#52514e;font-size:0.88em;margin-top:0.4em;}",
    "</style>",
    sep = "\n"
  )
}

sae_box_picker_js <- function(id) {
  js <- paste(
    "<script>",
    "(function(){",
    "  var root = document.getElementById('@ID@'); if (!root) return;",
    "  var src = document.getElementById('@ID@-data'); if (!src) return;",
    "  var data = JSON.parse(src.textContent);",
    "  var NS = 'http://www.w3.org/2000/svg';",
    "  var menu = root.querySelector('details');",
    "  var boxes = root.querySelectorAll('.sae-map-picker-list input[type=checkbox]');",
    "  var summary = root.querySelector('.sae-map-picker-summary');",
    "  var empty = root.querySelector('.sae-map-picker-empty');",
    "  var row = root.querySelector('.sae-box-row');",
    "  function el(name, attrs, parent, text){",
    "    var e = document.createElementNS(NS, name);",
    "    for (var k in attrs) if (attrs.hasOwnProperty(k)) e.setAttribute(k, attrs[k]);",
    "    if (text !== undefined) e.textContent = text;",
    "    if (parent) parent.appendChild(e);",
    "    return e;",
    "  }",
    "  function quantile(s, p){ var h = (s.length - 1) * p, lo = Math.floor(h), hi = Math.ceil(h); return s[lo] + (h - lo) * (s[hi] - s[lo]); }",
    "  function boxStats(v){",
    "    var s = v.slice().sort(function(a, b){ return a - b; });",
    "    var q1 = quantile(s, 0.25), q3 = quantile(s, 0.75), iqr = q3 - q1, i;",
    "    var wl = s[0], wh = s[s.length - 1];",
    "    for (i = 0; i < s.length; i++) if (s[i] >= q1 - 1.5 * iqr) { wl = s[i]; break; }",
    "    for (i = s.length - 1; i >= 0; i--) if (s[i] <= q3 + 1.5 * iqr) { wh = s[i]; break; }",
    "    return {q1: q1, med: quantile(s, 0.5), q3: q3, wl: wl, wh: wh, n: s.length};",
    "  }",
    "  function niceStep(span){",
    "    var raw = span / 6, mag = Math.pow(10, Math.floor(Math.log(raw) / Math.LN10)), r = raw / mag;",
    "    return (r <= 1 ? 1 : r <= 2 ? 2 : r <= 2.5 ? 2.5 : r <= 5 ? 5 : 10) * mag;",
    "  }",
    "  function decimals(step){ var d = 0; while (d < 8 && Math.abs(Math.round(step * Math.pow(10, d)) - step * Math.pow(10, d)) > 1e-7) d++; return d; }",
    "  function fmt(v, d){ var s = v.toFixed(d); return /^-0(\\.0*)?$/.test(s) ? s.slice(1) : s; }",
    "  function jitter(i, j){ var x = Math.sin((j + 1) * 12.9898 + (i + 1) * 78.233) * 43758.5453; return 2 * (x - Math.floor(x)) - 1; }",
    "  function values(key, measure){",
    "    var p = data.points[key], out = [];",
    "    for (var j = 0; j < p.name.length; j++) { var v = p[measure][j]; if (v !== null && isFinite(v)) out.push({n: p.name[j], v: v}); }",
    "    return out;",
    "  }",
    "  function draw(panel, svg, keys){",
    "    while (svg.firstChild) svg.removeChild(svg.firstChild);",
    "    var W = 480, H = 360, L = 58, R = 10, T = 12, B = 58;",
    "    svg.setAttribute('viewBox', '0 0 ' + W + ' ' + H);",
    "    var sets = [], all = [], i, j;",
    "    for (i = 0; i < keys.length; i++) { var vs = values(keys[i], panel.key); sets.push(vs); for (j = 0; j < vs.length; j++) all.push(vs[j].v); }",
    "    if (!all.length) { el('text', {x: W / 2, y: H / 2, 'text-anchor': 'middle', 'font-size': 14, fill: '#52514e'}, svg, 'No values for the selected methods'); return; }",
    "    var lo = Math.min.apply(null, all), hi = Math.max.apply(null, all);",
    "    if (panel.zero || panel.from_zero) { lo = Math.min(lo, 0); hi = Math.max(hi, 0); }",
    "    var span = hi - lo; if (!(span > 0)) span = Math.abs(hi) || 1;",
    "    var step = niceStep(span), pad = 0.04 * span, y0 = lo - pad, y1 = hi + pad;",
    "    if (panel.from_zero && lo >= 0) y0 = 0;",
    "    var dec = decimals(step);",
    "    function y(v){ return T + (y1 - v) / (y1 - y0) * (H - T - B); }",
    "    var grid = el('g', {}, svg);",
    "    for (var t = Math.ceil(y0 / step - 1e-9) * step; t <= y1 + 1e-9 * step; t += step) {",
    "      el('line', {x1: L, x2: W - R, y1: y(t), y2: y(t), stroke: '#e6e5e0', 'stroke-width': 1}, grid);",
    "      el('text', {x: L - 8, y: y(t) + 4.5, 'text-anchor': 'end', 'font-size': 13.5, fill: '#52514e'}, grid, fmt(t, dec));",
    "    }",
    "    if (panel.zero && y0 < 0 && y1 > 0) el('line', {x1: L, x2: W - R, y1: y(0), y2: y(0), stroke: '#64748B', 'stroke-width': 1.2, 'stroke-dasharray': '5 4'}, svg);",
    "    var band = (W - L - R) / keys.length, bw = Math.min(band * 0.5, 54);",
    "    for (i = 0; i < keys.length; i++) {",
    "      var m = data.methods[keys[i]], cx = L + band * (i + 0.5), vs2 = sets[i], g = el('g', {}, svg);",
    "      var label = m.label.split(' benchmarked');",
    "      el('text', {x: cx, y: H - B + 22, 'text-anchor': 'middle', 'font-size': 14.5, fill: '#0b0b0b'}, g, label[0]);",
    "      if (label.length > 1) el('text', {x: cx, y: H - B + 40, 'text-anchor': 'middle', 'font-size': 14.5, fill: '#0b0b0b'}, g, 'benchmarked');",
    "      if (!vs2.length) continue;",
    "      var st = boxStats(vs2.map(function(o){ return o.v; }));",
    "      var tip = m.label + ': median ' + fmt(st.med, dec + 1) + ', interquartile range ' + fmt(st.q1, dec + 1) + ' to ' + fmt(st.q3, dec + 1) + ', ' + st.n + ' domains';",
    "      el('line', {x1: cx, x2: cx, y1: y(st.wh), y2: y(st.q3), stroke: m.color, 'stroke-width': 1.5}, g);",
    "      el('line', {x1: cx, x2: cx, y1: y(st.q1), y2: y(st.wl), stroke: m.color, 'stroke-width': 1.5}, g);",
    "      el('line', {x1: cx - bw * 0.22, x2: cx + bw * 0.22, y1: y(st.wh), y2: y(st.wh), stroke: m.color, 'stroke-width': 1.5}, g);",
    "      el('line', {x1: cx - bw * 0.22, x2: cx + bw * 0.22, y1: y(st.wl), y2: y(st.wl), stroke: m.color, 'stroke-width': 1.5}, g);",
    "      var rect = el('rect', {x: cx - bw / 2, y: y(st.q3), width: bw, height: Math.max(1, y(st.q1) - y(st.q3)), rx: 2, fill: m.color, 'fill-opacity': 0.14, stroke: m.color, 'stroke-width': 1.5}, g);",
    "      el('title', {}, rect, tip);",
    "      for (j = 0; j < vs2.length; j++) {",
    "        var c = el('circle', {cx: cx + jitter(i, j) * bw * 0.34, cy: y(vs2[j].v), r: 3.6, fill: m.color, 'fill-opacity': 0.6, stroke: '#ffffff', 'stroke-width': 1}, g);",
    "        el('title', {}, c, vs2[j].n + ': ' + fmt(vs2[j].v, dec + 2));",
    "      }",
    "      var med = el('line', {x1: cx - bw / 2, x2: cx + bw / 2, y1: y(st.med), y2: y(st.med), stroke: m.color, 'stroke-width': 2.6}, g);",
    "      el('title', {}, med, tip);",
    "    }",
    "  }",
    "  function update(){",
    "    var keys = [], names = [];",
    "    for (var i = 0; i < boxes.length; i++) if (boxes[i].checked) { keys.push(boxes[i].value); names.push(boxes[i].getAttribute('data-label')); }",
    "    summary.textContent = names.length === boxes.length ? 'all (' + names.length + ')' : (names.length ? names.join(', ') : 'none');",
    "    empty.style.display = names.length ? 'none' : '';",
    "    row.style.display = names.length ? '' : 'none';",
    "    if (!names.length) return;",
    "    for (var p = 0; p < data.panels.length; p++) draw(data.panels[p], root.querySelector('svg[data-panel=' + data.panels[p].key + ']'), keys);",
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
  )
  gsub("@ID@", id, js, fixed = TRUE)
}

# Returns the HTML block as one string, or NULL when the data are missing.
sae_box_picker_html <- function(csv_path, id, hint = NULL) {
  if (!file.exists(csv_path)) return(NULL)
  d <- tryCatch(utils::read.csv(csv_path, stringsAsFactors = FALSE, encoding = "UTF-8"),
                error = function(e) NULL)
  need <- c("domain", "method_key", "method", "change", "rmse", "change_label", "rmse_label")
  if (is.null(d) || !nrow(d) || !all(need %in% names(d))) return(NULL)
  if (!"name" %in% names(d)) d$name <- d$domain
  if (!"method_order" %in% names(d)) d$method_order <- match(d$method_key, unique(d$method_key))
  d$change <- suppressWarnings(as.numeric(d$change))
  d$rmse <- suppressWarnings(as.numeric(d$rmse))
  d <- d[is.finite(d$change) | is.finite(d$rmse), , drop = FALSE]
  if (!nrow(d)) return(NULL)
  if (!"color" %in% names(d)) d$color <- NA_character_
  meth <- d[order(d$method_order), c("method_key", "method", "color")]
  meth <- meth[!duplicated(meth$method_key), , drop = FALSE]
  id <- gsub("[^A-Za-z0-9_-]", "-", id)
  num <- function(x) lapply(x, function(v) if (is.finite(v)) signif(v, 10) else NULL)
  points <- lapply(meth$method_key, function(k) {
    s <- d[d$method_key == k, , drop = FALSE]
    list(name = as.list(as.character(s$name)), change = num(s$change), rmse = num(s$rmse))
  })
  names(points) <- meth$method_key
  methods <- lapply(seq_len(nrow(meth)), function(i) {
    col <- meth$color[i]
    list(label = meth$method[i],
         color = if (is.na(col) || !grepl("^#[0-9A-Fa-f]{6}$", col)) "#52514e" else col)
  })
  names(methods) <- meth$method_key
  payload <- list(
    methods = methods,
    panels = list(list(key = "change", zero = TRUE, from_zero = FALSE),
                  list(key = "rmse", zero = FALSE, from_zero = TRUE)),
    points = points)
  json <- jsonlite::toJSON(payload, auto_unbox = TRUE, null = "null", digits = NA)
  json <- gsub("</", "<\\/", json, fixed = TRUE)
  if (is.null(hint)) {
    hint <- paste("Choose the methods to compare. Each point is one domain (hover for its",
                  "name); the axes fit the methods shown.")
  }
  checkboxes <- vapply(seq_len(nrow(meth)), function(i) {
    sprintf("<label><input type=\"checkbox\" value=\"%s\" data-label=\"%s\" checked>%s</label>",
            sae_html_escape(meth$method_key[i]), sae_html_escape(meth$method[i]),
            sae_html_escape(meth$method[i]))
  }, character(1))
  panel_html <- function(key, title) {
    sprintf("<div class=\"sae-box-panel\"><p class=\"sae-box-title\">%s</p><svg data-panel=\"%s\" role=\"img\" aria-label=\"%s\"></svg></div>",
            sae_html_escape(title), key, sae_html_escape(title))
  }
  paste(
    "<!--sae-html-only-start-->",
    sae_map_picker_css(),
    sae_box_picker_css(),
    sprintf("<div class=\"sae-map-picker sae-box-picker\" id=\"%s\">", id),
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
    "<div class=\"sae-box-row\">",
    panel_html("change", d$change_label[1]),
    panel_html("rmse", d$rmse_label[1]),
    "</div>",
    "<p class=\"sae-map-picker-empty\" style=\"display:none\">No method selected. Open the Methods list and tick one or more methods.</p>",
    "<p class=\"sae-box-note\">Each point is one domain. Boxes show the median and interquartile range; whiskers reach the most extreme value within 1.5 times the interquartile range.</p>",
    "</div>",
    sprintf("<script type=\"application/json\" id=\"%s-data\">%s</script>", id, json),
    sae_box_picker_js(id),
    "<!--sae-html-only-end-->",
    sep = "\n"
  )
}

# Markdown for report.Rmd: the box plots with a Methods list for the HTML
# report and the static figure for the Word report. Falls back to the static
# figure alone when the data are missing.
sae_box_picker_markdown <- function(csv_path, static_path, id, label) {
  static <- if (file.exists(static_path)) sprintf("![%s](%s)\n\n", label, static_path) else ""
  picker <- tryCatch(sae_box_picker_html(csv_path, id), error = function(e) NULL)
  if (is.null(picker)) return(static)
  paste0(
    "::: {.sae-html-only}\n\n```{=html}\n", picker, "\n```\n\n:::\n\n",
    if (nzchar(static)) paste0("::: {.sae-word-only}\n\n", static, ":::\n\n") else ""
  )
}
