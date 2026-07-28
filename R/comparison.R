# Multi-year comparison of the three bus timetable sources.
#
# For recent years three versions of the bus timetable exist:
#  - TNDS:      Traveline National Dataset, TransXChange format (the source
#               used for 2018-2023), converted with UK2GTFS
#  - BODS TXC:  Bus Open Data Service, TransXChange format (operator-published
#               change archive), converted with UK2GTFS
#  - BODS GTFS: the DfT's own GTFS rendering of BODS data (the source used
#               directly for 2024-2025)
#
# All three are counted with gtfs_trips_per_zone() over the same 28-day
# Monday window and the same zones, so any differences are differences in
# the sources (or their conversion), not in the method.
#
# The comparison runs for 2022-2026, one snapshot per year. It cannot run
# earlier: the BODS TransXChange change archive only starts in May 2022, and
# the only 2021 BODS GTFS snapshot is from January 2021, months away from
# any TNDS snapshot and in the middle of the third national lockdown.
#
# Alongside the zone-level comparison, R/route_match.R matches individual
# bus routes between the sources so the difference can be split into
# services a source lacks entirely and services it runs at a different
# frequency.

#' Snapshot triples: one matched set of the three sources per year
#'
#' `ref` is the window reference date, floored to its Monday by
#' study_window(); all three sources of a year are counted over that one
#' window. `bods_txc` names the feed convert_bods_txc() writes, `tnds` the
#' feed convert_tnds_snapshot() writes, and `bods_gtfs` is the DfT feed used
#' as supplied (a path under cfg$data_root).
#'
#' The DfT's national GTFS changed character between the 2024 and 2026
#' snapshots: the older feeds carry history (the 2022-11-02 feed has
#' calendars back to 2022-08-01), the 2026 ones do not — every calendar in
#' `20260204/itm_all_gtfs.zip` starts on or after the extraction date. When
#' the reference date is not a Monday, flooring it opens the window before
#' the extraction date and the BODS GTFS column is silently short by those
#' days, which is what made February 2026 look anomalous. Where the feed has
#' no history the window is therefore anchored forward, to the first Monday
#' on or after the extraction date, via an explicit `ref`.
comparison_snapshots <- function() {
  list(
    # 2022-2024: feeds carry history, so flooring the reference date to its
    # Monday stays inside their coverage.
    `2022` = list(ref = "2022-11-02",
                  tnds = "gtfs/tnds_20221102_merged.zip",
                  bods_txc = "gtfs/bods_txc_20221102.zip",
                  bods_gtfs = "OpenBusData/GTFS/20221102/itm_all_gtfs.zip"),
    `2023` = list(ref = "2023-11-01",
                  tnds = "gtfs/tnds_20231101_merged.zip",
                  bods_txc = "gtfs/bods_txc_20231101.zip",
                  bods_gtfs = "OpenBusData/GTFS/20231101/itm_all_gtfs.zip"),
    `2024` = list(ref = "2024-10-07",
                  tnds = "gtfs/tnds_20241004_merged.zip",
                  bods_txc = "gtfs/bods_txc_20241007.zip",
                  bods_gtfs = "OpenBusData/GTFS/20241007/itm_all_gtfs.zip"),
    # 2025: the extraction date is itself a Monday, so nothing to correct.
    `2025` = list(ref = "2025-10-06",
                  tnds = "gtfs/tnds_20251003_merged.zip",
                  bods_txc = "gtfs/bods_txc_20251006.zip",
                  bods_gtfs = "OpenBusData/GTFS/20251006/itm_all_gtfs.zip"),
    # 2026: extracted on Wednesday 4 February with no history, so the window
    # opens on the following Monday rather than the preceding one.
    `2026` = list(ref = "2026-02-09", snapshot_date = "2026-02-04",
                  tnds = "gtfs/tnds_20260204_merged.zip",
                  bods_txc = "gtfs/bods_txc_20260204.zip",
                  bods_gtfs = "OpenBusData/GTFS/20260204/itm_all_gtfs.zip")
  )
}

