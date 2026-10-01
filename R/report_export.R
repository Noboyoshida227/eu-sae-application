# Apply portable Word table geometry after Pandoc, which otherwise uses
# percentage widths and inherits paragraph spacing from HTML.
sae_format_word_tables <- function(path) {
  for (pkg in c("xml2", "zip")) {
    if (!requireNamespace(pkg, quietly = TRUE)) stop("Word export requires R package '", pkg, "'. Run install_packages.R.")
  }
  work <- tempfile("sae-word-format-")
  dir.create(work)
  on.exit(unlink(work, recursive = TRUE), add = TRUE)
  zip::unzip(path, exdir = work)
  document <- file.path(work, "word", "document.xml")
  x <- xml2::read_xml(document)
  ns <- c(w = "http://schemas.openxmlformats.org/wordprocessingml/2006/main",
          wp = "http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing")
  find <- function(node, query) xml2::xml_find_all(node, query, ns)
  property <- function(node, tag, attrs = character(), first = FALSE) {
    el <- xml2::xml_find_first(node, paste0("./w:", tag), ns)
    if (inherits(el, "xml_missing")) el <- xml2::xml_add_child(node, paste0("w:", tag), .where = if (first) 0L else length(xml2::xml_children(node)))
    for (key in names(attrs)) xml2::xml_set_attr(el, paste0("w:", key), as.character(attrs[[key]]), ns = ns)
    el
  }
  for (tbl in find(x, "//w:tbl")) {
    rows <- find(tbl, "./w:tr")
    header <- find(rows[[1]], "./w:tc")
    labels <- vapply(header, function(cell) paste(xml2::xml_text(find(cell, ".//w:t")), collapse = ""), character(1))
    n <- length(header)
    if (!n) next
    weights <- rep(1, n)
    if (n == 2L) weights <- if (identical(labels, c("Field", "Value"))) c(.38, .62) else c(.29, .71)
    if (any(tolower(labels) == "formula")) {
      weights <- rep(1, n)
      weights[tolower(labels) == "formula"] <- if (n <= 3L) 5 else 3
    } else if (n > 2L && any(tolower(labels) == "method")) {
      weights[tolower(labels) == "method"] <- 1.65
    }
    widths <- as.integer(round(9360 * weights / sum(weights)))
    widths[n] <- widths[n] + 9360L - sum(widths)
    pr <- property(tbl, "tblPr", first = TRUE)
    property(pr, "tblW", c(w = "9360", type = "dxa"))
    property(pr, "tblInd", c(w = "120", type = "dxa"))
    property(pr, "tblLayout", c(type = "fixed"))
    margins <- property(pr, "tblCellMar")
    for (side in c("top", "bottom", "start", "end")) property(margins, side, c(w = if (side %in% c("top", "bottom")) "60" else "120", type = "dxa"))
    grid <- xml2::xml_find_first(tbl, "./w:tblGrid", ns)
    if (inherits(grid, "xml_missing")) stop("Generated Word table has no column grid.")
    xml2::xml_remove(xml2::xml_children(grid))
    for (width in widths) {
      col <- xml2::xml_add_child(grid, "w:gridCol")
      xml2::xml_set_attr(col, "w:w", as.character(width), ns = ns)
    }
    for (ri in seq_along(rows)) {
      trpr <- property(rows[[ri]], "trPr", first = TRUE)
      property(trpr, "cantSplit")
      if (ri == 1L) property(trpr, "tblHeader")
      cells <- find(rows[[ri]], "./w:tc")
      if (length(cells) != n) stop("Word table has unexpected merged cells.")
      for (ci in seq_along(cells)) {
        cell <- cells[[ci]]
        tcpr <- property(cell, "tcPr", first = TRUE)
        property(tcpr, "tcW", c(w = widths[ci], type = "dxa"))
        property(tcpr, "vAlign", c(val = "center"))
        if (ri == 1L) property(tcpr, "shd", c(fill = "E8EEF5", val = "clear"))
        paragraphs <- find(cell, "./w:p")
        # Pandoc's cell Divs may append empty paragraphs; retain text, fields,
        # drawings, and at least one paragraph even for a truly empty cell.
        for (p in paragraphs) {
          if (length(find(cell, "./w:p")) > 1L &&
              !length(find(p, ".//w:t|.//w:drawing|.//w:fldChar|.//w:instrText"))) xml2::xml_remove(p)
        }
        for (p in find(cell, "./w:p")) {
          pp <- property(p, "pPr", first = TRUE)
          property(pp, "pStyle", c(val = "TableText"), first = TRUE)
          property(pp, "spacing", c(before = "0", after = "40", line = "252", lineRule = "auto"))
          property(pp, "keepNext", c(val = if (length(rows) <= 6L && ri < length(rows)) "1" else "0"))
          property(pp, "jc", c(val = if (tolower(labels[ci]) %in% c("domain", "year")) "center" else "left"))
        }
      }
    }
  }
  for (p in find(x, "//w:body/w:p[.//w:drawing]")) {
    following <- xml2::xml_find_first(p, "following-sibling::*[1]", ns)
    style <- xml2::xml_find_first(following, "./w:pPr/w:pStyle", ns)
    alternative <- xml2::xml_attr(xml2::xml_find_first(p, ".//wp:docPr", ns), "descr")
    following_text <- paste(xml2::xml_text(find(following, ".//w:t")), collapse="")
    is_caption <- !inherits(style, "xml_missing") && xml2::xml_attr(style, "w:val", ns) == "ImageCaption"
    # knitr emits an ordinary paragraph with the same text as image alt text.
    is_caption <- is_caption || (!is.na(alternative) && nzchar(alternative) && identical(alternative, following_text))
    if (is_caption) {
      property(property(p, "pPr", first=TRUE), "keepNext", c(val="1"))
      property(property(following, "pPr", first=TRUE), "pStyle", c(val="ImageCaption"), first=TRUE)
    }
  }
  xml2::write_xml(x, document)
  rebuilt <- tempfile("sae-word-", fileext = ".docx")
  on.exit(unlink(rebuilt), add = TRUE)
  zip::zipr(rebuilt, files = list.files(work, recursive = TRUE, all.files = TRUE), root = work, include_directories = FALSE, mode = "mirror")
  if (!file.copy(rebuilt, path, overwrite = TRUE)) stop("Cannot finalize Word table formatting.")
  invisible(path)
}

