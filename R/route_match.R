# Matching bus routes across the three timetable sources.
#
# The zone-level comparison (R/comparison.R) says how much the sources
# disagree; this file says WHAT they disagree about. It matches individual
# bus routes between TNDS, BODS TransXChange and BODS GTFS so that the
# national difference can be split into
#
#   (a) services one source carries and another does not at all, and
#   (b) services all sources carry, but at different frequencies.
#
# Routes cannot be matched on identifiers: route_id is source-specific and
# the BODS GTFS agency_id is a synthetic "OP77" code, not a NOC. Instead a
# route is identified by its public route number plus the set of stops it
# serves, which is stable across the three conversion routes.

#' Normalised public route number, used as the matching key
#'
#' Falls back to route_long_name where a feed leaves route_short_name blank.
#' Routes with no usable name get a unique key so they can never match.
route_short_key <- function(routes) {
  s <- as.character(routes$route_short_name)
  ln <- as.character(routes$route_long_name)
  blank <- is.na(s) | trimws(s) == ""
  s[blank] <- ln[blank]
  key <- toupper(gsub("[^A-Za-z0-9]", "", ifelse(is.na(s), "", s)))
  unusable <- key == ""
  key[unusable] <- paste0("~", as.character(routes$route_id)[unusable])
  key
}

#' Vehicle journeys operated by each trip within the study window
#'
#' Reproduces the run-counting semantics of UK2GTFS::gtfs_trips_per_zone():
#' weekday counts from calendar.txt, then calendar_dates exceptions applied
#' with GTFS semantics (a cancellation only removes a day the calendar
#' operates; an extra only adds a day it does not). `gtfs` must already be
#' trimmed to the window, so calendar dates are clipped to it.
#'
#' Unlike the zone counts, this is a count of vehicle journeys, not of stop
#' departures: a journey is counted once however many stops or zones it
#' serves.
trip_runs_in_window <- function(gtfs) {
  dow <- c("monday", "tuesday", "wednesday", "thursday", "friday",
           "saturday", "sunday")

  cal <- as.data.frame(gtfs$calendar)
  if (nrow(cal) == 0) {
    return(data.table::data.table(trip_id = character(0), runs = numeric(0)))
  }
  cal$start_date <- as.Date(cal$start_date)
  cal$end_date <- as.Date(cal$end_date)

  # Occurrences of each weekday in [start_date, end_date]: step forward from
  # start_date to the first matching weekday, then count whole weeks.
  start_dow <- as.integer(lubridate::wday(cal$start_date, week_start = 1))
  span <- as.integer(cal$end_date - cal$start_date)
  n_dow <- vapply(seq_along(dow), function(i) {
    offset <- (i - start_dow) %% 7L
    as.numeric(pmax((span - offset) %/% 7L + 1L, 0L))
  }, numeric(nrow(cal)))
  n_dow[is.na(n_dow)] <- 0
  n_dow <- matrix(n_dow, nrow = nrow(cal))

  runs <- as.matrix(cal[, dow]) * n_dow
  colnames(runs) <- dow

  # calendar_dates exceptions, counted per weekday so the GTFS semantics can
  # be applied against the matching calendar.txt day flag
  cd <- as.data.frame(gtfs$calendar_dates)
  if (!is.null(cd) && nrow(cd) > 0) {
    cd$date <- as.Date(cd$date)
    # A date can only be added or cancelled once per service
    cd <- cd[!duplicated(paste(cd$service_id, cd$date, cd$exception_type)), ]
    cd$dow <- as.integer(lubridate::wday(cd$date, week_start = 1))
    cd <- data.table::as.data.table(cd)
    exc <- cd[, list(extra = sum(exception_type == 1),
                     canceled = sum(exception_type == 2)),
              by = list(service_id, dow)]
    idx <- match(exc$service_id, cal$service_id)
    keep <- !is.na(idx)
    exc <- exc[keep]; idx <- idx[keep]
    cell <- cbind(idx, exc$dow)
    operates <- runs[cell] > 0
    runs[cell] <- ifelse(operates,
                         pmax(runs[cell] - exc$canceled, 0),
                         exc$extra)
  }

  svc <- data.table::data.table(service_id = cal$service_id,
                                runs = rowSums(runs))
  trips <- data.table::as.data.table(
    as.data.frame(gtfs$trips)[, c("trip_id", "service_id")])
  out <- merge(trips, svc, by = "service_id", all.x = TRUE)
  out[is.na(runs), runs := 0]

  # Frequency-based services represent several departures per trip per day
  if (!is.null(gtfs$frequencies) && nrow(gtfs$frequencies) > 0) {
    fq <- data.table::as.data.table(as.data.frame(gtfs$frequencies))
    fq[, n_dep := pmax(ceiling(
      (gtfs_secs(end_time) - gtfs_secs(start_time)) / as.numeric(headway_secs)), 1)]
    fq <- fq[, list(freq_runs = sum(n_dep)), by = trip_id]
    out <- merge(out, fq, by = "trip_id", all.x = TRUE)
    out[is.na(freq_runs), freq_runs := 1]
    out[, runs := runs * freq_runs][, freq_runs := NULL]
  }
  out[, list(trip_id = as.character(trip_id), runs)]
}

