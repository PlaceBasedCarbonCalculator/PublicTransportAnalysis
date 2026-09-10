# Functions for the London Underground duplicate-copy investigation.
#
# The metro series in data/trips_per_lsoa21_22_by_mode_*.Rds jumps in single
# years - Leytonstone (E01004440) sits near 55 trips per hour in the afternoon
# peak in most years and near 100 in 2021 and 2025. This file measures why.
#
# The short version: TfL publishes one Underground line into TNDS as several
# TransXChange files with different ServiceCodes and overlapping validity, each
# becomes its own GTFS route, and gtfs_deduplicate() cannot see that they
# describe the same trains. See reports/metro_duplicate_copies.md.
#
# Deliberately standalone: nothing here is part of the targets pipeline, and
# nothing here writes to gtfs/ or changes any built output.

suppressPackageStartupMessages({
  library(data.table)
})

source("R/config.R")

# Expanding calendar.txt and calendar_dates.txt into the dates a service
# actually runs is the whole game here. Reading calendar.txt alone gets 2019
# wrong: that year's duplicate copies are cancelled by exception on weekdays
# but not on Saturdays, so a weekday-only check sees nothing. UK2GTFS already
# implements the GTFS semantics correctly for gtfs_deduplicate(), so use its
# implementation rather than writing a second one that can disagree.
service_operating_dates <- UK2GTFS:::service_operating_dates

# Leytonstone Underground Station, both platform-level ATCO codes. The LSOA
# also holds Leytonstone High Road (Overground, route_type 2) and a good many
# bus stops; those are excluded so the figures are Central line only.
LEYTONSTONE <- c("9400ZZLULYS1", "9400ZZLULYS2")
LEYTONSTONE_LSOA <- "E01004440"

# The afternoon peak as UK2GTFS::gtfs_trips_per_zone() defines it: departures
# in 15:00-17:59, over a three hour band.
AP_HOURS <- 15:17
AP_BAND_HOURS <- 3


#' The TNDS snapshot and rail feed behind each analysis year
#'
#' Taken from `year_sources()` rather than restated, so this script cannot
#' drift from the pipeline it is describing. Only the years with a TNDS bus
#' feed are returned - 2004-2017 have no London Underground worth counting
#' (see the era-break section of the report).
#'
#' @return a data.table of year, feed, ref, rail_feed, rail_ref
metro_feed_years <- function(years = 2018:2025, cfg = load_cfg()) {
  spec <- year_sources(cfg)
  rows <- lapply(years, function(y) {
    s <- spec[[as.character(y)]]
    bus <- s$bus[[1]]
    if (!grepl("^gtfs/tnds_", bus$path)) return(NULL)
    data.table(year = y, feed = bus$path, ref = bus$ref,
               rail_feed = if (is.null(s$rail)) NA_character_ else s$rail$path,
               rail_ref = if (is.null(s$rail)) NA_character_ else s$rail$ref)
  })
  rbindlist(rows)
}


#' Read selected tables out of a GTFS zip
#'
#' The merged TNDS feeds run to a few hundred megabytes zipped and stop_times
#' to tens of millions of rows, so tables are extracted once into a scratch
#' directory and re-read from there. Pass `select` to keep only the columns
#' wanted; times are always read as character, because the arrival/departure
#' columns are the one place where a type conversion can silently corrupt a
#' subset (see reference-gtfs-time-column-subset-trap).
#'
#' @param feed path to a GTFS zip
#' @param tables character vector of table names, without ".txt"
#' @param select optional named list of column vectors, one per table
#' @param scratch directory to extract into
#' @return a named list of data.tables; a table absent from the zip is NULL
read_gtfs_tables <- function(feed, tables,
                             select = NULL,
                             scratch = file.path(tempdir(), "metro_dup")) {
  dir.create(scratch, showWarnings = FALSE, recursive = TRUE)
  td <- file.path(scratch, basename(feed))
  dir.create(td, showWarnings = FALSE, recursive = TRUE)

  out <- lapply(tables, function(tb) {
    f <- file.path(td, paste0(tb, ".txt"))
    if (!file.exists(f)) {
      ok <- try(utils::unzip(feed, files = paste0(tb, ".txt"),
                             exdir = td, overwrite = TRUE), silent = TRUE)
      if (inherits(ok, "try-error") || !file.exists(f)) return(NULL)
    }
    args <- list(f, colClasses = list(character = c("arrival_time",
                                                    "departure_time")))
    if (!is.null(select[[tb]])) args$select <- select[[tb]]
    # colClasses names two columns most tables do not have; fread warns and
    # ignores them, which is the wanted behaviour but not wanted output
    suppressWarnings(do.call(data.table::fread, args))
  })
  names(out) <- tables
  out
}