# Remove the parts between <!--sae-html-only-start--> and
# <!--sae-html-only-end--> from `txt` (a byte string).
sae_strip_html_only_text <- function(txt) {
  start_tag <- "<!--sae-html-only-start-->"
  end_tag   <- "<!--sae-html-only-end-->"
  starts <- gregexpr(start_tag, txt, fixed = TRUE, useBytes = TRUE)[[1]]
  if (starts[1] < 0) return(txt)
  ends <- gregexpr(end_tag, txt, fixed = TRUE, useBytes = TRUE)[[1]]
  keep <- character(0)
  pos <- 1L
  for (st in starts) {
    if (st < pos) next
    en <- ends[ends > st]
    if (length(en) == 0L) break          # unterminated block: keep the rest
    keep <- c(keep, substr(txt, pos, st - 1L))
    pos <- en[1] + nchar(end_tag, type = "bytes")
  }
  keep <- c(keep, substr(txt, pos, nchar(txt, type = "bytes")))
  out <- paste(keep, collapse = "")
  Encoding(out) <- "bytes"
  out
}

.sae_base64_decode <- function(x) {
  if (requireNamespace("base64enc", quietly = TRUE)) return(base64enc::base64decode(x))
  if (requireNamespace("jsonlite", quietly = TRUE)) return(jsonlite::base64_dec(x))
  stop("The base64enc or jsonlite package is needed to prepare the Word report.")
}