#' GTFS time column to seconds since midnight (Period, ITime or character)
gtfs_secs <- function(x) {
  if (inherits(x, "Period")) return(lubridate::period_to_seconds(x))
  if (inherits(x, "difftime")) return(as.numeric(x, units = "secs"))
  if (inherits(x, "ITime")) return(as.numeric(unclass(x)))
  if (is.character(x)) {
    return(vapply(strsplit(x, ":", fixed = TRUE), function(p) {
      sum(as.numeric(p) * c(3600, 60, 1)[seq_along(p)])
    }, numeric(1)))
  }
  as.numeric(x)
}

#' Per-route summary of one feed over the study window
#'
#' Returns the bus routes of a feed with the vehicle journeys each operates
#' in the window, the stops it serves (for matching) and its terminal stop
#' names (for reporting readable examples).
#'
#' @param gtfs a feed with route_type already harmonised
#' @param win study window (list of startdate/enddate)
#' @param keep_type which harmonised route type to summarise (3 = bus)
route_window_summary <- function(gtfs, win, keep_type = 3L) {
  gtfs <- UK2GTFS::gtfs_trim_dates(gtfs, startdate = win$startdate,
                                   enddate = win$enddate)
  runs <- trip_runs_in_window(gtfs)

  routes <- data.table::as.data.table(as.data.frame(gtfs$routes))
  routes[, route_id := as.character(route_id)]
  routes <- routes[route_type == keep_type]
  if (nrow(routes) == 0) {
    return(list(routes = data.table::data.table(), stops = data.table::data.table()))
  }

  trips <- data.table::as.data.table(as.data.frame(gtfs$trips))
  trips <- trips[, list(trip_id = as.character(trip_id),
                        route_id = as.character(route_id))]
  trips <- trips[route_id %in% routes$route_id]
  trips <- merge(trips, runs, by = "trip_id", all.x = TRUE)
  trips[is.na(runs), runs := 0]

  st <- data.table::as.data.table(as.data.frame(gtfs$stop_times))
  st <- st[, list(trip_id = as.character(trip_id),
                  stop_id = as.character(stop_id),
                  stop_sequence = as.integer(stop_sequence))]
  st <- st[trip_id %in% trips$trip_id]
  st <- merge(st, trips[, list(trip_id, route_id)], by = "trip_id")

  route_stops <- unique(st[, list(route_id, stop_id)])

  # Terminals: the most common first and last stop across the route's trips,
  # which name the route far more usefully than route_long_name does
  data.table::setorder(st, trip_id, stop_sequence)
  ends <- st[, list(first_stop = stop_id[1], last_stop = stop_id[.N]),
             by = list(route_id, trip_id)]
  modal <- function(x) names(sort(table(x), decreasing = TRUE))[1]
  ends <- ends[, list(first_stop = modal(first_stop),
                      last_stop = modal(last_stop)), by = route_id]

  stops <- data.table::as.data.table(as.data.frame(gtfs$stops))
  stops <- stops[, list(stop_id = as.character(stop_id),
                        stop_name = as.character(stop_name))]
  stops <- unique(stops, by = "stop_id")
  ends <- merge(ends, stops[, list(first_stop = stop_id, from = stop_name)],
                by = "first_stop", all.x = TRUE)
  ends <- merge(ends, stops[, list(last_stop = stop_id, to = stop_name)],
                by = "last_stop", all.x = TRUE)

  agency <- data.table::as.data.table(as.data.frame(gtfs$agency))
  if ("agency_id" %in% names(routes) && "agency_id" %in% names(agency)) {
    routes[, agency_id := as.character(agency_id)]
    routes <- merge(routes,
                    unique(agency[, list(agency_id = as.character(agency_id),
                                         agency_name = as.character(agency_name))],
                           by = "agency_id"),
                    by = "agency_id", all.x = TRUE)
  } else {
    routes[, agency_name := NA_character_]
  }

  route_runs <- trips[, list(runs = sum(runs), trips = .N), by = route_id]
  out <- merge(routes[, list(route_id, route_short_name, route_long_name,
                             agency_name)],
               route_runs, by = "route_id", all.x = TRUE)
  out <- merge(out, ends[, list(route_id, from, to)], by = "route_id",
               all.x = TRUE)
  out[is.na(runs), runs := 0]
  out[, short_key := route_short_key(out)]

  list(routes = out[], stops = route_stops[])
}