#' Drop the extracted tables for a feed
#'
#' stop_times is the large one; the rest are cheap enough to keep.
clear_gtfs_scratch <- function(feed, tables = "stop_times",
                               scratch = file.path(tempdir(), "metro_dup")) {
  td <- file.path(scratch, basename(feed))
  unlink(file.path(td, paste0(tables, ".txt")))
  invisible(NULL)
}


#' The dates each service runs, clipped to a year's counting window
#'
#' @param g a list with `calendar` and (optionally) `calendar_dates`
#' @param service_ids services to expand
#' @param ref the feed's reference date, as `year_sources()` gives it
#' @return a data.table of service_id and date (integer days since epoch)
window_service_dates <- function(g, service_ids, ref) {
  win <- study_window(ref)
  d <- service_operating_dates(g, unique(as.character(service_ids)))
  d[date %in% as.integer(seq(win$startdate, win$enddate, by = "day"))]
}


#' Routes of one mode and operator, with their trips and live dates
#'
#' @param feed path to a GTFS zip
#' @param ref the feed's reference date
#' @param route_type GTFS mode, 1 for metro
#' @param agency_id optional operator filter, e.g. "LUL"
#' @return a data.table of route_id, agency_id, names, trips and live dates
route_copies <- function(feed, ref, route_type = 1L, agency_id = NULL) {
  # data.table's fast subset resolves a bare name against the table's columns
  # first, and both filters here share a name with the column they test, so
  # the values are held under names of their own
  want_type <- route_type
  want_agency <- agency_id
  g <- read_gtfs_tables(feed, c("routes", "trips", "calendar",
                                "calendar_dates"))
  ro <- g$routes[route_type %in% want_type]
  if (!is.null(want_agency)) ro <- ro[agency_id %in% want_agency]
  tr <- g$trips[route_id %in% ro$route_id]

  d <- window_service_dates(g, tr$service_id, ref)
  x <- merge(tr[, list(route_id, service_id = as.character(service_id))],
             d, by = "service_id", allow.cartesian = TRUE)
  live <- x[, list(trip_days = .N,
                   first_date = as.Date(min(date), origin = "1970-01-01"),
                   last_date = as.Date(max(date), origin = "1970-01-01"),
                   live_days = uniqueN(date)), by = "route_id"]

  out <- merge(ro[, list(route_id, agency_id, route_short_name,
                         route_long_name)],
               tr[, list(trips = .N), by = "route_id"],
               by = "route_id", all.x = TRUE)
  out <- merge(out, live, by = "route_id", all.x = TRUE)
  out[is.na(trips), trips := 0L]
  out[order(-trip_days, -trips)]
}


#' Normalise a route_long_name so one line is one group across years
#'
#' The same line is published as "Morden - High Barnet" in one snapshot and
#' "Morden - High Barnet Station" in the next, and "Elephant & Castle -
#' Queen's Park Station (London)" in a third. Grouping on the raw string would
#' split a line into two rows of the year-by-year table and hide the
#' duplication rather than show it.
normalise_line <- function(x) {
  x <- gsub(" Station", "", x, fixed = TRUE)
  x <- gsub(" (London)", "", x, fixed = TRUE)
  trimws(x)
}


