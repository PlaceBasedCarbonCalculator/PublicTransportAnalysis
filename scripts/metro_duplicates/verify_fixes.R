# Check the fixes, after the fact.
#
# metro_duplicates.R measures the defect as the published feeds carry it. This
# script measures the *fixes*: it answers the questions section 6 of
# reports/metro_duplicate_copies.md originally listed as open, and every table
# in sections 6.1 to 6.4 comes from here.
#
# Run from the repo root, with UK2GTFS installed from branch
# `fixed-track-duplicates` or later:
#   Rscript scripts/metro_duplicates/verify_fixes.R
#
# Standalone, like its sibling - not a targets stage. It writes only
# data/metro_fix_checks.Rds. Roughly half an hour, nearly all of it reading
# stop_times out of merged TNDS feeds.

source("scripts/metro_duplicates/metro_duplicates.R")

OUT <- "data/metro_fix_checks.Rds"

# The two snapshots of 2026. They are not in year_sources() - 2026 is not an
# analysis year - but they are the only pair of feeds this repo holds that
# cover the same year twice, which is the only way to ask whether the
# duplication is a property of the year or of the snapshot.
SNAPSHOTS_2026 <- data.table(
  feed = c("gtfs/tnds_20260204_merged.zip", "gtfs/tnds_20260726_merged.zip"),
  ref  = c("2026-02-04", "2026-07-26"),
  label = c("Feb 2026", "Jul 2026"))

# Regional feeds for the bus check. London carries buses and the Underground
# in one file, which is the case that matters; the North West is the control,
# a region with trams and no metro.
BUS_CHECK_FEEDS <- c("gtfs/cache/tnds_20211012/L.zip",
                     "gtfs/cache/tnds_20241004/L.zip",
                     "gtfs/cache/tnds_20241004/NW.zip",
                     "gtfs/cache/tnds_20251003/L.zip")

res <- list()
years <- metro_feed_years()


#' Does the fixed-track rule change anything for buses?
#'
#' The relaxed journey signature is gated behind `gtfs_deduplicate(fixed_track
#' = )`, so bus behaviour should be identical to the old code. That is an
#' argument from the code - the route grouping key contains `route_type`, so a
#' bus can never share a group with a fixed-track route - and this is the
#' measurement of it. `fixed_track = integer(0)` is exactly the old behaviour.
#'
#' Runs the deduplicator twice over a whole feed, so it is the slow part of
#' this script.
#'
#' @param feed path to a converted GTFS zip
#' @return a data.table of feed, route_type, trips and the four removal counts
bus_unchanged <- function(feed) {
  g <- UK2GTFS::gtfs_read(feed)
  g$shapes <- NULL
  g$stops <- g$stops[!is.na(g$stops$stop_lon), ]
  g <- UK2GTFS::gtfs_clean(g)

  rt <- data.table(route_id = as.character(g$routes$route_id),
                   route_type = as.integer(g$routes$route_type))
  tr <- data.table(trip_id = as.character(g$trips$trip_id),
                   route_id = as.character(g$trips$route_id))
  tr <- merge(tr, rt, by = "route_id", all.x = TRUE)

  old <- UK2GTFS::gtfs_deduplicate(g, fixed_track = integer(0), quiet = TRUE)
  new <- UK2GTFS::gtfs_deduplicate(g, fixed_track = c(0L, 1L, 2L), quiet = TRUE)
  gone_old <- !tr$trip_id %in% as.character(old$trips$trip_id)
  gone_new <- !tr$trip_id %in% as.character(new$trips$trip_id)
  tr[, `:=`(gone_old = gone_old, gone_new = gone_new)]

  out <- tr[, list(trips = .N,
                   rm_old = sum(gone_old),
                   rm_new = sum(gone_new),
                   only_old = sum(gone_old & !gone_new),
                   only_new = sum(gone_new & !gone_old)),
            by = "route_type"]
  out[, feed := basename(feed)]
  setorder(out, route_type)
  out[]
}


