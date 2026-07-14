# Three-way comparison of the October 2025 bus timetable sources.
#
# For the most recent years three versions of the bus timetable exist:
#  - TNDS:     Traveline National Dataset, TransXChange format (the source
#              used for 2018-2023), converted with UK2GTFS
#  - BODS TXC: Bus Open Data Service, TransXChange format (operator-published
#              change archive), converted with UK2GTFS
#  - BODS GTFS: the DfT's own GTFS rendering of BODS data (the source used
#              directly for 2024-2025)
# All three are counted with gtfs_trips_per_zone() over the same 28-day
# Monday window and the same zones, so any differences are differences in
# the sources (or their conversion), not in the method.

comparison_window_ref <- "2025-10-06"

#' Map extended GTFS route types to the types used in this analysis
#'
#' The DfT BODS GTFS uses many extended route types (e.g. 208 special coach,
#' 715 demand-response bus, 1000 water). These are folded onto the set used
#' throughout this analysis: 0 tram, 1 metro, 2 rail, 3 bus, 4 ferry and
#' 200 coach. Coach stays distinct from bus, matching how UK2GTFS now codes
#' coach services (TNDS NCSD, NPTDR COACH records).
map_route_type_simple <- function(rt) {
  rt <- as.integer(rt)
  dplyr::case_when(
    rt %in% 100:199 ~ 2L,             # railway services -> rail
    rt %in% 200:299 ~ 200L,           # coach services -> coach
    rt %in% 400:499 ~ 1L,             # urban railway -> metro
    rt %in% 700:799 ~ 3L,             # bus services -> bus
    rt %in% 900:999 ~ 0L,             # tram services -> tram
    rt %in% c(1000L, 1200L) ~ 4L,     # water/ferry -> ferry
    rt == 1400L ~ 0L,                 # funicular -> tram/light rail
    TRUE ~ rt
  )
}

#' Basic feed statistics for the comparison report
feed_summary_stats <- function(gtfs, win) {
  gtfs_win <- UK2GTFS::gtfs_trim_dates(gtfs, startdate = win$startdate,
                                       enddate = win$enddate)
  data.frame(
    agencies = nrow(gtfs$agency),
    routes = nrow(gtfs$routes),
    trips = nrow(gtfs$trips),
    stops_used = length(unique(gtfs$stop_times$stop_id)),
    stop_times = nrow(gtfs$stop_times),
    missing_departure_times = sum(is.na(gtfs$stop_times$departure_time)),
    routes_in_window = nrow(gtfs_win$routes),
    trips_in_window = nrow(gtfs_win$trips),
    calendar_start = as.character(min(gtfs$calendar$start_date, na.rm = TRUE)),
    calendar_end = as.character(max(gtfs$calendar$end_date, na.rm = TRUE))
  )
}

#' Composition of a feed by original and harmonised route_type
feed_mode_composition <- function(gtfs) {
  routes <- as.data.frame(gtfs$routes)
  trips <- as.data.frame(gtfs$trips)
  trips <- dplyr::left_join(trips, routes[, c("route_id", "route_type")],
                            by = "route_id")
  comp <- dplyr::count(trips, route_type, name = "trips")
  comp$route_type_simple <- map_route_type_simple(comp$route_type)
  comp
}

#' Time-weighted average daytime trips per hour
#'
#' Same definition as PlaceBasedCarbonCalculator build
#' (R/public_transport_frequency.R): all bands except Night, weekdays
#' weighted x5, over a 7-day 16-hour daytime week.
add_tph_daytime_avg <- function(res) {
  wd <- function(band) {
    (res[[paste0("tph_Mon_", band)]] + res[[paste0("tph_Tue_", band)]] +
       res[[paste0("tph_Wed_", band)]] + res[[paste0("tph_Thu_", band)]] +
       res[[paste0("tph_Fri_", band)]]) / 5
  }
  res$tph_daytime_avg <-
    (wd("Morning Peak") * 5 * 4 + wd("Midday") * 5 * 5 +
       wd("Afternoon Peak") * 5 * 3 + wd("Evening") * 5 * 4 +
       res$`tph_Sat_Morning Peak` * 4 + res$tph_Sat_Midday * 5 +
       res$`tph_Sat_Afternoon Peak` * 3 + res$tph_Sat_Evening * 4 +
       res$`tph_Sun_Morning Peak` * 4 + res$tph_Sun_Midday * 5 +
       res$`tph_Sun_Afternoon Peak` * 3 + res$tph_Sun_Evening * 4) / (7 * 16)
  res
}