#' Duplicate ("phantom") trip-days inside a counting window
#'
#' For each line and each date, the copies of that line that are live are
#' counted, and everything above the largest single copy is treated as
#' duplication. This deliberately understates: where three copies of equal size
#' are live it counts two as phantom, but where the copies differ in size it
#' assumes the largest is the real one and charges nothing for the rest being
#' plausible variants.
#'
#' Lines are identified by operator, mode and the pair of names. For bus that
#' is effectively the route number, so the measure is directly comparable
#' across modes - which is the point: it shows bus at a fraction of a percent
#' and metro in the tens of percent.
#'
#' @param feed path to a GTFS zip
#' @param ref the feed's reference date
#' @param route_types modes to include, NULL for all
#' @param agency_id optional operator filter
#' @param by "route_type" or "line"
#' @return a data.table of trip_days, phantom and pct
phantom_trip_days <- function(feed, ref, route_types = NULL,
                              agency_id = NULL, by = c("route_type", "line")) {
  by <- match.arg(by)
  want_agency <- agency_id
  g <- read_gtfs_tables(feed, c("routes", "trips", "calendar",
                                "calendar_dates"))
  ro <- copy(g$routes)
  if (!is.null(route_types)) ro <- ro[route_type %in% route_types]
  if (!is.null(want_agency)) ro <- ro[agency_id %in% want_agency]
  ro[, route_id := as.character(route_id)]
  ro[, line := normalise_line(route_long_name)]
  ro[, key := paste(agency_id, route_type, route_short_name, line, sep = "|")]

  tr <- g$trips[as.character(route_id) %in% ro$route_id]
  d <- window_service_dates(g, tr$service_id, ref)
  x <- merge(tr[, list(route_id = as.character(route_id),
                       service_id = as.character(service_id))],
             d, by = "service_id", allow.cartesian = TRUE)
  x <- x[, list(trips = .N), by = c("route_id", "date")]
  x <- merge(x, ro[, list(route_id, key, line, route_type)], by = "route_id")

  # one row per line per date: how much service is claimed, and how much the
  # single largest copy claims on its own
  g2 <- x[, list(total = sum(trips), biggest = max(trips), copies = .N),
          by = c("key", "line", "route_type", "date")]

  grp <- if (by == "route_type") "route_type" else c("route_type", "line")
  s <- g2[, list(trip_days = sum(total),
                 phantom = sum(total - biggest),
                 lines = uniqueN(key),
                 lines_affected = uniqueN(key[copies > 1])), by = grp]
  s[, pct := round(100 * phantom / trip_days, 1)]
  s[order(route_type, -phantom)]
}


#' How many routes of each mode carry no route_short_name
#'
#' This is the field gtfs_deduplicate() groups on, and a blank one makes a
#' route stand alone - so a blank name is an exemption from deduplication.
#' UK2GTFS blanks any TransXChange LineName longer than six characters
#' (transxchange_export.R), which is harmless for bus route numbers and
#' removes almost every Underground line name.
blank_short_name_by_mode <- function(feed) {
  g <- read_gtfs_tables(feed, c("routes", "trips"))
  ro <- copy(g$routes)
  ro[, blank := is.na(route_short_name) | !nzchar(route_short_name)]
  n <- g$trips[, list(N = .N), by = "route_id"]
  ro <- merge(ro, n, by = "route_id", all.x = TRUE)
  ro[is.na(N), N := 0L]
  s <- ro[, list(routes = .N, routes_blank = sum(blank),
                 pct_routes_blank = round(100 * mean(blank), 1),
                 trips = sum(N), trips_blank = sum(N[blank])), by = "route_type"]
  s[, pct_trips_blank := round(100 * trips_blank / trips, 1)]
  s[order(route_type)]
}