#' Trips removed and phantom trip-days, on one denominator
#'
#' The report originally compared "% of trips removed" against "% of phantom
#' trip-days" and read the difference as the rule over-reaching. They are not
#' comparable: one counts rows in trips.txt, the other counts trip-days inside
#' the 28 day window, and a duplicate copy carries a short calendar. This puts
#' both on trip-days.
#'
#' @return a data.table of year, trips, trip-days and both removal rates
removed_vs_phantom <- function(feed, ref, agency_id = "LUL") {
  drop <- fixed_track_duplicates(feed, ref, route_types = 1L,
                                 agency_id = agency_id)
  g <- read_gtfs_tables(feed, c("routes", "trips", "calendar",
                                "calendar_dates"))
  want_agency <- agency_id
  ro <- g$routes[route_type == 1L & agency_id %in% want_agency]
  tr <- g$trips[as.character(route_id) %in% as.character(ro$route_id)]
  d <- window_service_dates(g, tr$service_id, ref)
  nd <- d[, list(n_dates = .N), by = "service_id"]
  tr <- merge(tr[, list(trip_id = as.character(trip_id),
                        service_id = as.character(service_id))],
              nd, by = "service_id")
  ph <- phantom_trip_days(feed, ref, route_types = 1L,
                          agency_id = agency_id, by = "route_type")
  removed_days <- sum(tr$n_dates[tr$trip_id %in% drop])
  data.table(
    trips = nrow(tr),
    trips_removed = length(drop),
    pct_trips = round(100 * length(drop) / nrow(tr), 1),
    trip_days = sum(tr$n_dates),
    trip_days_removed = removed_days,
    pct_trip_days = round(100 * removed_days / sum(tr$n_dates), 1),
    phantom_pct = ph$pct[1])
}


#' What survives the rule, route by route
#'
#' The residual: after the rule fires, which routes still supply departures at
#' the station, and how many of their trips were dropped. This is what shows
#' that the surviving primary copy is correct on its own and the excess is the
#' operating-date test declining to remove trips that run on a date the kept
#' copy does not cover.
#'
#' @return a data.table of route, whether the rule dropped it, and departures
#'   on each weekday asked for
residual_by_route <- function(feed, ref, stop_ids = LEYTONSTONE,
                              dow = c(3, 6)) {
  drop <- fixed_track_duplicates(feed, ref, route_types = 1L,
                                 agency_id = "LUL")
  g <- read_gtfs_tables(
    feed, c("routes", "trips", "calendar", "calendar_dates", "stop_times"),
    select = list(stop_times = c("trip_id", "stop_id", "departure_time")))
  st <- g$stop_times[stop_id %in% stop_ids]
  st <- st[as.integer(substr(departure_time, 1, 2)) %in% AP_HOURS]
  tr <- g$trips[trip_id %in% st$trip_id]
  tr[, dropped := as.character(trip_id) %in% drop]
  x <- merge(unique(st[, list(trip_id)]),
             tr[, list(trip_id, route_id, dropped,
                       service_id = as.character(service_id))],
             by = "trip_id")
  d <- window_service_dates(g, x$service_id, ref)
  d[, wday := ((date + 3L) %% 7L) + 1L]
  k <- merge(x, d, by = "service_id", allow.cartesian = TRUE)
  clear_gtfs_scratch(feed)
  k <- k[wday %in% dow]
  if (nrow(k) == 0) return(NULL)
  out <- k[, list(departures = .N), by = c("route_id", "dropped", "wday")]
  out[, day := c("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")[wday]]
  setorderv(out, c("wday", "route_id", "dropped"))
  out[, list(route_id, dropped, day, departures)]
}


#' Departures split by platform
#'
#' The two Leytonstone stops are the two directions. Splitting the count is
#' what makes the figure comparable with a published line frequency, which is
#' always quoted per direction, and a lopsided split would itself be a sign
#' that something is being counted twice on one side only.
#'
#' @return a data.table of stop, departures and tph
platform_split <- function(feed, ref, stop_ids = LEYTONSTONE, dow = 3) {
  g <- read_gtfs_tables(
    feed, c("trips", "calendar", "calendar_dates", "stops", "stop_times"),
    select = list(stop_times = c("trip_id", "stop_id", "departure_time")))
  st <- g$stop_times[stop_id %in% stop_ids]
  st <- st[as.integer(substr(departure_time, 1, 2)) %in% AP_HOURS]
  x <- merge(st[, list(trip_id, stop_id)],
             g$trips[, list(trip_id, service_id = as.character(service_id))],
             by = "trip_id")
  d <- window_service_dates(g, x$service_id, ref)
  d[, wday := ((date + 3L) %% 7L) + 1L]
  k <- merge(x, d, by = "service_id", allow.cartesian = TRUE)[wday %in% dow]
  nm <- g$stops[stop_id %in% stop_ids, list(stop_id, stop_name)]
  clear_gtfs_scratch(feed)
  out <- k[, list(departures = .N), by = "stop_id"]
  out <- merge(out, nm, by = "stop_id", all.x = TRUE)
  out[, tph := round(departures / (4 * AP_BAND_HOURS), 1)]
  out[]
}


