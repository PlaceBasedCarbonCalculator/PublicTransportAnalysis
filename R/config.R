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
    # gtfs_trips_per_zone, txc_filter_files). Override per target with
    # cfg_cores(); see there for why this default is not simply raised.
    ncores = 10
  )
}

#' The same configuration with a different worker count
#'
#' targets hashes the body of every global function a target reaches, and
#' `load_cfg()` is reached by every conversion and every counting target, so
#' editing `ncores` above would invalidate — and so re-run — conversions that
#' are already built and correct. Passing `cfg = cfg_cores(n)` in a target's
#' command changes that target alone, which is free when the target has to be
#' rebuilt anyway. The machine has 36 cores.
cfg_cores <- function(n, cfg = load_cfg()) {
  cfg$ncores <- as.integer(n)
  cfg
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
#' date), summed together where there is more than one. `rail` is a single
#' feed or NULL (rail is only separately available from 2018; NPTDR includes
#' some rail within the bus-era feeds).
#'
#' Only ever list more than one `bus` feed for a year when the feeds cover
#' *disjoint* parts of the network. `sum_feeds()` adds their counts, and
#' deduplication happens inside `read_feed()`, per feed — nothing downstream
#' can tell that two feeds describe the same journey. Listing two national
#' feeds together is what made the 2024 and 2025 outputs count nearly every
#' bus journey twice.
#'
#' Paths are relative to `cfg$data_root` unless they start with "gtfs/", in
#' which case they are feeds converted by this pipeline (see R/convert.R).
year_sources <- function(cfg = load_cfg()) {
  # `...` carries optional per-feed settings, currently only
  # `drop_route_types` (see feed_trips())
  feed <- function(path, ref, ...) c(list(path = path, ref = ref), list(...))

  spec <- list()
  # 2004-2011: NPTDR annual October snapshots (bus, coach, ferry, some
  # rail/metro/tram). Window anchored to 1 October each year.
  for (y in 2004:2011) {
    spec[[as.character(y)]] <- list(
      year = y,
      bus = list(feed(sprintf("gtfs/nptdr_%s.zip", y),
                      sprintf("%s-10-01", y))),
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
      rail = NULL
    )
  }

  # 2018-2023: TNDS TransXChange (bus/coach/ferry/tram, incl. NCSD coach) +
  # ATOC CIF (rail), all converted from raw data by this pipeline. Snapshot
  # choice follows the TransportBlackspots analysis: October where
  # available, otherwise the nearest usable snapshot.
  #
  # Route type 1 (metro) is dropped from every rail feed. The CIF feeds carry
  # the London Underground - agency LT, 1,901 to 6,092 trips a year at 25
  # stations - and the Tyne and Wear Metro, and TNDS carries both in full, so
  # summing the two feeds counts those stations twice. The stop ids cannot
  # collide (TIPLOC in the CIF against ATCO in TNDS) so no deduplication could
  # ever catch it, but stops are joined to zones by position, not by id.
  # README.md used to say the Underground was not in the CIF feed; it is, in
  # every year. TNDS is the copy kept because it carries the whole of both
  # networks where the CIF carries the sections shared with the national
  # railway. See reports/metro_duplicate_copies.md.
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
      rail = feed(sprintf("gtfs/rail_atoc_%s.zip", rail_date), rail_date,
                  drop_route_types = 1)
    )
  }
  # 2023: November TNDS snapshot only (the fuller of the two available that
  # year; the spring snapshot is dropped rather than combined).
  spec[["2023"]] <- list(
    year = 2023,
    bus = list(feed("gtfs/tnds_20231101_merged.zip", "2023-11-01")),
    rail = feed("gtfs/rail_atoc_2023-11-01.zip", "2023-11-01",
                drop_route_types = 1)
  )

  # 2024: TNDS TransXChange (bus) + ATOC rail, on the same footing as
  # 2018-2023.
  #
  # These two years used to list the BODS national GTFS feed *as well as* the
  # TNDS conversion, and sum_feeds() added their counts. Both feeds carry the
  # whole Great Britain bus network, so nearly every journey was counted twice
  # and the outputs came out at roughly double 2023 (21.4 trips per hour per
  # neighbourhood in 2023 against 43.8 in 2024). Deduplication in read_feed()
  # cannot catch it: it runs within a feed, not across two.
  #
  # TNDS is the source kept because it is the one validated against operators'
  # published schedules - reports/route_279_pdf_validation.md and
  # reports/route_validation_69_A1_142.md found TNDS matching printed
  # timetables journey-for-journey where BODS GTFS carried some of them more
  # than twice over. Keeping TNDS also makes 2018-2025 one continuous
  # single-source bus series. See reports/foe_bus_decline_comparison.md.
  #
  # From 2024 coach comes from the BODS Coach dataset instead of TNDS, and
  # route type 200 is dropped from the TNDS feed so it is not counted twice.
  # TNDS's NCSD coach archive disappears after February 2025 - 208 coach
  # routes in October 2024, 22 in October 2025, 6 in July 2026 - and what
  # survives is local operators, not the national network. Taking coach from
  # BODS for every year it is available keeps one source per year and puts the
  # break at 2023/24 rather than leaving coach to fade out. Unlike the two bus
  # feeds these years used to carry, these two are disjoint: the BODS Coach
  # feed is National Express, Flixbus, Scottish Citylink, Megabus and Park's
  # of Hamilton, none of which appear in the TNDS snapshots (the "National
  # Express" in TNDS is National Express West Midlands and Coventry, which are
  # local bus). See scripts/foe_comparison/explore_bods_coach.R.
  spec[["2024"]] <- list(
    year = 2024,
    bus = list(feed("gtfs/tnds_20241004_merged.zip", "2024-10-04",
                    drop_route_types = 200),
               feed("gtfs/bods_coach_20241007.zip", "2024-10-07")),
    rail = feed("gtfs/rail_atoc_2024-10-05.zip", "2024-10-05",
                drop_route_types = 1)
  )

  # 2025: TNDS TransXChange (bus) + BODS Coach + rail from the National Rail
  # Data Portal (new CIF source, converted by this pipeline with atoc2gtfs()).
  spec[["2025"]] <- list(
    year = 2025,
    bus = list(feed("gtfs/tnds_20251003_merged.zip", "2025-10-03",
                    drop_route_types = 200),
               feed("gtfs/bods_coach_20251006.zip", "2025-10-06")),
    rail = feed("gtfs/rail_rdp_20251006.zip", "2025-10-06",
                drop_route_types = 1)
  )

  spec
}

#' Resolve a feed path against the data root / repo
resolve_feed_path <- function(path, cfg = load_cfg()) {
  if (startsWith(path, "gtfs/")) path else file.path(cfg$data_root, path)
}

analysis_years <- function() c(2004:2011, 2014:2025)