#' Departures at a set of stops, by day of week and by route
#'
#' Reproduces what gtfs_trips_per_zone() counts for one zone, without needing
#' the 483 MB zone polygons: the trips calling at these stops inside the
#' afternoon peak band, on each occurrence of one weekday in the 28 day window.
#' The result is a few trips per hour below the published figure for the LSOA,
#' because the published zone is the LSOA plus a 500 m buffer and picks up a
#' little more; the decomposition by route is what matters.
#'
#' @param feed path to a GTFS zip
#' @param ref the feed's reference date
#' @param stop_ids stops to count departures at
#' @param dow ISO weekday numbers, 3 for Wednesday
#' @return a data.table of dow, departures, tph and the per-route breakdown
station_profile <- function(feed, ref, stop_ids = LEYTONSTONE, dow = c(3, 6)) {
  g <- read_gtfs_tables(
    feed, c("routes", "trips", "calendar", "calendar_dates", "stop_times"),
    select = list(stop_times = c("trip_id", "stop_id", "departure_time")))
  st <- g$stop_times[stop_id %in% stop_ids]
  st <- st[as.integer(substr(departure_time, 1, 2)) %in% AP_HOURS]
  clear_gtfs_scratch(feed)

  tr <- g$trips[trip_id %in% st$trip_id]
  x <- merge(unique(st[, list(trip_id)]),
             tr[, list(trip_id, route_id, service_id = as.character(service_id))],
             by = "trip_id")
  d <- window_service_dates(g, x$service_id, ref)
  d[, wday := ((date + 3L) %% 7L) + 1L]   # 1970-01-01 was a Thursday

  k <- merge(x, d, by = "service_id", allow.cartesian = TRUE)
  k <- merge(k, g$routes[, list(route_id, route_long_name)], by = "route_id")

  res <- lapply(dow, function(w) {
    kk <- k[wday == w]
    per_route <- kk[, list(N = .N), by = c("route_id", "route_long_name")]
    setorder(per_route, -N)
    data.table(
      dow = c("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")[w],
      departures = nrow(kk),
      tph = round(nrow(kk) / (4 * AP_BAND_HOURS), 1),
      routes = paste(sprintf("%s(%s)", per_route$route_id, per_route$N),
                     collapse = " + "),
      line = if (nrow(per_route) > 0) per_route$route_long_name[1] else NA_character_)
  })
  rbindlist(res)
}


#' The published figure for one zone and mode, for comparison
published_zone_tph <- function(year, zone_id = LEYTONSTONE_LSOA,
                               route_type = 1L, cfg = load_cfg()) {
  f <- file.path(cfg$out_dir,
                 sprintf("trips_per_lsoa21_22_by_mode_%s.Rds", year))
  if (!file.exists(f)) return(NULL)
  x <- as.data.frame(readRDS(f))
  s <- x[!is.na(x$zone_id) & x$zone_id == zone_id &
           x$route_type == route_type, , drop = FALSE]
  if (nrow(s) == 0) return(NULL)
  data.table(year = year,
             tph_Wed_AP = s[["tph_Wed_Afternoon Peak"]],
             tph_Sat_AP = s[["tph_Sat_Afternoon Peak"]],
             runs_Wed_AP = s[["runs_Wed_Afternoon Peak"]],
             routes_AP = s[["routes_Afternoon Peak"]])
}


