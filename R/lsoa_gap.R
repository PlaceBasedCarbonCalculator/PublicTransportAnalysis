# Where do TNDS and the DfT's BODS GTFS disagree most, and why?
#
# R/comparison.R measures the national difference between the three sources
# and splits it into missing services and frequency differences. This file
# takes the same question down to the zone: which LSOAs (Data Zones in
# Scotland) does the choice of source change most, and which individual bus
# routes are responsible.
#
# The counting deliberately reproduces UK2GTFS::gtfs_trips_per_zone(), which
# is what produced the zone totals in the first place, so the per-route
# figures here add up to the zone totals in the comparison output:
#
#  * a stop is joined to every zone whose (widened, overlapping) polygon
#    contains it;
#  * within a zone a trip counts ONCE however many of the zone's stops it
#    calls at (internal_trips_per_zone() de-duplicates on trip_id);
#  * a stop-time with no departure time is dropped before that, because
#    gtfs_trips_per_zone() drops rows whose time band is NA;
#  * a trip's weight is the number of times it runs in the 28-day window,
#    with frequency-based trips weighted by their implied departures.

#' Total bus runs per zone in one comparison source result
#'
#' The per-zone table gtfs_trips_per_zone() produced, reduced to one number
#' per zone: bus trip-runs over the whole 28-day window, all days and all
#' time bands including Night. `tph_daytime_avg` is the measure the pipeline
#' publishes, but it drops Night and weights weekdays, so it is not a total.
zone_bus_runs <- function(cmp_result) {
  tr <- as.data.frame(cmp_result$trips)
  tr <- tr[tr$route_type == 3 & !is.na(tr$zone_id), ]
  runs_cols <- grep("^runs_", names(tr), value = TRUE)
  data.table::data.table(zone_id = as.character(tr$zone_id),
                         runs = rowSums(tr[runs_cols], na.rm = TRUE),
                         tph = tr$tph_daytime_avg)
}

#' Stops of a feed joined to the zones they fall in
#'
#' Same join as gtfs_trips_per_zone(): points in 4326, and a stop inside
#' several zones is counted in each.
feed_stops_in_zones <- function(gtfs, zones) {
  st <- as.data.frame(gtfs$stops)
  st <- st[!is.na(st$stop_lon) & !is.na(st$stop_lat), ]
  keep <- intersect(c("stop_id", "stop_name"), names(st))
  pts <- sf::st_as_sf(st[, c(keep, "stop_lon", "stop_lat")],
                      coords = c("stop_lon", "stop_lat"), crs = 4326)
  j <- sf::st_join(pts, zones[, "zone_id"], left = FALSE)
  out <- data.table::as.data.table(sf::st_drop_geometry(j))
  out[, stop_id := as.character(stop_id)]
  if (!"stop_name" %in% names(out)) out[, stop_name := NA_character_]
  out[!is.na(zone_id), list(stop_id, stop_name, zone_id = as.character(zone_id))]
}