#' Group routes from several sources into cross-source services
#'
#' Two routes are linked when they share a normalised route number and their
#' stop sets overlap by at least `min_overlap` (overlap coefficient, i.e.
#' shared stops over the smaller stop set). Connected components of that
#' graph become "services". Linking is done within sources as well as
#' between them, so a service a source splits across several route_ids is
#' still compared as one service.
#'
#' @param summaries named list of route_window_summary() results
#' @param min_overlap minimum stop-set overlap coefficient to link two routes
#' @return list(services = per-service runs by source, members = route to
#'   service lookup)
match_route_services <- function(summaries, min_overlap = 0.5) {
  srcs <- names(summaries)

  meta <- data.table::rbindlist(lapply(srcs, function(s) {
    r <- data.table::copy(summaries[[s]]$routes)
    if (nrow(r) == 0) return(NULL)
    r[, source := s][, node := paste(s, route_id, sep = "::")][]
  }), fill = TRUE)

  rs <- data.table::rbindlist(lapply(srcs, function(s) {
    st <- summaries[[s]]$stops
    if (nrow(st) == 0) return(NULL)
    st <- data.table::copy(st)
    st[, node := paste(s, route_id, sep = "::")][, route_id := NULL][]
  }), fill = TRUE)
  rs <- merge(rs, meta[, list(node, short_key)], by = "node")

  sizes <- rs[, list(n_stops = .N), by = node]

  # Candidate pairs: routes sharing a route number AND at least one stop.
  # Keying on both keeps this self-join small.
  data.table::setkey(rs, short_key, stop_id)
  pairs <- rs[rs, on = list(short_key, stop_id), allow.cartesian = TRUE,
              nomatch = 0L]
  pairs <- pairs[node < i.node, list(shared = .N), by = list(node, i.node)]

  if (nrow(pairs) > 0) {
    pairs <- merge(pairs, sizes, by = "node")
    data.table::setnames(pairs, "n_stops", "n_a")
    pairs <- merge(pairs, sizes, by.x = "i.node", by.y = "node")
    data.table::setnames(pairs, "n_stops", "n_b")
    pairs[, overlap := shared / pmin(n_a, n_b)]
    edges <- pairs[overlap >= min_overlap, list(node, i.node)]
  } else {
    edges <- data.table::data.table(node = character(0), i.node = character(0))
  }

  g <- igraph::graph_from_data_frame(edges, directed = FALSE,
                                     vertices = data.frame(name = meta$node))
  comp <- igraph::components(g)
  meta[, service := as.integer(comp$membership[node])]

  # One row per service and source
  by_src <- meta[, list(runs = sum(runs), routes = .N),
                 by = list(service, source)]
  services <- data.table::dcast(by_src, service ~ source,
                                value.var = "runs", fill = 0)
  for (s in srcs) if (!s %in% names(services)) services[, (s) := 0]

  # Label each service with its route number and a representative pair of
  # terminals, taken from whichever source runs it most
  label <- meta[order(-runs), list(short_key = short_key[1],
                                   route_short_name = route_short_name[1],
                                   agency_name = agency_name[1],
                                   from = from[1], to = to[1]),
                by = service]
  services <- merge(label, services, by = "service")

  list(services = services[], members = meta[, list(node, source, route_id,
                                                    service, runs)])
}

#' Split the difference between two sources into missing services and
#' frequency differences
#'
#' @param services the services table from match_route_services()
#' @param a,b source column names
#' @return one-row data frame decomposing total runs in a minus total in b
decompose_difference <- function(services, a, b) {
  x <- services[[a]]
  y <- services[[b]]
  only_a <- x > 0 & y == 0
  only_b <- y > 0 & x == 0
  both <- x > 0 & y > 0
  data.frame(
    comparison = paste(a, "vs", b),
    services_both = sum(both),
    services_only_a = sum(only_a),
    services_only_b = sum(only_b),
    runs_a = sum(x),
    runs_b = sum(y),
    runs_only_a = sum(x[only_a]),
    runs_only_b = sum(y[only_b]),
    runs_shared_a = sum(x[both]),
    runs_shared_b = sum(y[both]),
    # Of the total gap, how much is services the other source lacks entirely
    # and how much is a different frequency on services both carry
    gap_total = sum(x) - sum(y),
    gap_from_missing = sum(x[only_a]) - sum(y[only_b]),
    gap_from_frequency = sum(x[both]) - sum(y[both]),
    stringsAsFactors = FALSE
  )
}