# The source Pandoc reads for the Word report: a temporary copy of the
# self-contained HTML report, written next to it, with
#   * the HTML-only blocks removed (the map method picker), and
#   * every embedded image (src="data:image/...;base64,...") written to a
#     temporary folder and referenced by file name.
# Pandoc's HTML reader needs several GB of memory for the base64 images of
# a typical report (about 4 GB with Pandoc 3.11 and 6 GB with 2.17 on the
# Spain example); with the images as files it needs about 0.5 GB, and the
# Word file is the same. The original HTML is not modified. Returns
# list(html, assets) for the caller to delete.
sae_prepare_word_source <- function(html_path) {
  bytes <- readBin(html_path, "raw", n = file.info(html_path)$size)
  txt <- rawToChar(bytes)
  Encoding(txt) <- "bytes"             # positions are byte offsets
  txt <- sae_strip_html_only_text(txt)
  assets <- tempfile("word-assets-", tmpdir = dirname(html_path))
  pattern <- 'src="data:image/([A-Za-z0-9.+-]+);base64,([A-Za-z0-9+/=[:space:]]+)"'
  m <- gregexpr(pattern, txt, perl = TRUE, useBytes = TRUE)
  hits <- regmatches(txt, m)[[1]]
  if (length(hits) > 0L) {
    dir.create(assets, showWarnings = FALSE)
    ext_of <- c("png" = "png", "jpeg" = "jpg", "jpg" = "jpg", "gif" = "gif",
                "svg+xml" = "svg", "webp" = "webp")
    repl <- vapply(seq_along(hits), function(i) {
      parts <- regmatches(hits[i], regexec(pattern, hits[i], perl = TRUE, useBytes = TRUE))[[1]]
      ext <- if (tolower(parts[2]) %in% names(ext_of)) ext_of[[tolower(parts[2])]] else "img"
      name <- sprintf("img%04d.%s", i, ext)
      writeBin(.sae_base64_decode(gsub("[[:space:]]", "", parts[3])), file.path(assets, name))
      sprintf('src="%s/%s"', basename(assets), name)
    }, character(1))
    regmatches(txt, m) <- list(repl)
  }
  out <- tempfile("word-source-", tmpdir = dirname(html_path), fileext = ".html")
  con <- file(out, open = "wb")
  on.exit(close(con), add = TRUE)
  writeBin(charToRaw(txt), con)
  list(html = out, assets = assets)
}

# Minimum Pandoc for the Word report: its Lua filter uses pandoc.Inlines.
sae_word_min_pandoc <- "2.17"

# Word is derived from the completed HTML: no statistical or AI calls are rerun.
sae_render_word_report <- function(html_path = "outputs/final_report.html",
                                    output_path = "outputs/final_report.docx",
                                    root = getwd()) {
  if (!file.exists(html_path)) stop("HTML report not found: ", html_path)
  reference <- file.path(root, "docs", "report_reference.docx")
  filter <- file.path(root, "R", "report_word.lua")
  if (!file.exists(reference) || !file.exists(filter)) stop("Word report template/filter is missing from the package.")
  if (!rmarkdown::pandoc_available()) stop("Pandoc is required for the Word report.")
  pv <- rmarkdown::pandoc_version()
  if (pv < numeric_version(sae_word_min_pandoc)) {
    stop(sprintf(paste(
      "Pandoc %s is too old for the Word report, which needs Pandoc %s or later",
      "(the HTML report is not affected). Install a newer Pandoc, or let the app",
      "download its own copy, and render the report again."), pv, sae_word_min_pandoc))
  }
  html_path <- normalizePath(html_path, winslash = "/", mustWork = TRUE)
  # Pandoc reads a prepared copy: HTML-only blocks removed, embedded images
  # written to files (see sae_prepare_word_source()). The original HTML is
  # not modified.
  src <- sae_prepare_word_source(html_path)
  html_source <- src$html
  on.exit(unlink(c(src$html, src$assets), recursive = TRUE), add = TRUE)
  # pandoc_convert temporarily changes its working directory; resolve all
  # paths and options before entering it (R arguments are evaluated lazily).
  options <- c("--standalone",
               paste0("--reference-doc=", normalizePath(reference, winslash = "/")),
               paste0("--lua-filter=", normalizePath(filter, winslash = "/")),
               paste0("--resource-path=", dirname(html_path)))
  # A temporary output prevents an interrupted conversion from leaving a
  # truncated DOCX. The final path is installed only after ZIP validation.
  dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
  output_path <- file.path(normalizePath(dirname(output_path), winslash = "/", mustWork = TRUE), basename(output_path))
  temporary <- tempfile("word-report-", tmpdir = dirname(output_path), fileext = ".docx")
  on.exit(unlink(temporary), add = TRUE)
  rmarkdown::pandoc_convert(
    input = html_source,
    from = "html", to = "docx", output = temporary,
    options = options,
    verbose = FALSE
  )
  sae_format_word_tables(temporary)
  parts <- utils::unzip(temporary, list = TRUE)$Name
  if (!all(c("[Content_Types].xml", "word/document.xml") %in% parts)) stop("Generated Word file is not a valid DOCX package.")
  if (!file.copy(temporary, output_path, overwrite = TRUE)) stop("Cannot save Word report: ", output_path)
  invisible(normalizePath(output_path, winslash = "/", mustWork = TRUE))
}
