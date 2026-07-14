# Central configuration for the public transport frequency pipeline.
#
# All paths to data OUTSIDE this repo are defined here and nowhere else.
# Raw timetable data (D:) is treated as read-only; everything this pipeline
# writes goes inside this repo (gtfs/, data/, input/, reports/).

load_cfg <- function() {
  list(
    # Root of the raw/converted timetable archive (read-only)
    data_root = Sys.getenv("UK2GTFS_DATA",
                           "D:/OneDrive - University of Leeds/Data/UK2GTFS"),

    # Sibling repos (read-only), relative to this repo's root
    tb_repo    = "../../ITSleeds/TransportBlackspots",
    pbcc_build = "../build",
    pbcc_input = "../inputdata",

    # Directories inside this repo
    gtfs_dir   = "gtfs",    # GTFS feeds converted/merged by this pipeline
    input_dir  = "input",   # large inputs cached locally (e.g. zone polygons)
    out_dir    = "data",    # final outputs consumed by ../build
    report_dir = "reports",

    # Parallelism: passed to every UK2GTFS function with an ncores argument
    # (transxchange2gtfs, atoc2gtfs, gtfs_interpolate_times,
    # gtfs_trips_per_zone, txc_filter_files)
    ncores = 10
  )
}

#' Study window: a 28-day period that always starts on a Monday
#'
#' Every year is counted over a 28-day window containing exactly four of each
#' weekday, derived by flooring the source's snapshot/reference date to the
#' Monday of its week. This makes raw runs_* counts directly comparable
#' between years and makes the tph_* normalisation exact.
study_window <- function(ref) {
  start <- lubridate::floor_date(lubridate::ymd(ref), unit = "week",
                                 week_start = 1)
  list(startdate = start, enddate = start + 27L)
}

#' Timetable sources for each analysis year
#'
#' One entry per year. `bus` is a list of feeds (path + window reference
#' date); `bus_combine` says how multiple bus feeds are combined ("max" =
#' element-wise maximum, used in 2023 where school-term differences mean we
#' take the fuller of a spring and an autumn timetable). `rail` is a single
#' feed or NULL (rail is only separately available from 2018; NPTDR includes
#' some rail within the bus-era feeds).
#'
#' Paths are relative to `cfg$data_root` unless they start with "gtfs/", in
#' which case they are feeds converted by this pipeline (see R/convert.R).
year_sources <- function(cfg = load_cfg()) {
  feed <- function(path, ref) list(path = path, ref = ref)

  spec <- list()
  # 2004-2011: NPTDR annual October snapshots (bus, coach, ferry, some
  # rail/metro/tram). Window anchored to 1 October each year.
  for (y in 2004:2011) {
    spec[[as.character(y)]] <- list(
      year = y,
      bus = list(feed(sprintf("gtfs/nptdr_%s.zip", y),
                      sprintf("%s-10-01", y))),
      bus_combine = "sum",
      rail = NULL
    )
  }

  # 2014-2017: Traveline National Dataset weekly snapshots ("Bus Archive"),
  # converted from raw TransXChange and merged with each snapshot trimmed to
  # its Monday-Sunday week (the archive snapshots are dated on Tuesdays).
  # Essentially no rail, tram or metro in these years.
  ba_ref <- c(`2014` = "2014-10-06", `2015` = "2015-10-05",
              `2016` = "2016-10-03", `2017` = "2017-10-02")
  for (y in 2014:2017) {
    spec[[as.character(y)]] <- list(
      year = y,
      bus = list(feed(sprintf("gtfs/busarchive_%s_merged.zip", y),
                      ba_ref[[as.character(y)]])),
      bus_combine = "sum",
      rail = NULL
    )
  }

  # 2018-2023: TNDS TransXChange (bus/coach/ferry/tram, incl. NCSD coach) +
  # ATOC CIF (rail), all converted from raw data by this pipeline. Snapshot
  # choice follows the TransportBlackspots analysis: October where
  # available, otherwise the nearest usable snapshot.
  tnds_years <- list(
    `2018` = c("20180515", "2018-10-16"),
    `2019` = c("20191008", "2019-08-31"),
    `2020` = c("20200701", "2020-11-26"),
    `2021` = c("20211012", "2021-10-09"),
    `2022` = c("20221102", "2022-11-02")
  )
  for (y in names(tnds_years)) {
    snap <- tnds_years[[y]][1]
    rail_date <- tnds_years[[y]][2]
    snap_ref <- paste(substr(snap, 1, 4), substr(snap, 5, 6),
                      substr(snap, 7, 8), sep = "-")
    spec[[y]] <- list(
      year = as.integer(y),
      bus = list(feed(sprintf("gtfs/tnds_%s_merged.zip", snap), snap_ref)),
      bus_combine = "sum",
      rail = feed(sprintf("gtfs/rail_atoc_%s.zip", rail_date), rail_date)
    )
  }
  # 2023: element-wise max of spring and autumn TNDS snapshots (school-term
  # services differ between terms; we take the fuller timetable).
  spec[["2023"]] <- list(
    year = 2023,
    bus = list(feed("gtfs/tnds_20230503_merged.zip", "2023-05-03"),
               feed("gtfs/tnds_20231101_merged.zip", "2023-11-01")),
    bus_combine = "max",
    rail = feed("gtfs/rail_atoc_2023-05-03.zip", "2023-05-03")
  )

  # 2024: Bus Open Data Service national GTFS (used directly) + ATOC rail.
  spec[["2024"]] <- list(
    year = 2024,
    bus = list(feed("OpenBusData/GTFS/20241007/itm_all_gtfs.zip", "2024-10-07")),
    bus_combine = "sum",
    rail = feed("gtfs/rail_atoc_2024-10-05.zip", "2024-10-05")
  )

  # 2025: BODS national GTFS + rail from the National Rail Data Portal
  # (new CIF source, converted by this pipeline with atoc2gtfs()).
  spec[["2025"]] <- list(
    year = 2025,
    bus = list(feed("OpenBusData/GTFS/20251006/itm_all_gtfs.zip", "2025-10-06")),
    bus_combine = "sum",
    rail = feed("gtfs/rail_rdp_20251006.zip", "2025-10-06")
  )

  spec
}

#' Resolve a feed path against the data root / repo
resolve_feed_path <- function(path, cfg = load_cfg()) {
  if (startsWith(path, "gtfs/")) path else file.path(cfg$data_root, path)
}

analysis_years <- function() c(2004:2011, 2014:2025)