#' Every metro route the rail CIF feed carries, by operator
#'
#' atoc_metro_overlap() answers which London Underground stations the CIF feed
#' duplicates. This is the wider question - what else in the feed is
#' route_type 1 - and the answer is the Tyne and Wear Metro in every year, plus
#' two single-trip strays.
#'
#' @return a data.table of feed, agency and trip counts
rail_metro_by_agency <- function(rail_feed) {
  g <- read_gtfs_tables(rail_feed, c("agency", "routes", "trips"))
  ro <- g$routes[route_type == 1L]
  if (nrow(ro) == 0) return(NULL)
  n <- g$trips[as.character(route_id) %in% as.character(ro$route_id),
               list(trips = .N), by = "route_id"]
  ro <- merge(ro, n, by = "route_id", all.x = TRUE)
  ro <- merge(ro, g$agency[, list(agency_id, agency_name)],
              by = "agency_id", all.x = TRUE)
  clear_gtfs_scratch(rail_feed)
  out <- ro[, list(routes = .N, trips = sum(trips, na.rm = TRUE)),
            by = c("agency_id", "agency_name")]
  out[, feed := basename(rail_feed)]
  setorder(out, -trips)
  out[]
}


#' How much of the published output the metro defect can reach
#'
#' Bounds the downstream effect without a reconversion: metro's share of zones
#' and of national afternoon-peak tph. Multiplying that share by the phantom
#' rate gives the upper bound the report quotes.
#'
#' @return a data.table of year, zone counts and metro share
metro_share <- function(years = c(2004:2011, 2014:2025), cfg = load_cfg()) {
  col <- "tph_Wed_Afternoon Peak"
  rbindlist(lapply(years, function(y) {
    f <- file.path(cfg$out_dir,
                   sprintf("trips_per_lsoa21_22_by_mode_%s.Rds", y))
    if (!file.exists(f)) return(NULL)
    x <- as.data.table(readRDS(f))
    if (!col %in% names(x)) return(NULL)
    tot <- sum(x[[col]], na.rm = TRUE)
    m <- x[route_type == 1L]
    data.table(year = y,
               zones_any = uniqueN(x$zone_id),
               zones_metro = uniqueN(m$zone_id),
               tph_all = round(tot),
               tph_metro = round(sum(m[[col]], na.rm = TRUE)),
               pct_metro = round(100 * sum(m[[col]], na.rm = TRUE) / tot, 2))
  }), fill = TRUE)
}


# ---- 6.1 the spikes are physically impossible ----------------------------
message("Platform split at Leytonstone")
res$platform <- rbindlist(lapply(seq_len(nrow(years)), function(i) {
  message("  ", years$year[i])
  platform_split(years$feed[i], years$ref[i])[, year := years$year[i]][]
}))

# ---- 6.2 tram and rail ---------------------------------------------------
message("Tram and rail duplication, by line")
res$tram_rail <- rbindlist(lapply(seq_len(nrow(years)), function(i) {
  message("  ", years$year[i])
  rbindlist(lapply(c(0L, 2L), function(rt) {
    p <- phantom_trip_days(years$feed[i], years$ref[i],
                           route_types = rt, by = "line")
    if (nrow(p) == 0) NULL else p[, year := years$year[i]][]
  }), fill = TRUE)
}), fill = TRUE)