#' The snapshot triple used for validation against published timetables
#'
#' Separate from comparison_snapshots(): the multi-year comparison wants one
#' matched snapshot per year, while validation wants whichever snapshot the
#' available PDFs are actually valid for. Published timetables are easy to
#' obtain for today and hard to obtain for the past, so this is a current
#' snapshot of all three sources.
#'
#' Extracted Sunday 26 July 2026 (BODS TransXChange the previous day), so the
#' window opens on Monday 27 July for the same no-history reason as 2026-02.
validation_snapshot <- function() {
  list(ref = "2026-07-27", snapshot_date = "2026-07-26",
       tnds = "gtfs/tnds_20260726_merged.zip",
       bods_txc = "gtfs/bods_txc_20260725.zip",
       bods_gtfs = "OpenBusData/GTFS/20260726/itm_all_gtfs.zip")
}

#' Windows the validation counts over
#'
#' Two, because the two bank holidays fall either side of a single 28-day
#' window and bank holiday handling is the nearest untested neighbour of the
#' holiday-profile duplication that was fixed in UK2GTFS.
#'
#'  * `main` (27 Jul - 23 Aug 2026) contains Monday 3 August, the Scottish
#'    summer bank holiday. The Glasgow, Falkirk and Fife references are all
#'    inside it.
#'  * `bankhol` (10 Aug - 6 Sep 2026) contains Monday 31 August, the England
#'    and Wales summer bank holiday, and so covers the Cardiff 62's "Sundays
#'    & public holidays" table and Kinchbus's "Sunday & Bank Holiday Monday"
#'    table - the only two published references for a bank holiday in the
#'    set. It runs six weeks past the extraction date, which is well within
#'    what the TransXChange sources carry forward but should be read with
#'    that in mind.
validation_windows <- function() {
  c(main = "2026-07-27", bankhol = "2026-08-10")
}

comparison_years <- function() as.integer(names(comparison_snapshots()))

comparison_sources <- function() c("tnds", "bods_txc", "bods_gtfs")

comparison_source_labels <- function() {
  c(tnds = "TNDS (TransXChange)",
    bods_txc = "BODS (TransXChange)",
    bods_gtfs = "BODS (GTFS)")
}

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

#' Count one source-year: per-zone trips, feed stats and per-route summary
#'
#' One target per source and year, so an interrupted run resumes at the last
#' completed source rather than restarting the year.
#'
#' @param year analysis year (must be in comparison_snapshots())
#' @param source one of comparison_sources()
#' @param zones_path path to the zone polygons
#' @param ... unused; carries the file dependency on the converted feed so
#'   targets rebuilds this when the conversion changes
comparison_source_result <- function(year, source, zones_path, ...,
                                     cfg = load_cfg()) {
  spec <- comparison_snapshots()[[as.character(year)]]
  if (is.null(spec)) stop("No comparison snapshot for year ", year)
  if (!source %in% comparison_sources()) stop("Unknown source ", source)

  suppressMessages(sf::sf_use_s2(FALSE))
  win <- study_window(spec$ref)
  message(source, " ", year, ": window ", win$startdate, " to ", win$enddate)

  gtfs <- read_feed(spec[[source]], cfg)
  stats <- feed_summary_stats(gtfs, win)
  composition <- feed_mode_composition(gtfs)

  # Harmonise extended route types before counting so modes align
  gtfs$routes$route_type <- map_route_type_simple(gtfs$routes$route_type)

  # Route-level summary first: it needs stop_times, which the zone counting
  # consumes. It works on its own date-trimmed copy of the feed, so release
  # that before the (memory-heavy) zone counting starts.
  routes <- route_window_summary(gtfs, win, keep_type = 3L)
  gc()

  zones <- readRDS(zones_path)
  zones <- sf::st_transform(zones, 4326)
  res <- UK2GTFS::gtfs_trips_per_zone(gtfs, zone = zones,
                                      startdate = win$startdate,
                                      enddate = win$enddate,
                                      ncores = cfg$ncores)
  res <- add_tph_daytime_avg(as.data.frame(res))

  list(year = year, source = source, window = win,
       stats = stats, composition = composition, trips = res, routes = routes)
}

