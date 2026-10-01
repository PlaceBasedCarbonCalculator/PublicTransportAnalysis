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
#  * a stop is joined to every zone whose polygon contains it (with the plain
#    boundaries this analysis uses, that is one zone per stop);
#  * within a zone a trip counts ONCE however many of the zone's stops it
#    calls at (internal_trips_per_zone() de-duplicates on trip_id);
#  * a stop-time with no departure time is dropped before that, because
#    gtfs_trips_per_zone() drops rows whose time band is NA;
#  * a trip's weight is the number of times it runs in the 28-day window,
#    with frequency-based trips weighted by their implied departures.
#
# Everything here is measured on the DEDUPLICATED feed, like every other
# count in the repo: the question is what disagreement is left between the
# sources once neither is describing the same bus twice. The duplication
# tables therefore no longer measure the sources as published - they measure
# what UK2GTFS::gtfs_deduplicate() deliberately left behind. It removes a copy
# only when the whole itinerary matches, the route agrees and the dates are
# redundant, whereas zone_duplicate_runs() and feed_duplicate_runs() ask only
# whether two trips are indistinguishable on the day. What they now report is
# the gap between those two tests: partial calendar overlaps, and copies
# published under different route numbers or operators. Any zone where that
# residual is large is a zone whose remaining gap is still a counting
# artefact rather than a difference in service.
#
# Both duplicate tests identify a journey by its WHOLE itinerary. The
# zone-level one used to identify it by the part inside the zone, which
# over-counted badly on dense urban corridors - see zone_duplicate_runs() for
# the measurement that forced the change.
#
# Two things beyond the per-route attribution:
#
#  * mode_gap_analysis() does the same comparison for every mode, from the
#    per-zone counts comparison_source_result() already produced. Nothing in
#    this file was ever non-bus before, and the largest non-bus disagreement
#    turns out not to be missing service but disputed classification -
#    mode_swap_zones() detects it.
#  * gap_verdict() decides, per zone and where the evidence allows, which of
#    the two sources is misdescribing the service, by splitting the gap into
#    journeys against operating days and weighing that against each source's
#    residual duplication and daily profile.

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

#' The modes this analysis reports, in the order the report presents them
#'
#' Harmonised route types as map_route_type_simple() leaves them, so 200 is
#' coach rather than one of the extended GTFS codes.
gap_mode_labels <- function() {
  c(`3` = "Bus", `200` = "Coach", `0` = "Tram", `1` = "Metro", `2` = "Rail",
    `4` = "Ferry", `6` = "Aerial lift")
}

#' Runs per zone and route type in one comparison source result
#'
#' zone_bus_runs() reduced to bus; this keeps every mode. gtfs_trips_per_zone()
#' already emits one row per zone and route type, and comparison_source_result()
#' harmonises the extended BODS route types before counting, so the two sources'
#' modes are directly comparable without any further mapping here.
zone_runs_by_mode <- function(cmp_result) {
  tr <- as.data.frame(cmp_result$trips)
  tr <- tr[!is.na(tr$zone_id), ]
  runs_cols <- grep("^runs_", names(tr), value = TRUE)
  data.table::data.table(zone_id = as.character(tr$zone_id),
                         route_type = as.integer(tr$route_type),
                         runs = rowSums(tr[runs_cols], na.rm = TRUE))
}