#' How alike two copies of a line are, signature by signature
#'
#' gtfs_deduplicate() calls two trips the same journey only when the whole
#' sequence of (stop, arrival, departure) matches. This measures how far that
#' test gets on a pair of duplicate route copies, against two looser keys, and
#' is the evidence for the second cause: the copies are stopping-pattern
#' variants of the same trains, not byte-identical, so restoring their names
#' is necessary but not sufficient.
#'
#' @return a data.table of signature, shared, only_a, only_b
signature_overlap <- function(feed, route_a, route_b) {
  g <- read_gtfs_tables(
    feed, c("trips", "stop_times"),
    select = list(stop_times = c("trip_id", "stop_id", "stop_sequence",
                                 "arrival_time", "departure_time")))
  tr <- g$trips[route_id %in% c(route_a, route_b)]
  st <- g$stop_times[trip_id %in% tr$trip_id]
  setorderv(st, c("trip_id", "stop_sequence"))
  sig <- st[, list(
    full = paste(stop_id, arrival_time, departure_time, collapse = "~"),
    ends = paste(first(stop_id), first(departure_time),
                 last(stop_id), last(arrival_time)),
    stops = paste(stop_id, collapse = "~")), by = "trip_id"]
  sig <- merge(sig, tr[, list(trip_id, route_id)], by = "trip_id")
  clear_gtfs_scratch(feed)

  one <- function(col) {
    # dcast needs a real column on the left of the formula, so the signature
    # being compared is renamed rather than reached with get()
    tmp <- sig[, list(v = get(col), route_id)]
    p <- dcast(tmp, v ~ route_id, fun.aggregate = length)
    a <- p[[as.character(route_a)]]
    b <- p[[as.character(route_b)]]
    # not `key =`: data.table() would take that as the key to set, not a column
    data.table(signature = col, shared = sum(a > 0 & b > 0),
               only_a = sum(a > 0 & b == 0), only_b = sum(a == 0 & b > 0))
  }
  rbindlist(lapply(c("full", "ends", "stops"), one))
}


#' Candidate deduplication rule for fixed-track modes
#'
#' Two trips of the same operator and line that leave the same first stop at
#' the same time on the same date are the same train. On a metro or heavy rail
#' line that is physically guaranteed in a way it is not for buses, so the
#' journey signature can be relaxed from every call to the two termini and
#' their times without the risk that makes a time tolerance unsafe on the road
#' (see reports/near_duplicate_journeys.md, which excludes the Underground for
#' exactly that reason).
#'
#' The date test is unchanged from gtfs_deduplicate(): copies are ranked with
#' the most-used calendar first, and a copy is removed only where every date it
#' runs is also run by a copy that is kept. So the superseded timetable that
#' covers the first days of a window is never removed.
#'
#' @param feed path to a GTFS zip
#' @param ref the feed's reference date
#' @param route_types modes to apply the rule to
#' @param agency_id optional operator filter
#' @return a character vector of trip_ids the rule would remove
fixed_track_duplicates <- function(feed, ref, route_types = 1L,
                                   agency_id = NULL) {
  g <- read_gtfs_tables(
    feed, c("routes", "trips", "calendar", "calendar_dates", "stop_times"),
    select = list(stop_times = c("trip_id", "stop_id", "stop_sequence",
                                 "arrival_time", "departure_time")))
  want_agency <- agency_id
  ro <- g$routes[route_type %in% route_types]
  if (!is.null(want_agency)) ro <- ro[agency_id %in% want_agency]
  ro <- copy(ro)[, line := normalise_line(route_long_name)]
  tr <- g$trips[route_id %in% ro$route_id]

  st <- g$stop_times[trip_id %in% tr$trip_id]
  setorderv(st, c("trip_id", "stop_sequence"))
  sig <- st[, list(k = paste(first(stop_id), first(departure_time),
                             last(stop_id), last(arrival_time))),
            by = "trip_id"]

  z <- merge(tr[, list(trip_id = as.character(trip_id), route_id,
                       service_id = as.character(service_id))],
             sig[, list(trip_id = as.character(trip_id), k)], by = "trip_id")
  z <- merge(z, ro[, list(route_id, agency_id, line)], by = "route_id")
  z[, grp := paste(agency_id, line, k, sep = "\r")]

  d <- window_service_dates(g, z$service_id, ref)
  if (nrow(d) == 0) return(character(0))
  nd <- d[, list(n_dates = .N), by = "service_id"]
  z <- merge(z, nd, by = "service_id")
  z[, n_grp := .N, by = "grp"]
  z <- z[n_grp > 1L]
  if (nrow(z) == 0) return(character(0))

  setorderv(z, c("grp", "n_dates", "trip_id"), c(1L, -1L, 1L))
  z[, rnk := seq_len(.N), by = "grp"]
  z[, i := .I]
  runs <- merge(z[, list(service_id, i, grp, rnk)], d,
                by = "service_id", allow.cartesian = TRUE)
  runs[, min_rnk := min(rnk), by = c("grp", "date")]
  covered <- runs[, list(redundant = all(min_rnk < rnk)), by = "i"]
  z$trip_id[covered$i[covered$redundant]]
}


