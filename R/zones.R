# Zone polygons: LSOA (2021, England & Wales) / Data Zone (2022, Scotland).
#
# Two versions, for two different jobs.
#
# WIDENED (ensure_zones), used for the published trips-per-zone outputs.
# Construction (identical to TransportBlackspots scripts/Cenus2021-rerun/
# bounds_2021.R): LSOAs smaller than the area of a 500 m-radius circle are
# unioned with a 500 m buffer of their population-weighted centroid, so a
# stop just outside a small urban LSOA still counts; large rural LSOAs keep
# their full boundary. Everything is then buffered a further 100 m to catch
# stops digitised just off the coast. This is what the frequency measure is
# meant to capture - the service a resident can actually reach - and it is
# the form the published outputs use.
#
# PLAIN (ensure_plain_zones), used for the source comparison and the
# zone-level gap analysis. The widening makes the zones overlap, so one stop
# falls in several and a difference between two sources at that stop is
# counted several times over. Those analyses are asking how far two sources
# disagree, not what a resident can reach, and the double counting only
# spreads and inflates the disagreement. Unmodified boundaries tile the
# country, so each stop lands in exactly one zone and each difference is
# counted once.

#' Make sure the zone file exists inside this repo, and return its path
#'
#' Prefers, in order: (1) the copy already cached in input/; (2) copying the
#' identical file from the TransportBlackspots checkout (this is the exact
#' file used to produce the published outputs, so results are bit-for-bit
#' reproducible); (3) rebuilding from the PlaceBasedCarbonCalculator inputs.
ensure_zones <- function(cfg = load_cfg()) {
  dest <- file.path(cfg$input_dir, "GB_LSOA_2021_22_full_or_500mBuff.Rds")
  if (file.exists(dest)) {
    return(dest)
  }
  dir.create(cfg$input_dir, showWarnings = FALSE, recursive = TRUE)

  tb_copy <- file.path(cfg$tb_repo, "data",
                       "GB_LSOA_2021_22_full_or_500mBuff.Rds")
  if (file.exists(tb_copy)) {
    message("Copying zone polygons from TransportBlackspots checkout")
    file.copy(tb_copy, dest)
    return(dest)
  }

  message("Building zone polygons from PlaceBasedCarbonCalculator inputs")
  zones <- build_zones(cfg)
  saveRDS(zones, dest)
  dest
}

#' Make sure the plain zone file exists inside this repo, and return its path
#'
#' The unmodified LSOA21/DZ22 boundaries, straight from the
#' PlaceBasedCarbonCalculator build. They are the input the widened zones are
#' built from, so both versions cover the same 43,064 areas with the same
#' codes and differ only in shape.
#'
#' There is no equivalent of the TransportBlackspots copy to fall back on -
#' that repo only holds the widened file - so the build inputs are required.
ensure_plain_zones <- function(cfg = load_cfg()) {
  dest <- file.path(cfg$input_dir, "GB_LSOA_2021_22_plain.Rds")
  if (file.exists(dest)) {
    return(dest)
  }
  dir.create(cfg$input_dir, showWarnings = FALSE, recursive = TRUE)
  message("Caching plain zone polygons from the PlaceBasedCarbonCalculator build")
  saveRDS(read_plain_lsoa(cfg), dest)
  dest
}

#' The unmodified LSOA21 / DZ22 boundaries (EPSG:27700)
read_plain_lsoa <- function(cfg = load_cfg()) {
  src <- file.path(cfg$pbcc_build, "_targets/objects/bounds_lsoa_GB_full")
  if (!file.exists(src)) {
    stop("Plain LSOA/Data Zone boundaries not found at ", src,
         ". Set cfg$pbcc_build to a PlaceBasedCarbonCalculator build with the ",
         "bounds_lsoa_GB_full target built.")
  }
  readRDS(src)
}

#' Build the widened zone polygons from PlaceBasedCarbonCalculator inputs
build_zones <- function(cfg = load_cfg()) {
  lsoa <- read_plain_lsoa(cfg)
  cents_ew <- sf::read_sf(file.path(
    cfg$pbcc_input, "boundaries",
    "LSOA_Dec_2021_PWC_for_England_and_Wales_2022_-7410472461544737417.gpkg"))
  cents_s <- readRDS(file.path(cfg$pbcc_build,
                               "_targets/objects/centroids_dz22"))

  cents_ew <- cents_ew[, c("LSOA21CD", "SHAPE")]
  names(cents_ew) <- c("LSOA21CD", "geometry")
  sf::st_geometry(cents_ew) <- "geometry"
  cents_s <- cents_s[, c("LSOA21CD", "geometry")]
  cents <- rbind(cents_ew, cents_s)

  lsoa <- lsoa[order(lsoa$LSOA21CD), ]
  cents <- cents[order(cents$LSOA21CD), ]
  if (!identical(lsoa$LSOA21CD, cents$LSOA21CD)) {
    stop("LSOA boundary and centroid codes don't match")
  }

  lsoa$area <- as.numeric(sf::st_area(lsoa))
  buff <- sf::st_buffer(cents, 500)

  # 785000 m2 ~ area of a 500 m-radius circle
  big <- lsoa$area > 785000
  lsoa_big <- lsoa[big, ]
  lsoa_big$area <- NULL
  lsoa_small <- lsoa[!big, ]
  buff_small <- buff[!big, ]

  res <- vector("list", nrow(lsoa_small))
  for (i in seq_len(nrow(lsoa_small))) {
    if (i %% 5000 == 0) message(i, " / ", nrow(lsoa_small))
    res[[i]] <- sf::st_union(sf::st_buffer(lsoa_small$geometry[i], 0),
                             buff_small$geometry[i])[[1]]
  }
  buff_small$geometry <- sf::st_as_sfc(res, crs = 27700)

  zone <- rbind(lsoa_big, buff_small)
  zone <- sf::st_buffer(zone, 100)
  zone
}
