# Per-year trips-per-LSOA frequency statistics.
#
# The counting itself is UK2GTFS::gtfs_trips_per_zone(); this file only
# handles reading feeds, applying the standard 28-day Monday study window,
# and combining bus and rail feeds into one table per year.

#' Read a GTFS feed and prepare it for analysis
read_feed <- function(path, cfg = load_cfg()) {
  path <- resolve_feed_path(path, cfg)
  if (!file.exists(path)) stop("GTFS feed not found: ", path)
  gtfs <- UK2GTFS::gtfs_read(path)
  gtfs$shapes <- NULL # not needed, large in BODS feeds
  gtfs$stops <- gtfs$stops[!is.na(gtfs$stops$stop_lon), ]
  gtfs <- UK2GTFS::gtfs_clean(gtfs)
  gtfs
}

#' Count trips per zone for one feed over its 28-day Monday window
feed_trips <- function(feed, zones, cfg = load_cfg()) {
  win <- study_window(feed$ref)
  message("Feed ", feed$path, ": window ", win$startdate, " to ", win$enddate)
  gtfs <- read_feed(feed$path, cfg)
  res <- UK2GTFS::gtfs_trips_per_zone(gtfs, zone = zones,
                                      startdate = win$startdate,
                                      enddate = win$enddate,
                                      ncores = cfg$ncores)
  as.data.frame(res)
}

#' Sum several trips-per-zone tables (e.g. bus + rail) per zone and mode
sum_feeds <- function(res_list) {
  res <- dplyr::bind_rows(res_list)
  res <- dplyr::group_by(res, zone_id, route_type)
  res <- dplyr::summarise_all(res, sum, na.rm = TRUE)
  dplyr::ungroup(res)
}

#' Element-wise maximum of two trips-per-zone tables
#'
#' Used for 2023, where the bus figure is the fuller of a spring and an
#' autumn TNDS snapshot (school-term services differ between terms).
max_feeds <- function(a, b) {
  a <- as.data.frame(a)
  b <- as.data.frame(b)
  names(b) <- paste0(names(b), "_b")
  both <- dplyr::full_join(a, b,
                           by = c("zone_id" = "zone_id_b",
                                  "route_type" = "route_type_b"))
  stat_cols <- setdiff(names(a), c("zone_id", "route_type"))
  for (nm in stat_cols) {
    both[[nm]] <- pmax(both[[nm]], both[[paste0(nm, "_b")]], na.rm = TRUE)
  }
  both[names(a)]
}

#' Produce data/trips_per_lsoa21_22_by_mode_<year>.Rds for one year
#'
#' `...` is unused directly: it carries the file dependencies on the feeds
#' converted by this pipeline so targets rebuilds the year when a conversion
#' changes.
run_year <- function(year, zones_path, ..., cfg = load_cfg()) {
  # Reproduce the published outputs: planar geometry for the point-in-polygon
  # stop-to-zone join (the zone polygons contain unions/buffers that s2
  # rejects as invalid on the sphere)
  suppressMessages(sf::sf_use_s2(FALSE))

  spec <- year_sources(cfg)[[as.character(year)]]
  if (is.null(spec)) stop("No source specification for year ", year)

  zones <- readRDS(zones_path)
  zones <- sf::st_transform(zones, 4326)

  bus_res <- lapply(spec$bus, feed_trips, zones = zones, cfg = cfg)
  res <- if (spec$bus_combine == "max") {
    Reduce(max_feeds, bus_res)
  } else {
    sum_feeds(bus_res)
  }

  if (!is.null(spec$rail)) {
    rail <- feed_trips(spec$rail, zones, cfg)
    res <- sum_feeds(list(res, rail))
  }

  dir.create(cfg$out_dir, showWarnings = FALSE, recursive = TRUE)
  out <- file.path(cfg$out_dir,
                   sprintf("trips_per_lsoa21_22_by_mode_%s.Rds", year))
  saveRDS(res, out)
  out
}
