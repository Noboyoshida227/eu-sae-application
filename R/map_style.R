# ============================================================
# map_style.R -- one colour scheme for every map in the pipeline
# ============================================================
#
# Every choropleth written by 01_ufh.R, 02_mfh.R and 03_comparison.R takes
# its fill scale from here, so the scheme is defined in exactly one place.
#
#   Level maps  (poverty rates, RMSE, mean welfare in EUR, any quantity
#               where "more" simply means "more"):
#               reversed magma -- light (pale yellow) = low, dark = high.
#
#   Change maps (later year minus earlier year, growth rates, anything
#               with a meaningful zero):
#               diverging blue - light grey - red centred on zero --
#               blue = decrease, light grey = no change, red = increase.
#
#   Domains without a value are drawn in light grey in both cases.
#
#   Maps of one kind (all poverty maps, all RMSE maps, all change maps) share
#   one legend range computed with sae_shared_limits(), so a colour can be
#   compared across methods and years.
#
# The helpers return ggplot2 scale objects and accept the usual scale
# arguments (`limits`, `labels`, `oob`, `breaks`, ...) through `...`.
# ggplot2 is loaded lazily via `::` so this file can be sourced anywhere.

sae_map_na_colour <- "grey90"

sae_map_level_palette <- function(n = 5) {
  # Same colours as sae_fill_level(), for callers that need discrete swatches
  # (e.g. a legend drawn by hand). Light to dark.
  if (!requireNamespace("viridisLite", quietly = TRUE)) {
    return(grDevices::colorRampPalette(c("#FCFDBF", "#B63679", "#000004"))(n))
  }
  viridisLite::viridis(n, option = "magma", direction = -1)
}

sae_fill_level <- function(name = ggplot2::waiver(), ...) {
  ggplot2::scale_fill_viridis_c(
    option    = "magma",
    direction = -1,
    name      = name,
    na.value  = sae_map_na_colour,
    ...
  )
}

# Currency legends need room for thousands separators. Put the title above
# the bar so a long indicator name cannot squeeze the ticks together. Only
# presentation changes: values, limits and the shared level palette are kept.
sae_fill_welfare <- function(name = "Mean welfare (EUR)", horizontal = TRUE, ...) {
  sae_fill_level(
    name = name,
    labels = scales::label_number(accuracy = 1, big.mark = ","),
    breaks = scales::breaks_pretty(n = 4),
    guide = ggplot2::guide_colourbar(
      direction = if (horizontal) "horizontal" else "vertical",
      title.position = "top",
      barwidth = grid::unit(if (horizontal) 12 else 0.5, "cm"),
      barheight = grid::unit(if (horizontal) 0.45 else 4, "cm")
    ),
    ...
  )
}

sae_fill_change <- function(name = "Change", ...) {
  ggplot2::scale_fill_gradient2(
    low      = "#2c7bb6",
    mid      = "#D0D0D0",
    high     = "#d7191c",
    midpoint = 0,
    name     = name,
    na.value = sae_map_na_colour,
    ...
  )
}

# One value range for a whole family of maps, so that the same colour means
# the same value on every map of that kind (all methods, both years). `cols`
# are the columns of `df` whose values are mapped; columns that do not exist
# are ignored. With `symmetric = TRUE` the range is centred on zero (change
# maps). Returns NULL when there is nothing finite to map, which lets the
# scale fall back to its own default.
sae_shared_limits <- function(df, cols, symmetric = FALSE) {
  cols <- intersect(as.character(cols), names(df))
  if (length(cols) == 0L) return(NULL)
  v <- suppressWarnings(as.numeric(unlist(lapply(cols, function(col) df[[col]]), use.names = FALSE)))
  v <- v[is.finite(v)]
  if (length(v) == 0L) return(NULL)
  if (isTRUE(symmetric)) {
    m <- max(abs(v))
    if (m <= 0) m <- 1e-6
    return(c(-m, m))
  }
  r <- range(v)
  if (r[1] == r[2]) r <- r + c(-1, 1) * max(abs(r[1]) * 0.05, 1e-6)
  r
}

# Common map theme: no axes or grid, legend at the bottom unless overridden.
sae_map_theme <- function(base_size = 16, legend.position = "bottom") {
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      legend.position = legend.position,
      axis.text       = ggplot2::element_blank(),
      axis.ticks      = ggplot2::element_blank(),
      panel.grid      = ggplot2::element_blank()
    )
}

# One-sentence descriptions for captions and the report, kept next to the
# scales so that text and colours cannot drift apart.
sae_map_legend_note <- function(kind = c("level", "change")) {
  kind <- match.arg(kind)
  switch(kind,
    level  = "Lighter colours indicate lower values and darker colours higher values; domains without an estimate are grey.",
    change = "Blue indicates a decrease, light grey no change and red an increase; domains without an estimate are a paler grey."
  )
}