# ---- 6.3 the same year, twice --------------------------------------------
message("Two snapshots of 2026")
res$stability <- rbindlist(lapply(seq_len(nrow(SNAPSHOTS_2026)), function(i) {
  message("  ", SNAPSHOTS_2026$label[i])
  p <- phantom_trip_days(SNAPSHOTS_2026$feed[i], SNAPSHOTS_2026$ref[i],
                         route_types = 1L, agency_id = "LUL", by = "line")
  p[, snapshot := SNAPSHOTS_2026$label[i]][]
}), fill = TRUE)
res$stability_mode <- rbindlist(lapply(seq_len(nrow(SNAPSHOTS_2026)),
                                       function(i) {
  p <- phantom_trip_days(SNAPSHOTS_2026$feed[i], SNAPSHOTS_2026$ref[i],
                         by = "route_type")
  p[, snapshot := SNAPSHOTS_2026$label[i]][]
}), fill = TRUE)
res$stability_station <- rbindlist(lapply(seq_len(nrow(SNAPSHOTS_2026)),
                                          function(i) {
  p <- station_profile(SNAPSHOTS_2026$feed[i], SNAPSHOTS_2026$ref[i])
  p[, snapshot := SNAPSHOTS_2026$label[i]][]
}), fill = TRUE)

# ---- Fix B: bus unchanged, and the two rates reconciled ------------------
message("Removed against phantom, on one denominator")
res$removed_vs_phantom <- rbindlist(lapply(seq_len(nrow(years)), function(i) {
  message("  ", years$year[i])
  removed_vs_phantom(years$feed[i], years$ref[i])[, year := years$year[i]][]
}), fill = TRUE)

message("What survives the rule at Leytonstone")
res$residual <- rbindlist(lapply(which(years$year %in% c(2021, 2025)),
                                 function(i) {
  r <- residual_by_route(years$feed[i], years$ref[i])
  if (is.null(r)) NULL else r[, year := years$year[i]][]
}), fill = TRUE)

message("Bus removals, old rule against new")
res$bus_unchanged <- rbindlist(lapply(BUS_CHECK_FEEDS, function(f) {
  if (!file.exists(f)) {
    message("  skipped, not present: ", f)
    return(NULL)
  }
  message("  ", basename(dirname(f)), "/", basename(f))
  bus_unchanged(f)
}), fill = TRUE)

# ---- 4.1 revisited, and 6.4 ----------------------------------------------
message("Metro in the rail feeds, by operator")
res$rail_metro <- rbindlist(lapply(unique(years$rail_feed[
  !is.na(years$rail_feed)]), rail_metro_by_agency), fill = TRUE)

message("Metro's share of the published output")
res$metro_share <- metro_share()

saveRDS(res, OUT)
message("Written ", OUT)


# ---- what the report quotes ----------------------------------------------

cat("\n=== 6.1 Leytonstone by platform, Wednesday afternoon peak (tph) ===\n")
print(dcast(res$platform, year ~ stop_id, value.var = "tph"))

cat("\n=== 6.2 tram and rail duplication, lines with any phantom ===\n")
print(res$tram_rail[phantom > 0,
                    list(year, route_type, line, trip_days, phantom, pct)])

cat("\n=== 6.3 the same year, two snapshots: LUL by line (%) ===\n")
print(dcast(res$stability, line ~ snapshot, value.var = "pct"), nrow = 40)
cat("\n--- and by mode ---\n")
print(dcast(res$stability_mode, route_type ~ snapshot, value.var = "pct"))
cat("\n--- and at Leytonstone ---\n")
print(res$stability_station[, list(snapshot, dow, departures, tph)])

cat("\n=== Fix B: removed and phantom, both as trip-days ===\n")
print(res$removed_vs_phantom[, list(year, trips, pct_trips, trip_days,
                                    pct_trip_days, phantom_pct)])

cat("\n=== Fix B: what survives the rule at Leytonstone ===\n")
print(res$residual)

cat("\n=== Fix B: bus removals, old rule against new ===\n")
print(res$bus_unchanged[, list(feed, route_type, trips, rm_old, rm_new,
                               only_old, only_new)])
bus <- res$bus_unchanged[route_type == 3L]
cat("bus removals identical in every feed: ",
    all(bus$only_old == 0 & bus$only_new == 0), "\n")
other <- res$bus_unchanged[!route_type %in% c(0L, 1L, 2L)]
cat("all non fixed-track modes identical:  ",
    all(other$only_old == 0 & other$only_new == 0), "\n")

cat("\n=== 4.1 metro in the rail CIF feeds, by operator ===\n")
print(dcast(res$rail_metro, agency_id + agency_name ~ feed,
            value.var = "trips"))

cat("\n=== 6.4 metro's share of the published output ===\n")
print(res$metro_share)
