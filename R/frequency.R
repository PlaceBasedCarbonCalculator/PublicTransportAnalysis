# Per-year trips-per-LSOA frequency statistics.
#
# The counting itself is UK2GTFS::gtfs_trips_per_zone(); this file only
# handles reading feeds, applying the standard 28-day Monday study window,
# and combining bus and rail feeds into one table per year.
#
# read_feed() is also where the deduplication stage sits, between conversion
# and counting, and every consumer in the repo goes through it.

#' Read a GTFS feed and prepare it for analysis
#'
#' Every counting path in this repo - the per-year trips, the source
#' comparison, the zone-level gap analysis and the PDF validation - reads its
#' feeds through here, so this is where the feed is made ready to count.
#'
#' The last step is deduplication. Feeds assembled from many publishers, or
#' from several revisions of one publisher's data, describe the same vehicle
#' journey twice. That is a property of the feed and not of the road, so it is
#' removed before anything is counted. UK2GTFS::gtfs_deduplicate() removes a
#' copy only where the whole itinerary matches and every date it runs is also
#' run by the copy kept, so no date loses service; it leaves routes, calendars
#' and stops untouched.
#'
#' Its defaults are taken, and they matter. `match_block = FALSE` ignores
#' `block_id`, which the DfT's GTFS fills with a hash generated per dataset
#' revision, so two copies of one journey never agree on it; requiring
#' agreement let every such duplicate through, and the feed's First Bristol 21
#' stayed at 5,816 journeys against the 3,296 its operator prints. Ignoring it
#' lands the 21 on 3,296 and the A1 on 6,916, both exactly the published
#' figure and exactly TNDS. `match_operator = "name"` groups routes by the
#' operator's name rather than its `agency_id`, because one operator is
#' regularly filed under several agency records - Arriva London North is both
#' OP401/ARVA and OP16197/ALNO - and grouping on the record split its duplicate
#' journeys apart. Together these take the DfT feed's removal rate from 3.2% to
#' 5.2%. See reports/pdf_validation.md.
#'
#' It runs after gtfs_clean() so that it sees exactly the feed that will be
#' counted - cleaning drops unlocatable stops and the trips left with fewer
#' than two calls, which changes the itineraries being compared.
#'
#' @param path feed path or target name, resolved by resolve_feed_path()
#' @param cfg pipeline config
#' @param deduplicate remove journeys the feed describes more than once.
#'   Only set FALSE to measure duplication in the source as published, as
#'   lsoa_gap_analysis() does.
read_feed <- function(path, cfg = load_cfg(), deduplicate = TRUE) {
  path <- resolve_feed_path(path, cfg)
  if (!file.exists(path)) stop("GTFS feed not found: ", path)
  gtfs <- UK2GTFS::gtfs_read(path)
  gtfs$shapes <- NULL # not needed, large in BODS feeds
  gtfs$stops <- gtfs$stops[!is.na(gtfs$stops$stop_lon), ]
  gtfs <- UK2GTFS::gtfs_clean(gtfs)
  if (deduplicate) {
    gtfs <- UK2GTFS::gtfs_deduplicate(gtfs)
  }
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
  res <- sum_feeds(bus_res)

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