#' Bus runs per zone and route for one feed, over a set of zones
#'
#' @param gtfs a feed as read by read_feed() (route types not yet harmonised)
#' @param zones zone polygons in 4326 with a `zone_id` column, already
#'   subset to the zones of interest
#' @param win study window
#' @return list(by_route = zone x route runs, stops = stops in those zones)
zone_route_runs <- function(gtfs, zones, win) {
  gtfs$routes$route_type <- map_route_type_simple(gtfs$routes$route_type)
  gtfs <- UK2GTFS::gtfs_trim_dates(gtfs, startdate = win$startdate,
                                   enddate = win$enddate)
  sz <- feed_stops_in_zones(gtfs, zones)
  runs <- trip_runs_in_window(gtfs)

  routes <- data.table::as.data.table(as.data.frame(gtfs$routes))
  routes <- routes[route_type == 3L]
  routes[, route_id := as.character(route_id)]

  trips <- data.table::as.data.table(as.data.frame(gtfs$trips))
  trips <- trips[, list(trip_id = as.character(trip_id),
                        route_id = as.character(route_id),
                        service_id = as.character(service_id))]
  trips <- trips[route_id %in% routes$route_id]

  st <- data.table::as.data.table(as.data.frame(gtfs$stop_times))
  # Drop stop-times with no departure time first: gtfs_trips_per_zone() cuts
  # the hour into time bands and discards NA bands, so a trip is only counted
  # in a zone where it has a timed departure.
  st <- st[!is.na(departure_time)]
  st <- st[, list(trip_id = as.character(trip_id),
                  stop_id = as.character(stop_id),
                  departure_time = as.character(departure_time))]
  st <- st[stop_id %in% sz$stop_id]
  st <- merge(st, unique(sz[, list(stop_id, zone_id)]), by = "stop_id",
              allow.cartesian = TRUE)
  st <- st[trip_id %in% trips$trip_id]

  dup <- zone_duplicate_runs(st, trips, routes, service_dates_in_window(gtfs, win))

  # One row per trip per zone, matching internal_trips_per_zone()'s dedup
  tz <- unique(st[, list(trip_id, zone_id)])
  tz <- merge(tz, trips[, list(trip_id, route_id)], by = "trip_id")
  tz <- merge(tz, runs, by = "trip_id", all.x = TRUE)
  tz[is.na(runs), runs := 0]

  by_route <- tz[, list(runs = sum(runs), trips = .N),
                 by = list(zone_id, route_id)]
  by_route <- merge(by_route, routes[, list(route_id, route_short_name,
                                            route_long_name)],
                    by = "route_id", all.x = TRUE)
  list(by_route = by_route[], stops = sz[], dup = dup[])
}

#' Dates each service operates inside the window, with GTFS semantics
#'
#' Needed to ask whether two trips are the same journey on the *same day*. A
#' school-term journey and its holiday twin have identical times and
#' complementary calendars, which is correct modelling rather than duplication,
#' so any duplicate test that ignores dates over-counts heavily.
service_dates_in_window <- function(gtfs, win) {
  dow <- c("monday", "tuesday", "wednesday", "thursday", "friday", "saturday",
           "sunday")
  dates <- seq(win$startdate, win$enddate, by = 1)
  cal <- data.table::as.data.table(as.data.frame(gtfs$calendar))
  cal[, service_id := as.character(service_id)]
  cal[, `:=`(start_date = as.Date(start_date), end_date = as.Date(end_date))]

  base <- data.table::rbindlist(lapply(dates, function(d) {
    col <- dow[lubridate::wday(d, week_start = 1)]
    s <- cal[!is.na(start_date) & !is.na(end_date) & start_date <= d &
               end_date >= d & get(col) == 1L, service_id]
    if (!length(s)) return(NULL)
    data.table::data.table(service_id = s, date = d)
  }))
  if (is.null(base) || nrow(base) == 0) {
    base <- data.table::data.table(service_id = character(0),
                                   date = as.Date(character(0)))
  }

  cd <- data.table::as.data.table(as.data.frame(gtfs$calendar_dates))
  if (nrow(cd) > 0) {
    cd[, `:=`(service_id = as.character(service_id), date = as.Date(date))]
    cd <- cd[date >= win$startdate & date <= win$enddate]
    cd <- unique(cd, by = c("service_id", "date", "exception_type"))
    rem <- cd[exception_type == 2L, list(service_id, date)]
    add <- cd[exception_type == 1L, list(service_id, date)]
    if (nrow(rem)) base <- base[!rem, on = c("service_id", "date")]
    if (nrow(add)) base <- unique(data.table::rbindlist(list(base, add)))
  }
  base[]
}

