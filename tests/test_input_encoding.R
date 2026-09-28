# ============================================================
# test_input_encoding.R -- text inputs are read completely whatever their encoding
#
# A CSV saved by Excel on Windows is usually Windows-1252/1250 (Latin-1 family),
# not UTF-8. Reading it with fileEncoding = "UTF-8" stops at the first accented
# character and silently returns only the rows before it. The readers must
# return every row for UTF-8, UTF-8 with BOM, Latin-1 and Windows-1250 files,
# keep numbers intact, and strip a UTF-8 byte-order mark from the first column
# name. SAE_INPUT_ENCODING must still force a given source encoding.
#
# Run from the package root:  Rscript tests/test_input_encoding.R
# ============================================================

root <- normalizePath(if (file.exists("app_support.R")) "." else "..",
                      winslash = "/", mustWork = TRUE)
setwd(root)
source(file.path("R", "input_readers.R"))

checks <- 0L
ok <- function(cond, msg) {
  checks <<- checks + 1L
  if (!isTRUE(cond)) stop("FAILED: ", msg, call. = FALSE)
  cat("  ok -", msg, "\n")
}

sandbox <- tempfile("sae_encoding_test_")
dir.create(sandbox)
old_enc <- Sys.getenv("SAE_INPUT_ENCODING", unset = NA)
Sys.unsetenv("SAE_INPUT_ENCODING")
on.exit({
  if (is.na(old_enc)) Sys.unsetenv("SAE_INPUT_ENCODING") else Sys.setenv(SAE_INPUT_ENCODING = old_enc)
  unlink(sandbox, recursive = TRUE, force = TRUE)
}, add = TRUE)

# Rows: an accented name in row 2 of 4, so truncation would drop rows 3-4.
lines_utf8 <- c("prov,name,x", "1,Alava,0.1", "2,Coru\u00f1a,0.2", "3,Leon,0.3", "4,Malaga,0.4")
write_bytes <- function(file, text_lines, to, bom = FALSE, sep = "\n") {
  txt <- paste0(paste(text_lines, collapse = sep), sep)
  raw_txt <- iconv(txt, from = "UTF-8", to = to, toRaw = TRUE)[[1]]
  if (bom) raw_txt <- c(as.raw(c(0xEF, 0xBB, 0xBF)), raw_txt)
  path <- file.path(sandbox, file)
  writeBin(raw_txt, path)
  path
}

# Compare decoded text as UTF-8 bytes, which works in every locale.
utf8_bytes <- function(s) {
  enc <- Encoding(s)
  if (identical(enc, "latin1")) s <- iconv(s, from = "latin1", to = "UTF-8")
  as.integer(charToRaw(s))
}
coruna <- as.integer(c(0x43, 0x6F, 0x72, 0x75, 0xC3, 0xB1, 0x61))

p_utf8   <- write_bytes("utf8.csv", lines_utf8, "UTF-8")
p_bom    <- write_bytes("utf8_bom.csv", lines_utf8, "UTF-8", bom = TRUE)
p_latin1 <- write_bytes("latin1.csv", lines_utf8, "latin1")
p_crlf   <- write_bytes("latin1_crlf.csv", lines_utf8, "latin1", sep = "\r\n")
lines_pl <- c("prov,name,x", "1,Warszawa,0.1", "2,\u0141\u00f3d\u017a,0.2", "3,Krak\u00f3w,0.3", "4,Gda\u0144sk,0.4")
p_cp1250 <- write_bytes("cp1250.csv", lines_pl, "CP1250")
p_tsv    <- write_bytes("latin1.tsv", gsub(",", "\t", lines_utf8), "latin1")
p_dat    <- write_bytes("latin1.dat", gsub(",", ";", lines_utf8), "latin1")

x <- sae_read_table_input(p_utf8, "UTF-8 csv")
ok(nrow(x) == 4L && identical(x$x, c(0.1, 0.2, 0.3, 0.4)), "UTF-8 CSV: all 4 rows and numbers read")
ok(identical(utf8_bytes(x$name[2]), coruna), "UTF-8 CSV: accented name decoded")

x <- sae_read_table_input(p_bom, "UTF-8 BOM csv")
ok(nrow(x) == 4L, "UTF-8 CSV with BOM: all 4 rows read")
ok(identical(names(x)[1], "prov"), "UTF-8 CSV with BOM: BOM removed from the first column name")

x <- withCallingHandlers(
  sae_read_table_input(p_latin1, "Latin-1 csv"),
  warning = function(w) {
    if (grepl("not UTF-8 encoded", conditionMessage(w))) invokeRestart("muffleWarning")
  }
)
ok(nrow(x) == 4L && identical(x$x, c(0.1, 0.2, 0.3, 0.4)), "Latin-1 CSV: all 4 rows read (was 2 with fileEncoding = UTF-8)")
ok(identical(utf8_bytes(x$name[2]), coruna), "Latin-1 CSV: accented name decoded")

warned <- FALSE
x <- withCallingHandlers(
  sae_read_table_input(p_crlf, "Latin-1 CRLF csv"),
  warning = function(w) {
    if (grepl("not UTF-8 encoded", conditionMessage(w))) {
      warned <<- TRUE
      invokeRestart("muffleWarning")
    }
  }
)
ok(nrow(x) == 4L, "Latin-1 CSV with Windows line endings: all 4 rows read")
ok(warned, "Latin-1 CSV: a warning names the encoding problem")

x <- suppressWarnings(sae_read_table_input(p_cp1250, "Windows-1250 csv"))
ok(nrow(x) == 4L && identical(x$x, c(0.1, 0.2, 0.3, 0.4)), "Windows-1250 (Polish) CSV: all 4 rows and numbers read")

x <- suppressWarnings(sae_read_table_input(p_tsv, "Latin-1 tsv"))
ok(nrow(x) == 4L && ncol(x) == 3L, "Latin-1 TSV: all 4 rows read")

x <- suppressWarnings(sae_read_table_input(p_dat, "Latin-1 dat"))
ok(nrow(x) == 4L && ncol(x) == 3L, "Latin-1 semicolon DAT: all 4 rows read")

ok(identical(sae_read_input_names(p_bom), c("prov", "name", "x")), "column names for mapping: BOM removed")
ok(identical(sae_read_input_names(p_latin1), c("prov", "name", "x")), "column names for mapping: Latin-1 file")

Sys.setenv(SAE_INPUT_ENCODING = "latin1")
ok(identical(sae_text_encoding_args(p_latin1), list(fileEncoding = "latin1")),
   "SAE_INPUT_ENCODING override is passed to the reader as fileEncoding")
if (isTRUE(l10n_info()[["UTF-8"]])) {
  # Re-encoding to the session charset only works in a UTF-8 session
  # (Windows R >= 4.2, macOS and most Linux desktops).
  x <- sae_read_table_input(p_latin1, "Latin-1 csv with override")
  ok(nrow(x) == 4L && identical(utf8_bytes(x$name[2]), coruna), "SAE_INPUT_ENCODING override reads the file correctly")
}
Sys.unsetenv("SAE_INPUT_ENCODING")

cat(sprintf("\nAll %d checks passed.\n", checks))
