# ============================================================
# tools/make_cover_map.R -- regenerate www/cover_map_spain.png
#
# The landing-page illustration of both interfaces and the cover of the slide
# guide. It is drawn by the package's own map style (R/map_style.R) from a
# completed run of the bundled Spain example:
#   * estimates: benchmarked MFH poverty rates, 2013, from that run's
#     outputs/data/pov_comparison_detailed.xlsx (the Spain survey and
#     auxiliary files are synthetic, derived from the R package sae, GPL-2);
#   * boundaries: Data/Spain/shapefile.rds (IGN/CNIG CartoBase ANE, CC BY 4.0).
#     The required IGN credit is printed on the image.
# The Canary Islands are moved into an inset box for display only.
#
# Usage, from the package root (needs sf, ggplot2, readxl, scales):
#   Rscript tools/make_cover_map.R app_runs/<run>/outputs/data/pov_comparison_detailed.xlsx
# ============================================================

suppressPackageStartupMessages({
  library(sf); library(ggplot2); library(readxl)
})
source("R/map_style.R")
sf_use_s2(FALSE)

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) stop("Give the path to a Spain run's pov_comparison_detailed.xlsx")
xlsx <- args[1]
out  <- if (length(args) >= 2) args[2] else "www/cover_map_spain.png"

d <- as.data.frame(read_excel(xlsx))
d <- d[d$year == 2013, c("domain", "MFH_Bench")]
g <- readRDS("Data/Spain/shapefile.rds")
credit <- attr(g, "boundary_attribution")
if (!is.character(credit) || !nzchar(credit)) stop("Boundary file has no IGN attribution metadata")
g$prov <- as.character(g$prov)
m <- merge(g, d, by.x = "prov", by.y = "domain", all.x = TRUE)
stopifnot(nrow(m) == 52, !anyNA(m$MFH_Bench))

lat <- st_coordinates(suppressWarnings(st_centroid(st_geometry(m))))[, 2]
can <- lat < 30                                   # Las Palmas, Santa Cruz de Tenerife
geom <- st_geometry(m)
geom[can] <- geom[can] + c(5, 7)                  # display-only inset position
st_geometry(m) <- st_set_crs(geom, 4326)
m <- st_transform(m, 3035)
box <- st_as_sfc(st_bbox(st_buffer(st_union(m[can, ]), 25000)))

p <- ggplot(m) +
  geom_sf(aes(fill = MFH_Bench), colour = "white", linewidth = 0.15) +
  geom_sf(data = st_sf(geometry = box), fill = NA, colour = "grey55", linewidth = 0.3) +
  sae_fill_level(name = "Poverty rate, 2013 (MFH, benchmarked)",
                 labels = scales::label_percent(accuracy = 1),
                 guide = guide_colourbar(title.position = "top", barwidth = unit(60, "mm"),
                                         barheight = unit(3.6, "mm"))) +
  labs(caption = paste0("Spain example (synthetic data derived from the R package sae)\n",
                        "Boundaries: ", credit)) +
  theme_void(base_size = 11) +
  theme(plot.background = element_rect(fill = "#eef3f8", colour = NA),
        legend.position = "bottom",
        legend.title = element_text(size = 11, colour = "grey20"),
        legend.text = element_text(size = 10, colour = "grey25"),
        plot.caption = element_text(size = 10, colour = "grey25", hjust = 0.5, lineheight = 1.1),
        plot.margin = margin(14, 14, 10, 14))
ggsave(out, p, width = 6.8, height = 5.0, dpi = 200, bg = "#eef3f8")
cat("wrote", out, "\n")