#' The same station profile, with a set of trips excluded
#'
#' Used to show what the candidate rule would do to the published figure.
station_profile_excluding <- function(feed, ref, drop_trip_ids,
                                      stop_ids = LEYTONSTONE, dow = c(3, 6)) {
  g <- read_gtfs_tables(
    feed, c("routes", "trips", "calendar", "calendar_dates", "stop_times"),
    select = list(stop_times = c("trip_id", "stop_id", "departure_time")))
  st <- g$stop_times[stop_id %in% stop_ids]
  st <- st[as.integer(substr(departure_time, 1, 2)) %in% AP_HOURS]

  tr <- g$trips[trip_id %in% st$trip_id]
  tr <- tr[!as.character(trip_id) %in% drop_trip_ids]
  x <- merge(unique(st[, list(trip_id)]),
             tr[, list(trip_id, service_id = as.character(service_id))],
             by = "trip_id")
  d <- window_service_dates(g, x$service_id, ref)
  d[, wday := ((date + 3L) %% 7L) + 1L]
  k <- merge(x, d, by = "service_id", allow.cartesian = TRUE)
  rbindlist(lapply(dow, function(w) {
    data.table(dow = c("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")[w],
               departures = nrow(k[wday == w]),
               tph = round(nrow(k[wday == w]) / (4 * AP_BAND_HOURS), 1))
  }))
}


#' London Underground carried by the rail CIF feed
#'
#' README.md says the Underground is not in the CIF feed and that metro
#' coverage depends on TNDS. It is in the CIF feed. run_year() sums the bus
#' feed and the rail feed by zone and route_type, so wherever a station appears
#' in both its service is added twice. The stop ids cannot collide - TIPLOC
#' here against ATCO in TNDS - but the join to zones is spatial, so the
#' coordinates are what matter.
#'
#' @param rail_feed path to a converted rail GTFS zip
#' @return a data.table of the metro stops the rail feed carries
atoc_metro_overlap <- function(rail_feed) {
  g <- read_gtfs_tables(rail_feed, c("agency", "routes", "trips", "stops",
                                     "stop_times"),
                        select = list(stop_times = c("trip_id", "stop_id")))
  ro <- g$routes[route_type == 1L]
  ro <- merge(ro, g$agency[, list(agency_id, agency_name)],
              by = "agency_id", all.x = TRUE)
  tr <- g$trips[route_id %in% ro$route_id]
  st <- g$stop_times[trip_id %in% tr$trip_id]
  clear_gtfs_scratch(rail_feed)

  sp <- g$stops[stop_id %in% unique(st$stop_id)]
  sp <- merge(sp[, list(stop_id, stop_name, stop_lat, stop_lon)],
              st[, list(calls = .N), by = "stop_id"], by = "stop_id")
  agency <- merge(tr[, list(trips = .N), by = "route_id"],
                  ro[, list(route_id, agency_id, agency_name)],
                  by = "route_id")
  list(
    by_agency = agency[, list(routes = .N, trips = sum(trips)),
                       by = c("agency_id", "agency_name")],
    stops = sp[order(-calls)])
}