#' Zone-level disagreement for every mode, not only bus
#'
#' The bus analysis is the bulk of this report because bus is what both sources
#' exist to carry, but neither source is bus-only and the non-bus modes
#' disagree in ways bus does not: a mode can be absent from one source by
#' design (heavy rail is not registered as a local bus service), present in
#' both but classified differently, or present in both and duplicated in one.
#' Separating those is the point of this table, and it costs nothing extra -
#' every number comes from the per-zone counts the comparison already produced.
#'
#' @param cmp_tnds,cmp_bods comparison_source_result() objects
#' @param top_n zones to keep per mode and direction
#' @return list(national, zones, top)
mode_gap_analysis <- function(cmp_tnds, cmp_bods, top_n = 10) {
  a <- zone_runs_by_mode(cmp_tnds)
  b <- zone_runs_by_mode(cmp_bods)
  data.table::setnames(a, "runs", "runs_tnds")
  data.table::setnames(b, "runs", "runs_bods")
  z <- merge(a, b, by = c("zone_id", "route_type"), all = TRUE)
  data.table::setnafill(z, fill = 0, cols = c("runs_tnds", "runs_bods"))
  z[, gap := runs_tnds - runs_bods]
  z[, country := substr(zone_id, 1, 1)]

  # National totals per mode. `zones_*` counts zones with any counted service
  # in that source, which is the measure that shows a mode missing from one
  # source outright rather than merely thinner.
  national <- z[, list(
    zones_either = data.table::uniqueN(zone_id[runs_tnds > 0 | runs_bods > 0]),
    zones_tnds = data.table::uniqueN(zone_id[runs_tnds > 0]),
    zones_bods = data.table::uniqueN(zone_id[runs_bods > 0]),
    zones_only_tnds = data.table::uniqueN(zone_id[runs_tnds > 0 & runs_bods == 0]),
    zones_only_bods = data.table::uniqueN(zone_id[runs_bods > 0 & runs_tnds == 0]),
    runs_tnds = sum(runs_tnds), runs_bods = sum(runs_bods),
    abs_gap = sum(abs(gap))), by = route_type]
  national[, ratio := ifelse(runs_bods > 0, runs_tnds / runs_bods, NA_real_)]
  lab <- gap_mode_labels()
  national[, mode := ifelse(as.character(route_type) %in% names(lab),
                            lab[as.character(route_type)],
                            paste("Type", route_type))]
  national[, ord := match(as.character(route_type), names(lab))]
  data.table::setorderv(national, "ord", na.last = TRUE)
  national[, ord := NULL]

  # Top zones per mode, both directions, for the non-bus modes only: the bus
  # ranking is the main report and is not repeated here.
  nb <- z[route_type != 3L & (runs_tnds > 0 | runs_bods > 0)]
  top <- data.table::rbindlist(lapply(split(nb, nb$route_type), function(d) {
    data.table::setorderv(d, "gap", -1L)
    unique(data.table::rbindlist(list(utils::head(d, top_n),
                                      utils::tail(d, top_n))))
  }))
  list(national = national[], zones = z[], top = top[])
}