#' Bus departures by day and time band, from a per-zone result table
band_runs_bus <- function(trips) {
  b <- trips[trips$route_type == 3 & !is.na(trips$zone_id), ]
  runs_cols <- grep("^runs_", names(b), value = TRUE)
  out <- data.frame(column = runs_cols,
                    runs = colSums(b[runs_cols], na.rm = TRUE))
  out <- tidyr::separate(out, column, into = c("measure", "day", "band"),
                         sep = "_", extra = "merge")
  out[, c("day", "band", "runs")]
}

#' Combine the three sources of one year into the report inputs
#'
#' Writes data/bus_source_comparison_<year>.Rds holding only what the report
#' needs: feed stats, mode composition, the per-zone bus table, day/band
#' totals, and the cross-source route matching.
combine_year_comparison <- function(year, results, cfg = load_cfg()) {
  names(results) <- vapply(results, `[[`, "", "source")
  srcs <- comparison_sources()
  results <- results[srcs]

  # Wide bus-only table: one row per zone, tph_daytime_avg per source
  bus_wide <- NULL
  for (nm in srcs) {
    b <- results[[nm]]$trips
    b <- b[b$route_type == 3 & !is.na(b$zone_id),
           c("zone_id", "tph_daytime_avg")]
    names(b)[2] <- nm
    bus_wide <- if (is.null(bus_wide)) b else
      dplyr::full_join(bus_wide, b, by = "zone_id")
  }
  # A zone missing from a source genuinely has no counted bus service there
  for (nm in srcs) bus_wide[[nm]][is.na(bus_wide[[nm]])] <- 0
  bus_wide$country <- substr(bus_wide$zone_id, 1, 1)

  bands <- dplyr::bind_rows(lapply(results, function(r) band_runs_bus(r$trips)),
                            .id = "source")

  # Cross-source route matching and the missing-vs-frequency decomposition
  matched <- match_route_services(lapply(results, `[[`, "routes"))
  pairs <- list(c("tnds", "bods_gtfs"), c("bods_txc", "bods_gtfs"),
                c("tnds", "bods_txc"))
  decomp <- dplyr::bind_rows(lapply(pairs, function(p) {
    decompose_difference(matched$services, p[1], p[2])
  }))

  out <- list(
    year = year,
    window = results[[1]]$window,
    snapshot = comparison_snapshots()[[as.character(year)]],
    stats = dplyr::bind_rows(lapply(results, `[[`, "stats"), .id = "source"),
    composition = dplyr::bind_rows(lapply(results, `[[`, "composition"),
                                   .id = "source"),
    bus_wide = bus_wide,
    bands = bands,
    services = matched$services,
    decomposition = decomp
  )

  dir.create(cfg$out_dir, showWarnings = FALSE, recursive = TRUE)
  out_path <- file.path(cfg$out_dir,
                        sprintf("bus_source_comparison_%s.Rds", year))
  saveRDS(out, out_path)
  out_path
}

#' Knit the multi-year comparison report to markdown
render_comparison_report <- function(comparison_paths, cfg = load_cfg()) {
  dir.create(cfg$report_dir, showWarnings = FALSE, recursive = TRUE)
  env <- new.env(parent = globalenv())
  env$comparison_paths <- normalizePath(comparison_paths)

  # Knit from inside reports/ so figure links in the md are relative to it.
  # knitr::knit (not rmarkdown::render) so no pandoc dependency.
  old_wd <- setwd(cfg$report_dir)
  on.exit(setwd(old_wd), add = TRUE)
  knitr::knit(
    input = "bus_source_comparison.Rmd",
    output = "bus_source_comparison.md",
    envir = env,
    quiet = TRUE
  )
  file.path(cfg$report_dir, "bus_source_comparison.md")
}