#' Runs in a zone that are the same journey twice on the same day
#'
#' The unit is the zone's own count, so a journey is identified by the (stop,
#' departure time) pairs it makes at stops *inside the zone*, not by its whole
#' national itinerary: two trips indistinguishable at every one of the zone's
#' stops on the same day contribute twice to that zone's total for one bus.
#'
#' The route number has to match too. A one-stop signature is otherwise weak -
#' two unrelated services can genuinely leave the same stop in the same minute -
#' whereas duplicate publication of a service keeps its number, which is how the
#' two route_ids of Arriva London's 279 present.
#'
#' @param zs stop-times at zone stops: trip_id, zone_id, stop_id, departure_time
#' @param trips trip_id, route_id, service_id
#' @param routes route_id, route_short_name
#' @param sdates service_dates_in_window() output
zone_duplicate_runs <- function(zs, trips, routes, sdates) {
  z <- merge(zs, trips, by = "trip_id")
  z <- merge(z, routes[, list(route_id, route_short_name)], by = "route_id",
             all.x = TRUE)
  # Number each distinct (stop, time) pair and paste the numbers rather than the
  # text. Identity is all that matters here, and pasting a whole bus station's
  # ATCO codes and timestamps for every trip is far slower and much heavier.
  z[, pair := paste0(stop_id, "\r", departure_time)]
  z[, pid := match(pair, unique(pair))][, pair := NULL]
  data.table::setorder(z, trip_id, zone_id, pid)
  sig <- z[, list(sig = paste(pid, collapse = ",")),
           by = list(trip_id, zone_id, route_id, route_short_name, service_id)]
  # integer key: the join below multiplies rows by operating days
  sig[, sig_id := match(sig, unique(sig))][, sig := NULL]

  td <- merge(sig, sdates, by = "service_id", allow.cartesian = TRUE)
  cells <- td[, list(n = .N), by = list(zone_id, date, route_short_name, sig_id)]
  cells[, list(trip_days = sum(n), dup_runs = sum(n - 1L)), by = zone_id]
}

#' Duplicate runs across a whole feed
#'
#' The national counterpart of zone_duplicate_runs(). Here a journey is its
#' entire itinerary - every (stop, departure time) pair of the trip - so this is
#' a stricter test than the zone one, which can only see the part of a trip
#' inside the zone.
#'
#' Frequency-based trips are counted once per operating day rather than once per
#' implied departure, so `trip_days` differs slightly from the run totals
#' elsewhere wherever a feed uses frequencies.txt; `frequencies` records how many
#' rows that is so the difference can be judged.
feed_duplicate_runs <- function(gtfs, win) {
  routes <- data.table::as.data.table(as.data.frame(gtfs$routes))
  routes <- routes[route_type == 3L][, route_id := as.character(route_id)]
  trips <- data.table::as.data.table(as.data.frame(gtfs$trips))
  trips <- trips[, list(trip_id = as.character(trip_id),
                        route_id = as.character(route_id),
                        service_id = as.character(service_id))]
  trips <- trips[route_id %in% routes$route_id]

  st <- data.table::as.data.table(as.data.frame(gtfs$stop_times))
  st <- st[!is.na(departure_time)]
  st <- st[, list(trip_id = as.character(trip_id),
                  stop_id = as.character(stop_id),
                  departure_time = as.character(departure_time))]
  st <- st[trip_id %in% trips$trip_id]
  # Build the pair key once - this table has tens of millions of rows
  st[, pair := paste0(stop_id, "\r", departure_time)]
  st[, pid := match(pair, unique(pair))][, pair := NULL]
  data.table::setorder(st, trip_id, pid)
  sig <- st[, list(sig = paste(pid, collapse = ",")), by = trip_id]
  sig[, sig_id := match(sig, unique(sig))][, sig := NULL]

  td <- merge(merge(trips, sig, by = "trip_id"),
              service_dates_in_window(gtfs, win), by = "service_id",
              allow.cartesian = TRUE)
  cells <- td[, list(n = .N), by = list(sig_id, date)]

  data.frame(
    bus_trips = nrow(trips),
    distinct_journeys = data.table::uniqueN(sig$sig_id),
    trip_days = nrow(td),
    duplicate_runs = sum(cells$n - 1L),
    share_duplicate = if (nrow(td)) sum(cells$n - 1L) / nrow(td) else NA_real_,
    frequencies = if (is.null(gtfs$frequencies)) 0L else nrow(gtfs$frequencies),
    stringsAsFactors = FALSE)
}

#' A readable locality for a zone, from the names of the stops inside it
#'
#' Zone polygons carry only the LSOA/Data Zone code, so the report names each
#' zone by the commonest locality prefix among its stops (NaPTAN stop names
#' are "Locality, Description"), falling back to the commonest whole name.
zone_locality <- function(stops) {
  if (nrow(stops) == 0) return(data.table::data.table())
  s <- data.table::copy(stops)
  s[, loc := trimws(sub(",.*$", "", stop_name))]
  s[is.na(loc) | loc == "", loc := stop_name]
  s <- s[!is.na(loc) & loc != ""]
  if (nrow(s) == 0) return(data.table::data.table())
  s[, list(locality = names(sort(table(loc), decreasing = TRUE))[1],
           stops = data.table::uniqueN(stop_id)), by = zone_id]
}