#' Zones where a mode is TNDS-only and another is BODS-only by the same amount
#'
#' The commonest non-bus disagreement is not missing service but disputed
#' classification: both sources carry the same trains and label them
#' differently, so one mode goes to zero in one source and another goes to zero
#' in the other, in the same zone, by almost the same number of runs. Counting
#' either mode on its own makes it look as though a railway had appeared or
#' vanished.
#'
#' Detected rather than listed, because the pairs change with the feeds: a zone
#' qualifies when a mode present only in TNDS and a mode present only in BODS
#' GTFS agree on run count to within `tol`. The run totals matching to a few
#' percent is what distinguishes a relabelling from a coincidence - missing
#' service does not arrive in the same zone at the same volume under another
#' name.
#'
#' @param mz the per-zone, per-mode table from mode_gap_analysis()
#' @param tol largest relative difference in runs still called a match
#' @param min_runs ignore pairs smaller than this; a handful of runs matching
#'   is not evidence of anything
mode_swap_zones <- function(mz, tol = 0.1, min_runs = 100) {
  d <- data.table::as.data.table(mz)
  only_t <- d[runs_tnds >= min_runs & runs_bods == 0,
              list(zone_id, type_tnds = route_type, runs_t = runs_tnds)]
  only_b <- d[runs_bods >= min_runs & runs_tnds == 0,
              list(zone_id, type_bods = route_type, runs_b = runs_bods)]
  if (!nrow(only_t) || !nrow(only_b)) {
    return(data.table::data.table(zone_id = character(0)))
  }
  p <- merge(only_t, only_b, by = "zone_id", allow.cartesian = TRUE)
  p[, rel := abs(runs_t - runs_b) / pmax(runs_t, runs_b)]
  p <- p[rel <= tol]
  data.table::setorderv(p, "runs_t", -1L)
  p[]
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
#' @param gtfs a feed already harmonised and trimmed to the window by
#'   prepare_feed_window(); the route types are the simplified ones
#' @param zones zone polygons in 4326 with a `zone_id` column, already
#'   subset to the zones of interest
#' @param win study window
#' @param route_types which harmonised route types to count. Bus (3) for the
#'   main analysis; the non-bus modes are counted in the same pass over the
#'   same feed, which is why this is an argument rather than a constant.
#' @return list(by_route = zone x route runs, stops = stops in those zones,
#'   dup = duplicate runs per zone, daily = zone x date trip-days)
zone_route_runs <- function(gtfs, zones, win, route_types = 3L) {
  sz <- feed_stops_in_zones(gtfs, zones)
  runs <- trip_runs_in_window(gtfs)

  routes <- data.table::as.data.table(as.data.frame(gtfs$routes))
  routes <- routes[route_type %in% as.integer(route_types)]
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
  # Whole-itinerary signatures are built over every stop-time of the relevant
  # trips, not only the ones inside the zones: the whole point is that a zone
  # cannot judge journey identity from the part it can see.
  isig <- trip_itinerary_sig(st[trip_id %in% trips$trip_id])

  st <- st[stop_id %in% sz$stop_id]
  st <- merge(st, unique(sz[, list(stop_id, zone_id)]), by = "stop_id",
              allow.cartesian = TRUE)
  st <- st[trip_id %in% trips$trip_id]

  dz <- zone_duplicate_runs(st, trips, routes,
                            service_dates_in_window(gtfs, win), isig)

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
  list(by_route = by_route[], stops = sz[], dup = dz$zone, daily = dz$daily)
}

#' Harmonise a feed's route types and trim it to the counting window
#'
#' Both of these were done inside zone_route_runs(), which was fine while it
#' was called once per feed. It is now called twice - once for bus and once for
#' the non-bus modes - and trimming a national feed twice is minutes of work
#' for an identical result, so the preparation is hoisted out to the caller.
prepare_feed_window <- function(gtfs, win) {
  gtfs$routes$route_type <- map_route_type_simple(gtfs$routes$route_type)
  UK2GTFS::gtfs_trim_dates(gtfs, startdate = win$startdate,
                           enddate = win$enddate)
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

#' A journey's identity, as the whole list of (stop, departure time) pairs
#'
#' Shared by the zone-level and whole-feed duplicate tests so that both mean
#' the same thing by "the same journey". The pairs are numbered and the numbers
#' pasted rather than the text: identity is all that matters, and pasting a
#' bus station's ATCO codes and timestamps for tens of millions of rows is far
#' slower and much heavier.
#'
#' @param st stop-times for the trips of interest: trip_id, stop_id,
#'   departure_time, with no missing departure time
#' @return trip_id and an integer `sig_id`, equal for identical itineraries
trip_itinerary_sig <- function(st) {
  s <- st[, list(trip_id, stop_id, departure_time)]
  s[, pair := paste0(stop_id, "\r", departure_time)]
  s[, pid := match(pair, unique(pair))][, pair := NULL]
  data.table::setorder(s, trip_id, pid)
  sig <- s[, list(sig = paste(pid, collapse = ",")), by = trip_id]
  sig[, sig_id := match(sig, unique(sig))][, sig := NULL]
  sig[]
}

#' Runs in a zone that are the same journey twice on the same day
#'
#' A journey is identified by its **whole itinerary**, and two trips count
#' against a zone only if they are the same journey end to end, run on the same
#' date, carry the same route number, and both touch the zone.
#'
#' Earlier editions identified the journey by the (stop, departure time) pairs
#' it made at stops *inside the zone* alone, on the reasoning that a zone can
#' only see the part of a trip that touches it. That test is wrong, and
#' measurably so. Checked against the feed on route 74 in Birmingham city
#' centre (E01033620), it reported 2,500 duplicate trip-days that are not
#' duplicates at all: the pairs it flagged are two buses three minutes apart -
#' 14:06 and 14:09 from the same first stop, 29 identical stops, different
#' `service_id`s - whose times coincide at the handful of stops inside one
#' small city-centre LSOA once rounded to the minute. On a high-frequency urban
#' corridor that is ordinary service, and the loose test called a sixth of the
#' zone's BODS GTFS count a duplicate because of it. Any verdict resting on
#' that number would have blamed the wrong source.
#'
#' The route number is still required to match, because a whole-itinerary match
#' between different numbers is more likely to be two numbers for one road than
#' one journey published twice.
#'
#' @param zs stop-times at zone stops: trip_id, zone_id
#' @param trips trip_id, route_id, service_id
#' @param routes route_id, route_short_name
#' @param sdates service_dates_in_window() output
#' @param isig trip_itinerary_sig() over the whole feed
zone_duplicate_runs <- function(zs, trips, routes, sdates, isig) {
  tz <- unique(zs[, list(trip_id, zone_id)])
  tz <- merge(tz, trips, by = "trip_id")
  tz <- merge(tz, routes[, list(route_id, route_short_name)], by = "route_id",
              all.x = TRUE)
  tz <- merge(tz, isig, by = "trip_id")

  td <- merge(tz, sdates, by = "service_id", allow.cartesian = TRUE)
  cells <- td[, list(n = .N), by = list(zone_id, date, route_short_name, sig_id)]
  # Per date as well as per zone. The daily profile is what distinguishes a
  # source that is thin all month from one that stops partway through it, and
  # the cells are already grouped by date, so it costs one more aggregation.
  list(zone = cells[, list(trip_days = sum(n), dup_runs = sum(n - 1L)),
                    by = zone_id],
       daily = cells[, list(trip_days = sum(n), dup_runs = sum(n - 1L)),
                     by = list(zone_id, date)])
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
feed_duplicate_runs <- function(gtfs, win, route_types = 3L) {
  routes <- data.table::as.data.table(as.data.frame(gtfs$routes))
  routes <- routes[route_type %in% as.integer(route_types)]
  routes[, route_id := as.character(route_id)]
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
  sig <- trip_itinerary_sig(st)

  td <- merge(merge(trips, sig, by = "trip_id"),
              service_dates_in_window(gtfs, win), by = "service_id",
              allow.cartesian = TRUE)
  cells <- td[, list(n = .N), by = list(sig_id, date)]

  data.frame(
    # Named `trips` rather than `bus_trips`: this is now run per mode as well
    # as for bus, and a metro count in a column called bus_trips invites
    # exactly the misreading the non-bus section exists to prevent.
    trips = nrow(trips),
    distinct_journeys = data.table::uniqueN(sig$sig_id),
    trip_days = nrow(td),
    duplicate_runs = sum(cells$n - 1L),
    share_duplicate = if (nrow(td)) sum(cells$n - 1L) / nrow(td) else NA_real_,
    frequencies = if (is.null(gtfs$frequencies)) 0L else nrow(gtfs$frequencies),
    stringsAsFactors = FALSE)
}

#' Which source the evidence blames for a zone's disagreement
#'
#' The report's older editions listed the causes of disagreement in general
#' terms and left the reader to decide which source to believe. This decides
#' it per zone, where the evidence allows, from three measurements that point
#' at different mechanisms and cannot be confused with one another:
#'
#'  * **journeys against operating days.** A zone's run total is the number of
#'    journeys touching it multiplied by the days each one runs. If the two
#'    sources hold the same journeys but one runs them on a third of the days,
#'    the disagreement is in the calendars, not the timetable - a registration
#'    expiring inside the window. If they hold the same days per journey but
#'    one has half the journeys, service is missing from that source.
#'  * **duplicate runs remaining.** Measured by zone_duplicate_runs(). Where
#'    the *higher* source's residual duplication accounts for much of its
#'    excess, the excess is one bus described twice and that source is wrong.
#'  * **the daily profile.** A source that is uniformly thin differs from one
#'    that stops partway through the window; only the second is an expiry.
#'
#' Thresholds are deliberately wide and the fall-through is "unresolved"
#' rather than a guess: the point is to name the zones where the evidence is
#' decisive, not to label every zone.
#'
#' @param top the zone table, already carrying trips, duplication and daily
#'   columns for both sources
#' @return `top` with verdict and the ratios the verdict rests on
gap_verdict <- function(top) {
  d <- data.table::copy(top)
  safe <- function(a, b) ifelse(b > 0, a / b, NA_real_)
  # A zone with no service in one source has no daily profile on that side, so
  # these are absent rather than zero after the merge.
  for (cl in c("days_full_tnds", "days_full_bods_gtfs", "days_any_tnds",
               "days_any_bods_gtfs")) {
    if (!cl %in% names(d)) d[, (cl) := NA_integer_]
    d[is.na(get(cl)), (cl) := 0L]
  }

  d[, dpt_tnds := safe(runs_tnds, trips_tnds)]
  d[, dpt_bods := safe(runs_bods, trips_bods)]
  d[, trip_ratio := safe(trips_tnds, trips_bods)]
  d[, dpt_ratio := safe(dpt_tnds, dpt_bods)]
  d[, dup_share_tnds := safe(dup_runs_tnds, trip_days_tnds)]
  d[, dup_share_bods := safe(dup_runs_bods_gtfs, trip_days_bods_gtfs)]
  # How much of the gap the higher source's own residual duplication accounts
  # for. Only the higher source can explain a gap this way: duplication in the
  # lower source makes its shortfall larger, not smaller.
  d[, dup_explains := data.table::fcase(
    gap > 0, safe(dup_runs_tnds, abs(gap)),
    gap < 0, safe(dup_runs_bods_gtfs, abs(gap)),
    default = NA_real_)]

  short <- function(x) !is.na(x) & x <= 0.7
  over <- function(x) !is.na(x) & x >= 1.43

  # Which of the two factors carries the gap. An earlier version required the
  # *other* factor to sit within a tenth of parity, which mislabelled the
  # clearest cases: Gatwick/Crawley has 777 TNDS journeys against 4,387 and a
  # days-per-journey ratio of 1.22, so the journeys explain it overwhelmingly,
  # yet 1.22 fell outside the parity band and the zone came out "unresolved"
  # while the hand-check showed TNDS simply lacks the Metrobus town network.
  # Comparing the two factors on a log scale is scale-free and asks the right
  # question - which one moved more - rather than demanding the other be still.
  lr <- function(x) ifelse(is.na(x) | x <= 0, NA_real_, abs(log(x)))
  d[, l_trip := lr(trip_ratio)]
  d[, l_dpt := lr(dpt_ratio)]
  dom <- function(a, b) !is.na(a) & !is.na(b) & a >= 2.5 * b
  d[, trips_dominate := dom(l_trip, l_dpt)]
  d[, days_dominate := dom(l_dpt, l_trip)]

  # An expiry has to show in the calendar as well as in the arithmetic: the
  # source blamed must count a normal day's service on fewer of the window's
  # days than the other. Without this a source that simply runs everything
  # less often would be called truncated.
  d[, cut_tnds := days_full_tnds < days_full_bods_gtfs]
  d[, cut_bods := days_full_bods_gtfs < days_full_tnds]

  d[, verdict := data.table::fcase(
    runs_tnds == 0, "absent from TNDS",
    runs_bods == 0, "absent from BODS GTFS",
    !is.na(dup_explains) & dup_explains >= 0.5 & gap < 0,
      "BODS GTFS counts one bus twice",
    !is.na(dup_explains) & dup_explains >= 0.5 & gap > 0,
      "TNDS counts one bus twice",
    days_dominate & short(dpt_ratio) & cut_tnds, "TNDS calendars cut short",
    days_dominate & over(dpt_ratio) & cut_bods,
      "BODS GTFS calendars cut short",
    trips_dominate & short(trip_ratio), "journeys missing from TNDS",
    trips_dominate & over(trip_ratio), "journeys missing from BODS GTFS",
    default = "unresolved")]

  # Which source the verdict faults, for counting up at the end. "unresolved"
  # and the two "absent" verdicts deliberately blame neither: an absence can
  # be correct (a Welsh service has no duty to appear in BODS at all).
  d[, blames := data.table::fcase(
    verdict %in% c("TNDS counts one bus twice", "TNDS calendars cut short",
                   "journeys missing from TNDS"), "TNDS",
    verdict %in% c("BODS GTFS counts one bus twice",
                   "BODS GTFS calendars cut short",
                   "journeys missing from BODS GTFS"), "BODS GTFS",
    default = "neither")]
  d[]
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

  # --- every mode, from the counts the comparison already produced ---------
  # No feed reading: comparison_source_result() counts all modes and only the
  # reporting was ever bus-only.
  modes <- mode_gap_analysis(cmp_tnds, cmp_bods)
  nonbus_types <- sort(setdiff(unique(modes$zones$route_type), 3L))

  # --- per-route attribution in those zones --------------------------------
  zones_all <- readRDS(zones_path)
  names(zones_all)[1] <- "zone_id"
  zones_all <- sf::st_transform(zones_all, 4326)
  zones <- zones_all[zones_all$zone_id %in% top$zone_id, ]
  # The non-bus modes rank different zones entirely - a tram zone is not a bus
  # interchange - so they get their own subset rather than reusing the bus one.
  zones_nb <- zones_all[zones_all$zone_id %in% unique(modes$top$zone_id), ]
  rm(zones_all)

  per_source <- list()
  stops_all <- list()
  dup_all <- list()
  daily_all <- list()
  dup_nat <- list()
  nb_route <- list()
  nb_stops <- list()
  for (src in c("tnds", "bods_gtfs")) {
    message("lsoa_gap: reading ", src, " (", spec[[src]], ")")
    gtfs <- read_feed(spec[[src]], cfg)
    gtfs <- prepare_feed_window(gtfs, win)

    rr <- zone_route_runs(gtfs, zones, win, route_types = 3L)
    per_source[[src]] <- rr$by_route
    stops_all[[src]] <- rr$stops
    dup_all[[src]] <- rr$dup
    daily_all[[src]] <- rr$daily

    message("lsoa_gap: non-bus modes, ", src)
    nb <- zone_route_runs(gtfs, zones_nb, win, route_types = nonbus_types)
    # Carry the mode down with the routes: a zone can hold two non-bus modes
    # and the report splits them.
    rtmap <- data.table::as.data.table(as.data.frame(gtfs$routes))[
      , list(route_id = as.character(route_id),
             route_type = as.integer(route_type))]
    nb_route[[src]] <- merge(nb$by_route, rtmap, by = "route_id", all.x = TRUE)
    nb_stops[[src]] <- nb$stops

    message("lsoa_gap: whole-feed duplicate check, ", src)
    dn <- lapply(c(list(3L), as.list(nonbus_types)), function(rt) {
      out <- feed_duplicate_runs(gtfs, win, route_types = rt)
      out$route_type <- rt
      out
    })
    dup_nat[[src]] <- data.table::rbindlist(dn)
    rm(gtfs, rr, nb); gc()
  }
  dup <- data.table::rbindlist(dup_all, idcol = "source")
  dup <- data.table::dcast(dup, zone_id ~ source,
                           value.var = c("trip_days", "dup_runs"), fill = 0)
  dup_national <- data.table::rbindlist(dup_nat, idcol = "source")
  daily <- data.table::rbindlist(daily_all, idcol = "source")
  nonbus_routes <- data.table::rbindlist(nb_route, idcol = "source", fill = TRUE)

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

  # Keep the per-source, per-route detail. Without it, any question about *why*
  # a service differs - whether one source splits it across several route_ids,
  # whether the trips or the runs-per-trip differ - needs both national feeds
  # read again, which is an hour of work to answer a five-minute question.
  by_route <- data.table::rbindlist(per_source, idcol = "source", fill = TRUE)

  # --- the evidence the verdict rests on -----------------------------------
  # Journeys per zone per source, so the gap can be split into "how many
  # journeys" against "how many days each journey runs".
  trip_counts <- data.table::dcast(
    by_route[, list(trips = sum(trips)), by = list(zone_id, source)],
    zone_id ~ source, value.var = "trips", fill = 0)
  data.table::setnames(trip_counts,
                       old = intersect(c("tnds", "bods_gtfs"),
                                       names(trip_counts)),
                       new = paste0("trips_", intersect(
                         c("tnds", "bods_gtfs"), names(trip_counts))))
  if (!"trips_tnds" %in% names(trip_counts)) trip_counts[, trips_tnds := 0]
  if (!"trips_bods_gtfs" %in% names(trip_counts)) {
    trip_counts[, trips_bods_gtfs := 0]
  }
  data.table::setnames(trip_counts, "trips_bods_gtfs", "trips_bods")
  top <- merge(top, trip_counts, by = "zone_id", all.x = TRUE)
  data.table::setnafill(top, fill = 0, cols = c("trips_tnds", "trips_bods"))

  # Daily profile, reduced to the two numbers the verdict uses: how many of
  # the window's days the source counts anything at all, and how many it
  # counts a normal day's worth on. "Normal" is half the source's own busiest
  # day, so a thin-but-steady source is not mistaken for a truncated one.
  prof <- daily[, list(days_any = data.table::uniqueN(date),
                       days_full = data.table::uniqueN(
                         date[trip_days >= 0.5 * max(trip_days)]),
                       last_day = max(date)),
                by = list(zone_id, source)]
  prof <- data.table::dcast(prof, zone_id ~ source,
                            value.var = c("days_any", "days_full", "last_day"))
  top <- merge(top, prof, by = "zone_id", all.x = TRUE)

  # gap_verdict() is deliberately NOT applied here. This target measures; the
  # report interprets, and calls gap_verdict() itself on these columns. The
  # thresholds in it are judgement and will be revised, and keeping the call
  # out of this function means revising them costs a seven-second re-knit
  # instead of the two hours it takes to read both national feeds again.
  data.table::setorderv(top, "gap", -1L)

  # --- non-bus services in the zones where the non-bus modes disagree ------
  nb_loc <- zone_locality(data.table::rbindlist(nb_stops, fill = TRUE))
  nb_svc <- nonbus_routes[, list(runs = sum(runs), trips = sum(trips)),
                          by = list(zone_id, route_type, source,
                                    name = route_short_name,
                                    long_name = route_long_name)]
  nb_wide <- data.table::dcast(
    nb_svc, zone_id + route_type + name + long_name ~ source,
    value.var = c("runs", "trips"), fill = 0)
  for (cl in c("runs_tnds", "runs_bods_gtfs", "trips_tnds",
               "trips_bods_gtfs")) {
    if (!cl %in% names(nb_wide)) nb_wide[, (cl) := 0]
  }
  nb_wide[, gap := runs_tnds - runs_bods_gtfs]
  nb_wide[, cause := data.table::fcase(
    runs_bods_gtfs == 0, "only in TNDS",
    runs_tnds == 0, "only in BODS GTFS",
    default = "both, different frequency")]
  data.table::setorderv(nb_wide, "gap", -1L)
  modes$top <- merge(modes$top, nb_loc, by = "zone_id", all.x = TRUE)
  modes$services <- nb_wide[]

  out <- list(year = year, window = win, snapshot = spec,
              zones = z[], top = top[], services = wide[], duplication = dup[],
              duplication_national = dup_national[], by_route = by_route[],
              daily = daily[], modes = modes,
              # Already computed by comparison_source_result(). Carried through
              # because it is the national frame for the per-zone verdicts: a
              # zone found to hold the same journeys on fewer days is one
              # instance of whatever share of the feed expires inside the
              # window, and the reader should be able to see both numbers.
              expiry = data.table::rbindlist(
                list(tnds = as.data.frame(cmp_tnds$expiry),
                     bods_gtfs = as.data.frame(cmp_bods$expiry)),
                idcol = "source", fill = TRUE),
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