#' Count trips per zone for one comparison source
comparison_source_trips <- function(path, zones, cfg = load_cfg()) {
  win <- study_window(comparison_window_ref)
  gtfs <- read_feed(path, cfg)

  stats <- feed_summary_stats(gtfs, win)
  composition <- feed_mode_composition(gtfs)

  # Harmonise extended route types before counting so modes align
  gtfs$routes$route_type <- map_route_type_simple(gtfs$routes$route_type)

  res <- UK2GTFS::gtfs_trips_per_zone(gtfs, zone = zones,
                                      startdate = win$startdate,
                                      enddate = win$enddate,
                                      ncores = cfg$ncores)
  res <- as.data.frame(res)
  res <- add_tph_daytime_avg(res)
  list(trips = res, stats = stats, composition = composition)
}

#' Run the three-way comparison and save the results
#'
#' Saves data/bus_source_comparison_2025.Rds: a list with per-source feed
#' stats, mode composition, and the per-zone results (all modes), plus a
#' wide bus-only per-zone table used by the report.
compare_bus_sources <- function(tnds_path, bods_txc_path,
                                zones_path, cfg = load_cfg()) {
  suppressMessages(sf::sf_use_s2(FALSE))
  zones <- readRDS(zones_path)
  zones <- sf::st_transform(zones, 4326)

  sources <- list(
    tnds = tnds_path,
    bods_txc = bods_txc_path,
    bods_gtfs = "OpenBusData/GTFS/20251006/itm_all_gtfs.zip"
  )

  res <- lapply(sources, comparison_source_trips, zones = zones, cfg = cfg)

  # Wide bus-only table: one row per zone, tph_daytime_avg per source
  bus_wide <- NULL
  for (nm in names(res)) {
    b <- res[[nm]]$trips
    b <- b[b$route_type == 3 & !is.na(b$zone_id), c("zone_id", "tph_daytime_avg")]
    names(b)[2] <- nm
    bus_wide <- if (is.null(bus_wide)) b else
      dplyr::full_join(bus_wide, b, by = "zone_id")
  }
  # A zone missing from a source genuinely has no counted bus service there
  for (nm in names(sources)) {
    bus_wide[[nm]][is.na(bus_wide[[nm]])] <- 0
  }
  bus_wide$country <- substr(bus_wide$zone_id, 1, 1)

  out <- list(
    window = study_window(comparison_window_ref),
    sources = sources,
    stats = dplyr::bind_rows(lapply(res, `[[`, "stats"), .id = "source"),
    composition = dplyr::bind_rows(lapply(res, `[[`, "composition"),
                                   .id = "source"),
    trips = lapply(res, `[[`, "trips"),
    bus_wide = bus_wide
  )

  dir.create(cfg$out_dir, showWarnings = FALSE, recursive = TRUE)
  out_path <- file.path(cfg$out_dir, "bus_source_comparison_2025.Rds")
  saveRDS(out, out_path)
  out_path
}

#' Knit the comparison report to markdown
render_comparison_report <- function(comparison_path, cfg = load_cfg()) {
  dir.create(cfg$report_dir, showWarnings = FALSE, recursive = TRUE)
  env <- new.env(parent = globalenv())
  env$comparison_path <- normalizePath(comparison_path)

  # Knit from inside reports/ so figure links in the md are relative to it.
  # knitr::knit (not rmarkdown::render) so no pandoc dependency.
  old_wd <- setwd(cfg$report_dir)
  on.exit(setwd(old_wd), add = TRUE)
  knitr::knit(
    input = "bus_source_comparison_2025.Rmd",
    output = "bus_source_comparison_2025.md",
    envir = env,
    quiet = TRUE
  )
  file.path(cfg$report_dir, "bus_source_comparison_2025.md")
}