#' Zone-level TNDS vs BODS GTFS disagreement, and the routes behind it
#'
#' @param comparison_path data/bus_source_comparison_<year>.Rds
#' @param zones_path zone polygons
#' @param cmp_tnds,cmp_bods the two comparison_source_result() objects, used
#'   for the exact zone totals and for the cross-source route matching
#' @param top_n how many zones to investigate in detail
lsoa_gap_analysis <- function(comparison_path, zones_path, cmp_tnds, cmp_bods,
                              top_n = 30, cfg = load_cfg()) {
  suppressMessages(sf::sf_use_s2(FALSE))
  cmp <- readRDS(comparison_path)
  year <- cmp$year
  win <- cmp$window
  spec <- cmp$snapshot

  # --- national picture, exact totals -------------------------------------
  a <- zone_bus_runs(cmp_tnds)
  b <- zone_bus_runs(cmp_bods)
  data.table::setnames(a, c("runs", "tph"), c("runs_tnds", "tph_tnds"))
  data.table::setnames(b, c("runs", "tph"), c("runs_bods", "tph_bods"))
  z <- merge(a, b, by = "zone_id", all = TRUE)
  # A zone present in one source only genuinely has no counted service in the
  # other, so the outer join's NAs are zeros
  data.table::setnafill(z, fill = 0, cols = c("runs_tnds", "runs_bods",
                                              "tph_tnds", "tph_bods"))
  z[, gap := runs_tnds - runs_bods]
  z[, gap_tph := tph_tnds - tph_bods]
  z[, larger := pmax(runs_tnds, runs_bods)]
  z[, rel := ifelse(larger > 0, abs(gap) / larger, 0)]
  z[, country := substr(zone_id, 1, 1)]

  # Rank on the absolute run difference: "biggest disagreement in total bus
  # service". Zones where the two sources differ by a large share of a small
  # service are reported separately rather than mixed in, because a handful of
  # runs on a rural zone is a different kind of finding.
  data.table::setorderv(z, "gap", -1L)
  top_tnds <- utils::head(z, top_n)
  data.table::setorderv(z, "gap", 1L)
  top_bods <- utils::head(z, top_n)
  top <- unique(data.table::rbindlist(list(top_tnds, top_bods)))

  # --- per-route attribution in those zones --------------------------------
  zones <- readRDS(zones_path)
  names(zones)[1] <- "zone_id"
  zones <- zones[zones$zone_id %in% top$zone_id, ]
  zones <- sf::st_transform(zones, 4326)

  per_source <- list()
  stops_all <- list()
  dup_all <- list()
  dup_nat <- list()
  for (src in c("tnds", "bods_gtfs")) {
    message("lsoa_gap: reading ", src, " (", spec[[src]], ")")
    gtfs <- read_feed(spec[[src]], cfg)
    rr <- zone_route_runs(gtfs, zones, win)
    per_source[[src]] <- rr$by_route
    stops_all[[src]] <- rr$stops
    dup_all[[src]] <- rr$dup
    message("lsoa_gap: whole-feed duplicate check, ", src)
    gtfs$routes$route_type <- map_route_type_simple(gtfs$routes$route_type)
    dup_nat[[src]] <- feed_duplicate_runs(
      UK2GTFS::gtfs_trim_dates(gtfs, startdate = win$startdate,
                               enddate = win$enddate), win)
    rm(gtfs, rr); gc()
  }
  dup <- data.table::rbindlist(dup_all, idcol = "source")
  dup <- data.table::dcast(dup, zone_id ~ source,
                           value.var = c("trip_days", "dup_runs"), fill = 0)
  dup_national <- data.table::rbindlist(dup_nat, idcol = "source")

  # --- match the routes across the two sources -----------------------------
  # Same matching the national comparison uses, run on the two sources being
  # compared so every route in these zones gets a service id shared with its
  # counterpart in the other source where one exists.
  matched <- match_route_services(list(tnds = cmp_tnds$routes,
                                       bods_gtfs = cmp_bods$routes))
  members <- matched$members[, list(source, route_id, service)]

  long <- data.table::rbindlist(list(
    cbind(per_source$tnds, source = "tnds"),
    cbind(per_source$bods_gtfs, source = "bods_gtfs")), fill = TRUE)
  long <- merge(long, members, by = c("source", "route_id"), all.x = TRUE)
  # A route with no service id (no stops, so never a matching candidate) can
  # still hold runs; give it a key of its own so it is not silently merged.
  long[is.na(service), service := -seq_len(.N)]

  svc <- long[, list(runs = sum(runs), routes = data.table::uniqueN(route_id),
                     name = route_short_name[which.max(runs)],
                     long_name = route_long_name[which.max(runs)]),
              by = list(zone_id, service, source)]
  wide <- data.table::dcast(svc, zone_id + service ~ source,
                            value.var = "runs", fill = 0)
  if (!"tnds" %in% names(wide)) wide[, tnds := 0]
  if (!"bods_gtfs" %in% names(wide)) wide[, bods_gtfs := 0]
  lbl <- svc[order(-runs), list(name = name[1], long_name = long_name[1]),
             by = list(zone_id, service)]
  wide <- merge(wide, lbl, by = c("zone_id", "service"))
  wide[, gap := tnds - bods_gtfs]
  wide[, cause := data.table::fcase(
    bods_gtfs == 0, "only in TNDS",
    tnds == 0, "only in BODS GTFS",
    default = "both, different frequency")]
  data.table::setorderv(wide, c("zone_id", "gap"), c(1L, -1L))

  locality <- zone_locality(data.table::rbindlist(stops_all, fill = TRUE))
  top <- merge(top, locality, by = "zone_id", all.x = TRUE)

  # How each zone's gap divides between services one source lacks entirely
  # and services both carry at different frequencies
  split <- wide[, list(
    gap_services_only_tnds = sum(gap[cause == "only in TNDS"]),
    gap_services_only_bods = sum(gap[cause == "only in BODS GTFS"]),
    gap_frequency = sum(gap[cause == "both, different frequency"]),
    n_only_tnds = sum(cause == "only in TNDS"),
    n_only_bods = sum(cause == "only in BODS GTFS"),
    n_both = sum(cause == "both, different frequency")), by = zone_id]
  top <- merge(top, split, by = "zone_id", all.x = TRUE)
  top <- merge(top, dup, by = "zone_id", all.x = TRUE)
  data.table::setorderv(top, "gap", -1L)

  # Keep the per-source, per-route detail. Without it, any question about *why*
  # a service differs - whether one source splits it across several route_ids,
  # whether the trips or the runs-per-trip differ - needs both national feeds
  # read again, which is an hour of work to answer a five-minute question.
  by_route <- data.table::rbindlist(per_source, idcol = "source", fill = TRUE)

  out <- list(year = year, window = win, snapshot = spec,
              zones = z[], top = top[], services = wide[], duplication = dup[],
              duplication_national = dup_national[], by_route = by_route[],
              national = list(
                zones = nrow(z),
                runs_tnds = sum(z$runs_tnds),
                runs_bods = sum(z$runs_bods),
                zones_tnds_higher = sum(z$gap > 0),
                zones_bods_higher = sum(z$gap < 0),
                zones_equal = sum(z$gap == 0),
                zones_only_tnds = sum(z$runs_bods == 0 & z$runs_tnds > 0),
                zones_only_bods = sum(z$runs_tnds == 0 & z$runs_bods > 0)))

  dir.create(cfg$out_dir, showWarnings = FALSE, recursive = TRUE)
  path <- file.path(cfg$out_dir, sprintf("lsoa_disagreement_%s.Rds", year))
  saveRDS(out, path)
  path
}

#' Knit the LSOA disagreement report to markdown
render_lsoa_gap_report <- function(gap_path, cfg = load_cfg()) {
  dir.create(cfg$report_dir, showWarnings = FALSE, recursive = TRUE)
  env <- new.env(parent = globalenv())
  env$gap_path <- normalizePath(gap_path)
  old_wd <- setwd(cfg$report_dir)
  on.exit(setwd(old_wd), add = TRUE)
  knitr::knit(input = "lsoa_disagreement.Rmd",
              output = "lsoa_disagreement.md", envir = env, quiet = TRUE)
  file.path(cfg$report_dir, "lsoa_disagreement.md")
}
