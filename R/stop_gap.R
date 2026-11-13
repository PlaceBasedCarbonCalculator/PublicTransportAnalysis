# Where do TNDS and the DfT's BODS GTFS disagree, stop by stop?
#
# The LSOA report (R/lsoa_gap.R) takes the national difference down to the
# zone. A zone still hides a lot: a bus station's thirty stands, both sides of
# a road, a stop code one source has replaced. This takes it down to the
# NaPTAN stop, which is the finest unit the two sources share.
#
# Counting is UK2GTFS::gtfs_stop_frequency(), as asked, on the same
# deduplicated feeds and the same July 2026 validation window as the LSOA
# report, and then a second time on a single day at the start of that window.
# The point of the pair is to separate two explanations the window total
# cannot tell apart:
#
#  * a timetable that stops early - a TNDS registration expiring inside the
#    window, a BODS calendar cut short - which shows up in the window but not
#    on a day both sources still cover; and
#  * genuinely different timetables, which show up on any day.
#
# gtfs_stop_frequency() counts a departure for every stop-time, so a trip that
# calls at a stop twice (a loop) counts twice there. It counts every stop-time
# regardless of timing status: UK2GTFS interpolates the times of non-timing
# points, so every stop of every trip has a departure. Both are what "how many
# buses call here" means, and they are why stop totals do not sum to zone
# totals, which count each trip once per zone.
#
# Bus only (harmonised route type 3), like the LSOA report's main figures.
#
# The cases at the end need more than counts: which routes make up the
# difference, whether the two sources describe the same journeys, and on which
# dates they part company. Route and trip identifiers are source-specific, so
# routes are matched on what the sources do share - the ordered sequence of
# stops - and journeys on their departure time at a common stop, with a
# tolerance because UK2GTFS interpolates times that one source may publish
# and the other may not.

#' The single day counted alongside the window
#'
#' Tuesday 28 July 2026, the second day of the validation window
#' (study_window(validation_snapshot()$ref) is 27 July - 9 August). Early, so
#' that nothing a source carries has yet expired: the TNDS registrations that
#' run out inside the window (window_expiry_stats()) are all still live on it.
#' A Tuesday rather than the Monday, so that it is an ordinary weekday in all
#' three nations and not the first day of anything a source might model
#' specially. Not 3 August, the Scottish summer bank holiday.
#'
#' Must lie inside the window: the per-date cross-check and the case charts
#' are built from the window's service dates.
stop_gap_day <- function() as.Date("2026-07-28")

#' Source of the UK2GTFS code the stop counts depend on
#'
#' targets hashes the functions in this repo, not the installed package, so a
#' fix to gtfs_stop_frequency() would otherwise leave every stop count stale
#' with nothing reported outdated. The target that calls this depends on the
#' installed package's code file, so it re-runs after any reinstall, and what
#' depends on it rebuilds only when this text actually changes.
#'
#' @param code_file the installed UK2GTFS code database; unused except as the
#'   dependency that makes a reinstall re-run this
stop_frequency_impl <- function(code_file = NULL) {
  fns <- c("gtfs_stop_frequency", "trip_runs_between",
           "frequency_runs_per_trip", "gtfs_deduplicate", "gtfs_clean",
           "gtfs_read")
  ns <- asNamespace("UK2GTFS")
  txt <- vapply(fns, function(f) {
    if (!exists(f, envir = ns, inherits = FALSE)) return(paste(f, "absent"))
    paste(deparse(get(f, envir = ns)), collapse = "\n")
  }, character(1))
  paste(c(as.character(utils::packageVersion("UK2GTFS")), txt),
        collapse = "\n")
}

#' Count bus departures per stop in one source, over the window and the day
#'
#' Reads the feed once and returns both counts plus a compact copy of its bus
#' timetable inside the window, so the analysis that follows never reads a
#' national feed again. That copy is integer-coded (trip and stop codes are
#' replaced by their position in a lookup) because it is tens of millions of
#' stop-times.
#'
#' @param src "tnds" or "bods_gtfs"
#' @param spec snapshot triple (validation_snapshot())
#' @param impl stop_frequency_impl(), carried only so targets rebuilds this
#'   when the package code changes
#' @param ... file dependencies (the converted TNDS feed), unused
#' @return path to data/stop_gap/stopfreq_<src>.Rds
stop_frequency_source <- function(src, spec = validation_snapshot(),
                                  day = stop_gap_day(), impl = NULL, ...,
                                  cfg = load_cfg()) {
  win <- study_window(spec$ref)
  stopifnot(day >= win$startdate, day <= win$enddate)
  message("stop_gap: reading ", src, " (", spec[[src]], ")")
  gtfs <- read_feed(spec[[src]], cfg)
  gtfs$routes$route_type <- map_route_type_simple(gtfs$routes$route_type)

  # Bus only. Only trips is cut down: gtfs_stop_frequency() keeps the
  # stop-times of the trips it is given, and subsetting stop_times rows here
  # would risk the Period corruption a data.table row subset causes.
  bus_routes <- as.character(gtfs$routes$route_id[gtfs$routes$route_type == 3L])
  gtfs$trips <- gtfs$trips[as.character(gtfs$trips$route_id) %in% bus_routes, ]

  message("stop_gap: gtfs_stop_frequency over the window")
  fw <- UK2GTFS::gtfs_stop_frequency(gtfs, win$startdate, win$enddate)
  message("stop_gap: gtfs_stop_frequency on ", day)
  fd <- UK2GTFS::gtfs_stop_frequency(gtfs, day, day)

  fw <- data.table::as.data.table(as.data.frame(fw))
  fd <- data.table::as.data.table(as.data.frame(fd))
  stops <- fw[, list(stop_id = as.character(stop_id),
                     stop_name = as.character(stop_name),
                     stop_lon = as.numeric(stop_lon),
                     stop_lat = as.numeric(stop_lat),
                     n_win = stops_total)]
  stops <- merge(stops, fd[, list(stop_id = as.character(stop_id),
                                  n_day = stops_total)],
                 by = "stop_id", all.x = TRUE)
  stops[is.na(n_win), n_win := 0]
  stops[is.na(n_day), n_day := 0]
  stops <- unique(stops, by = "stop_id")

  message("stop_gap: compact timetable")
  tt <- compact_timetable(gtfs, win)

  dir <- file.path(cfg$out_dir, "stop_gap")
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  out <- file.path(dir, sprintf("stopfreq_%s.Rds", src))
  saveRDS(list(source = src, feed = spec[[src]], window = win, day = day,
               stops = stops[], tt = tt), out)
  out
}

#' A feed's bus timetable inside the window, reduced to what the cases need
#'
#' @param gtfs a feed whose trips are already bus only
#' @return list of stop and trip lookups, trips, routes, integer stop-times,
#'   service dates in the window and frequency-based departures
compact_timetable <- function(gtfs, win) {
  sdates <- service_dates_in_window(gtfs, win)

  trips <- data.table::data.table(
    trip_id = as.character(gtfs$trips$trip_id),
    route_id = as.character(gtfs$trips$route_id),
    service_id = as.character(gtfs$trips$service_id),
    direction_id = if ("direction_id" %in% names(gtfs$trips))
      as.integer(gtfs$trips$direction_id) else NA_integer_)
  trips <- trips[service_id %in% sdates$service_id]
  trips[, trip := seq_len(.N)]

  # Columns are taken out of stop_times as whole vectors before anything is
  # subset: a row subset of the table itself can corrupt its Period columns.
  st <- data.table::data.table(
    trip_id = as.character(gtfs$stop_times$trip_id),
    stop_id = as.character(gtfs$stop_times$stop_id),
    seq = as.integer(gtfs$stop_times$stop_sequence),
    dep = as.integer(gtfs_secs(gtfs$stop_times$departure_time)))
  st <- st[trip_id %in% trips$trip_id]
  stop_ids <- sort(unique(st$stop_id))
  st[, stop := match(stop_id, stop_ids)][, stop_id := NULL]
  st[, trip := trips$trip[match(trip_id, trips$trip_id)]][, trip_id := NULL]
  data.table::setcolorder(st, c("trip", "stop", "seq", "dep"))
  data.table::setorder(st, trip, seq)

  routes <- data.table::as.data.table(as.data.frame(gtfs$routes))
  routes <- routes[as.character(route_id) %in% trips$route_id]
  agency <- data.table::as.data.table(as.data.frame(gtfs$agency))
  routes <- data.table::data.table(
    route_id = as.character(routes$route_id),
    route_short_name = as.character(routes$route_short_name),
    route_long_name = if ("route_long_name" %in% names(routes))
      as.character(routes$route_long_name) else NA_character_,
    agency_id = if ("agency_id" %in% names(routes))
      as.character(routes$agency_id) else NA_character_)
  if (all(c("agency_id", "agency_name") %in% names(agency))) {
    ag <- unique(data.table::data.table(
      agency_id = as.character(agency$agency_id),
      agency_name = as.character(agency$agency_name)), by = "agency_id")
    routes <- merge(routes, ag, by = "agency_id", all.x = TRUE)
  } else {
    routes[, agency_name := NA_character_]
  }

  freq <- NULL
  if (!is.null(gtfs$frequencies) && nrow(gtfs$frequencies) > 0) {
    fq <- data.table::data.table(
      trip_id = as.character(gtfs$frequencies$trip_id),
      start = gtfs_secs(gtfs$frequencies$start_time),
      end = gtfs_secs(gtfs$frequencies$end_time),
      headway = as.numeric(gtfs$frequencies$headway_secs))
    fq <- fq[trip_id %in% trips$trip_id]
    if (nrow(fq) > 0) {
      fq[, trip := trips$trip[match(trip_id, trips$trip_id)]]
      freq <- fq[, list(trip, start, end, headway)]
    }
  }

  stops <- data.table::as.data.table(as.data.frame(gtfs$stops))
  stops <- unique(stops[, list(stop_id = as.character(stop_id),
                               stop_name = as.character(stop_name),
                               stop_lon = as.numeric(stop_lon),
                               stop_lat = as.numeric(stop_lat))],
                  by = "stop_id")
  stops <- stops[match(stop_ids, stop_id)]
  stops[, stop_id := stop_ids]

  list(stops = stops[], trips = trips[], routes = routes[], st = st[],
       sdates = sdates[], freq = freq)
}

#' Departures per stop and date, from a compact timetable
#'
#' The per-date breakdown of what gtfs_stop_frequency() counts in total, by
#' the same GTFS service-day rules (service_dates_in_window()), so summing it
#' over the window must reproduce the window count. The analysis checks that it
#' does, which is the test that the two were counted alike.
#'
#' Frequency-based trips count once per implied departure, as in
#' gtfs_stop_frequency().
stop_date_departures <- function(tt, stops = NULL) {
  st <- tt$st
  if (!is.null(stops)) st <- st[stop %in% stops]
  mult <- trip_departure_multiplier(tt)
  ss <- st[, list(n = .N), by = list(stop, trip)]
  ss <- merge(ss, tt$trips[, list(trip, service_id)], by = "trip")
  ss <- merge(ss, mult, by = "trip", all.x = TRUE)
  ss[is.na(mult), mult := 1]
  ss <- ss[, list(n = sum(n * mult)), by = list(stop, service_id)]
  out <- merge(ss, tt$sdates, by = "service_id", allow.cartesian = TRUE)
  out[, list(n = sum(n)), by = list(stop, date)]
}

trip_departure_multiplier <- function(tt) {
  if (is.null(tt$freq) || nrow(tt$freq) == 0) {
    return(data.table::data.table(trip = integer(0), mult = numeric(0)))
  }
  f <- data.table::copy(tt$freq)
  f[, n_dep := pmax(ceiling((end - start) / headway), 1)]
  f[, list(mult = sum(n_dep)), by = trip]
}

#' Departure times of every journey at a set of stops, frequency trips expanded
trip_stop_times <- function(tt, stops) {
  st <- tt$st[stop %in% stops]
  if (!is.null(tt$freq) && nrow(tt$freq) > 0 && any(st$trip %in% tt$freq$trip)) {
    first <- tt$st[trip %in% tt$freq$trip, list(first = min(dep, na.rm = TRUE)),
                   by = trip]
    f <- merge(tt$freq, first, by = "trip")
    f[, n_dep := pmax(ceiling((end - start) / headway), 1)]
    ex <- f[, list(k = seq_len(n_dep) - 1L), by = list(trip, start, headway, first)]
    ex[, shift := start + k * headway - first]
    fs <- merge(st[trip %in% f$trip], ex[, list(trip, k, shift)], by = "trip",
                allow.cartesian = TRUE)
    fs[, dep := as.integer(dep + shift)]
    st <- data.table::rbindlist(list(
      st[!trip %in% f$trip][, k := 0L],
      fs[, list(trip, stop, seq, dep, k)]), use.names = TRUE)
  } else {
    st[, k := 0L]
  }
  st[]
}

#' Classify one period's comparison
stop_gap_type <- function(a, b) {
  data.table::fcase(a == 0 & b == 0, "neither",
                    b == 0, "TNDS only",
                    a == 0, "BODS only",
                    a > b, "TNDS higher",
                    b > a, "BODS higher",
                    default = "equal")
}

stop_gap_types <- function() c("TNDS only", "BODS only", "TNDS higher",
                               "BODS higher")

#' Stop-level TNDS vs BODS GTFS disagreement, and the routes behind the worst
#'
#' @param freq_tnds,freq_bods paths from stop_frequency_source()
#' @param zones_path plain LSOA/DZ polygons, to place each stop in the zone the
#'   LSOA report uses
#' @param top_n cases per error type and period
#' @param list_n stops listed per error type and period
#' @param tol journey-matching tolerance in seconds
#' @return path to data/stop_disagreement_2026.Rds
stop_gap_analysis <- function(freq_tnds, freq_bods, zones_path, year = 2026,
                              top_n = 5L, list_n = 25L, tol = 300,
                              cfg = load_cfg()) {
  suppressMessages(sf::sf_use_s2(FALSE))
  a <- readRDS(freq_tnds)
  b <- readRDS(freq_bods)
  stopifnot(identical(a$window, b$window), identical(a$day, b$day))
  win <- a$window
  day <- a$day
  tts <- list(tnds = a$tt, bods_gtfs = b$tt)

  # --- the stop table ------------------------------------------------------
  s <- merge(a$stops[, list(stop_id, name_t = stop_name, lon_t = stop_lon,
                            lat_t = stop_lat, win_tnds = n_win,
                            day_tnds = n_day)],
             b$stops[, list(stop_id, name_b = stop_name, lon_b = stop_lon,
                            lat_b = stop_lat, win_bods = n_win,
                            day_bods = n_day)],
             by = "stop_id", all = TRUE)
  data.table::setnafill(s, fill = 0, cols = c("win_tnds", "day_tnds",
                                              "win_bods", "day_bods"))
  s <- s[win_tnds + win_bods > 0]
  # A stop's position is NaPTAN's in both, but they can be read from
  # different NaPTAN editions; prefer the TNDS one where it has it, as the
  # stop-to-zone join for the LSOA report did.
  s[, stop_name := data.table::fifelse(is.na(name_t), name_b, name_t)]
  s[, stop_lon := data.table::fifelse(is.na(lon_t), lon_b, lon_t)]
  s[, stop_lat := data.table::fifelse(is.na(lat_t), lat_b, lat_t)]
  s[, moved_m := NA_real_]
  both_pos <- s[, !is.na(lon_t) & !is.na(lon_b)]
  s[both_pos, moved_m := geo_dist_m(lon_t, lat_t, lon_b, lat_b)]
  s[, c("name_t", "name_b", "lon_t", "lat_t", "lon_b", "lat_b") := NULL]
  s <- s[!is.na(stop_lon) & !is.na(stop_lat)]

  for (p in c("win", "day")) {
    ta <- paste0(p, "_tnds"); tb <- paste0(p, "_bods")
    s[, (paste0("gap_", p)) := get(ta) - get(tb)]
    s[, (paste0("type_", p)) := stop_gap_type(get(ta), get(tb))]
  }

  # Zone and position on the British National Grid
  pts <- sf::st_as_sf(s[, list(stop_id, stop_lon, stop_lat)],
                      coords = c("stop_lon", "stop_lat"), crs = 4326)
  pts <- sf::st_transform(pts, 27700)
  xy <- sf::st_coordinates(pts)
  s[, `:=`(x = xy[, 1], y = xy[, 2])]
  zones <- readRDS(zones_path)
  names(zones)[1] <- "zone_id"
  zones <- sf::st_transform(zones[, "zone_id"], 27700)
  zj <- sf::st_join(pts, zones, left = TRUE)
  zj <- data.table::as.data.table(sf::st_drop_geometry(zj))
  zj <- unique(zj, by = "stop_id")
  s <- merge(s, zj[, list(stop_id, zone_id = as.character(zone_id))],
             by = "stop_id", all.x = TRUE)
  s[, country := substr(zone_id, 1, 1)]
  rm(zones, zj, pts); gc()

  # A place a reader recognises. NaPTAN stop names are often just "Bus
  # Station" or "Interchange", and a zone code says nothing; the first three
  # characters of an ATCO code are its administrative area, which UK2GTFS
  # names (coverage_atco_areas(), as the coverage report uses).
  areas <- coverage_atco_areas()
  s[, area := if (is.null(areas)) NA_character_ else
    areas$name[match(substr(stop_id, 1, 3), areas$atco_code)]]

  # --- per-date breakdown, and the check against gtfs_stop_frequency() -----
  message("stop_gap: departures per stop and date")
  daily <- data.table::rbindlist(lapply(names(tts), function(src) {
    tt <- tts[[src]]
    d <- stop_date_departures(tt)
    d[, stop_id := tt$stops$stop_id[stop]][, stop := NULL]
    d[, source := src][]
  }))
  chk <- daily[, list(n = sum(n)), by = list(stop_id, source)]
  chk <- data.table::dcast(chk, stop_id ~ source, value.var = "n", fill = 0)
  chk <- merge(s[, list(stop_id, win_tnds, win_bods)], chk, by = "stop_id",
               all.x = TRUE)
  data.table::setnafill(chk, fill = 0, cols = intersect(c("tnds", "bods_gtfs"),
                                                        names(chk)))
  check <- list(
    stops = nrow(chk),
    mismatch_tnds = chk[abs(win_tnds - tnds) > 1e-6, .N],
    mismatch_bods = chk[abs(win_bods - bods_gtfs) > 1e-6, .N],
    total_tnds = c(stop_frequency = sum(chk$win_tnds), by_date = sum(chk$tnds)),
    total_bods = c(stop_frequency = sum(chk$win_bods),
                   by_date = sum(chk$bods_gtfs)))
  day_chk <- daily[date == day, list(n = sum(n)), by = source]
  check$day_total <- day_chk
  rm(chk)

  # National departures per date, split by the stop's window type, so the
  # report can show whether a source tails off across the window
  nat_daily <- merge(daily, s[, list(stop_id, type_win)], by = "stop_id")
  nat_daily <- nat_daily[, list(n = sum(n)), by = list(date, source, type_win)]

  # Per stop: the dates each source serves it, to recognise a source that
  # stops part way through the window
  span <- daily[n > 0, list(first = min(date), last = max(date),
                            days = data.table::uniqueN(date)),
                by = list(stop_id, source)]
  span <- data.table::dcast(span, stop_id ~ source,
                            value.var = c("first", "last", "days"))
  s <- merge(s, span, by = "stop_id", all.x = TRUE)

  # --- one-source stops with a counterpart nearby --------------------------
  # A stop served by one source only is either a stop the other source does
  # not serve, or the same buses filed under a neighbouring stop code - a
  # different stand at a bus station, the stop across the road, a code one
  # source has replaced. The nearest stop where the other source runs more is
  # the test (one_source_neighbours()).
  message("stop_gap: neighbouring one-source stops")
  for (p in c("win", "day")) {
    s <- one_source_neighbours(s, p)
  }

  # --- ranked lists and the cases -----------------------------------------
  rank_type <- function(p, ty, n) {
    d <- s[get(paste0("type_", p)) == ty]
    d <- d[order(-abs(get(paste0("gap_", p))))]
    utils::head(d, n)$stop_id
  }
  lists <- data.table::rbindlist(lapply(c("win", "day"), function(p) {
    data.table::rbindlist(lapply(stop_gap_types(), function(ty) {
      ids <- rank_type(p, ty, list_n)
      if (!length(ids)) return(NULL)
      data.table::data.table(period = p, type = ty, rank = seq_along(ids),
                             stop_id = ids)
    }))
  }))
  cases <- lists[rank <= top_n]
  focus <- unique(cases$stop_id)

  message("stop_gap: ", length(focus), " case stops")
  pat <- lapply(tts, stop_patterns)
  case_out <- lapply(focus, function(id) {
    message("  case ", id)
    stop_case(id, s, tts, pat, win, day, tol)
  })
  names(case_out) <- focus

  out <- list(window = win, day = day, year = year,
              feeds = c(tnds = a$feed, bods_gtfs = b$feed),
              stops = s[], check = check, nat_daily = nat_daily[],
              lists = lists[], cases = cases[], case = case_out,
              tol = tol, top_n = top_n)
  dest <- file.path(cfg$out_dir, sprintf("stop_disagreement_%s.Rds", year))
  saveRDS(out, dest)
  dest
}

geo_dist_m <- function(lon1, lat1, lon2, lat2) {
  rad <- pi / 180
  dlat <- (lat2 - lat1) * rad
  dlon <- (lon2 - lon1) * rad
  h <- sin(dlat / 2)^2 + cos(lat1 * rad) * cos(lat2 * rad) * sin(dlon / 2)^2
  2 * 6371008 * asin(pmin(1, sqrt(h)))
}

#' Nearest stop where the other source runs more, for one-source stops
#'
#' For a TNDS-only stop, the nearest stop within `max_m` at which BODS GTFS
#' counts more departures than TNDS - a BODS-only stop, or a BODS-higher one -
#' and how many more (`nb_n_<p>`, the surplus). The reverse for BODS-only
#' stops. A surplus close to this stop's own count is the same buses filed
#' under the neighbouring code.
#'
#' The first version looked only at stops of the *opposite one-source* kind and
#' missed the commonest arrangement: one source puts a route at stand A and
#' the other at stand B, while some other route calls at B in both, so B is
#' "BODS higher" rather than "BODS only".
one_source_neighbours <- function(s, p, max_m = 100) {
  ty <- paste0("type_", p)
  ta <- paste0(p, "_tnds"); tb <- paste0(p, "_bods")
  nb_id <- paste0("nb_", p); nb_d <- paste0("nb_m_", p); nb_n <- paste0("nb_n_", p)
  s[, (nb_id) := NA_character_]
  s[, (nb_d) := NA_real_]
  s[, (nb_n) := NA_real_]
  sides <- list(list(from = "TNDS only", own = ta, other = tb),
                list(from = "BODS only", own = tb, other = ta))
  for (sd in sides) {
    from <- s[get(ty) == sd$from]
    to <- s[get(sd$other) > get(sd$own) & get(ty) != sd$from]
    if (!nrow(from) || !nrow(to)) next
    # Exact nearest neighbour on a 200 m grid: candidates are the stops in the
    # same or an adjacent cell, which covers max_m.
    cell <- 200
    to[, `:=`(cx = floor(x / cell), cy = floor(y / cell))]
    from[, `:=`(cx = floor(x / cell), cy = floor(y / cell))]
    off <- data.table::CJ(dx = -1:1, dy = -1:1)
    cand <- from[, list(stop_id, x, y, cx, cy)][, k := 1L][off[, k := 1L],
                 on = "k", allow.cartesian = TRUE]
    cand[, `:=`(cx = cx + dx, cy = cy + dy)]
    cand <- merge(cand[, list(stop_id, x, y, cx, cy)],
                  to[, list(nb = stop_id, nx = x, ny = y, cx, cy,
                            nn = get(sd$other) - get(sd$own))],
                  by = c("cx", "cy"), allow.cartesian = TRUE)
    cand[, d := sqrt((x - nx)^2 + (y - ny)^2)]
    cand <- cand[d <= max_m][order(stop_id, d)][, .SD[1], by = stop_id]
    idx <- match(cand$stop_id, s$stop_id)
    data.table::set(s, idx, nb_id, cand$nb)
    data.table::set(s, idx, nb_d, cand$d)
    data.table::set(s, idx, nb_n, cand$nn)
  }
  s
}

#' Every distinct stop sequence in a source, and its consecutive stop pairs
#'
#' A pattern is a trip's ordered list of stops. The pairs (from, to) are what
#' routes are matched on: they carry the order, so a route's two directions
#' share none, and they survive a source naming one stop differently, which
#' costs two pairs rather than the whole route.
stop_patterns <- function(tt) {
  sig <- tt$st[, list(sig = paste(stop, collapse = ",")), by = trip]
  sig[, pattern := match(sig, unique(sig))]
  pats <- unique(sig[, list(pattern, sig)], by = "pattern")
  pats[, n_stops := lengths(strsplit(sig, ",", fixed = TRUE))]
  first_trip <- sig[, list(trip = trip[1]), by = pattern]
  pairs <- tt$st[trip %in% first_trip$trip]
  pairs <- merge(pairs, first_trip, by = "trip")
  data.table::setorder(pairs, pattern, seq)
  pairs <- pairs[, list(from = stop[-.N], to = stop[-1L]), by = pattern]
  pairs <- unique(pairs[from != to])
  pats <- merge(pats[, list(pattern, n_stops)],
                pairs[, list(n_pairs = .N), by = pattern],
                by = "pattern", all.x = TRUE)
  pats[is.na(n_pairs), n_pairs := 0L]
  list(trip_pattern = sig[, list(trip, pattern)], patterns = pats[],
       pairs = pairs[])
}

#' Greedy one-to-one matching of two sorted vectors of times within `tol`
match_sorted_times <- function(a, b, tol) {
  i <- 1L; j <- 1L
  ma <- integer(0); mb <- integer(0)
  while (i <= length(a) && j <= length(b)) {
    d <- a[i] - b[j]
    if (abs(d) <= tol) {
      ma <- c(ma, i); mb <- c(mb, j); i <- i + 1L; j <- j + 1L
    } else if (d < 0) {
      i <- i + 1L
    } else {
      j <- j + 1L
    }
  }
  list(a = ma, b = mb)
}

#' Everything the report shows about one stop
#'
#' 1. The routes calling at the stop in either source, and every pattern of
#'    those routes, so both directions are drawn even where the opposite
#'    direction uses the stop across the road.
#' 2. The patterns of the *other* source that share at least half their stop
#'    pairs with any of those, found from the pairs alone - which is what
#'    finds a route the other source files under a different number, or that
#'    serves a neighbouring stop code instead of this one.
#' 3. Patterns are linked across sources at that same threshold into
#'    directional groups, and the journeys of each group matched on their
#'    departure time at a stop both sources' patterns call at, date by date.
stop_case <- function(id, s, tts, pat, win, day, tol, min_sim = 0.5) {
  srcs <- names(tts)
  focus_row <- s[stop_id == id]
  dates <- seq(win$startdate, win$enddate, by = 1)

  # --- 1. seed patterns: the routes at the stop, in both directions --------
  seed <- lapply(srcs, function(src) {
    tt <- tts[[src]]
    k <- match(id, tt$stops$stop_id)
    if (is.na(k)) return(integer(0))
    trips <- unique(tt$st[stop == k, trip])
    routes <- unique(tt$trips[trip %in% trips, route_id])
    rtrips <- tt$trips[route_id %in% routes, trip]
    unique(pat[[src]]$trip_pattern[trip %in% rtrips, pattern])
  })
  names(seed) <- srcs

  # --- 2. the other source's patterns that share stop pairs ----------------
  # Stop pairs are compared by stop_id, since the integer codes are per source.
  pair_ids <- function(src, pats) {
    p <- pat[[src]]$pairs[pattern %in% pats]
    st <- tts[[src]]$stops$stop_id
    p[, list(pattern, from = st[from], to = st[to])]
  }
  sel <- seed
  for (src in srcs) {
    oth <- setdiff(srcs, src)
    sp <- pair_ids(src, seed[[src]])
    if (!nrow(sp)) next
    op <- pat[[oth]]$pairs
    ost <- tts[[oth]]$stops$stop_id
    # Only the other source's pairs that appear in the seed set are decoded,
    # which keeps this to a join against a few hundred pairs, not millions.
    key_from <- match(unique(sp$from), ost)
    cand <- op[from %in% key_from[!is.na(key_from)]]
    cand <- cand[, list(opat = pattern, from = ost[from], to = ost[to])]
    hits <- cand[sp, on = c("from", "to"), nomatch = 0L,
                 allow.cartesian = TRUE]
    if (!nrow(hits)) next
    # Shared pairs per (other pattern, seed pattern), over the smaller of the
    # two pair counts: a short-working of a long route matches it in full.
    hits <- hits[, list(shared = .N), by = list(opat, spat = pattern)]
    hits <- merge(hits, pat[[oth]]$patterns[, list(opat = pattern, n_o = n_pairs)],
                  by = "opat")
    hits <- merge(hits, pat[[src]]$patterns[, list(spat = pattern, n_s = n_pairs)],
                  by = "spat")
    hits <- hits[shared / pmax(1, pmin(n_o, n_s)) >= min_sim]
    sel[[oth]] <- unique(c(sel[[oth]], hits$opat))
  }

  # --- pattern table for the case -----------------------------------------
  ptab <- data.table::rbindlist(lapply(srcs, function(src) {
    tt <- tts[[src]]
    if (!length(sel[[src]])) return(NULL)
    tp <- pat[[src]]$trip_pattern[pattern %in% sel[[src]]]
    tp <- merge(tp, tt$trips[, list(trip, route_id, service_id, direction_id)],
                by = "trip")
    runs <- tt$sdates[service_id %in% tp$service_id,
                      list(days = .N), by = service_id]
    tp <- merge(tp, runs, by = "service_id", all.x = TRUE)
    tp[is.na(days), days := 0L]
    pt <- tp[, list(trips = .N, runs = sum(days),
                    route_id = names(sort(table(route_id), decreasing = TRUE))[1],
                    direction_id = direction_id[1]),
             by = pattern]
    pt <- merge(pt, tt$routes[, list(route_id, route_short_name,
                                     route_long_name, agency_name)],
                by = "route_id", all.x = TRUE)
    pt[, source := src][]
  }), fill = TRUE)
  if (is.null(ptab) || !nrow(ptab)) return(NULL)
  ptab[, node := paste(source, pattern, sep = ":")]

  # pairwise similarity, within and across sources
  pp <- data.table::rbindlist(lapply(srcs, function(src) {
    p <- pair_ids(src, ptab[source == src, pattern])
    if (!nrow(p)) return(NULL)
    p[, node := paste(src, pattern, sep = ":")][, list(node, from, to)]
  }))
  np <- pp[, list(n = .N), by = node]
  ed <- pp[pp, on = c("from", "to"), allow.cartesian = TRUE, nomatch = 0L]
  ed <- ed[node < i.node, list(shared = .N), by = list(node, i.node)]
  ed <- merge(ed, np, by = "node")
  ed <- merge(ed, np[, list(i.node = node, i.n = n)], by = "i.node")
  ed[, sim := shared / pmin(n, i.n)]
  ed <- ed[sim >= min_sim]

  # Directional groups: patterns linked by shared stop pairs, in either
  # source. Opposite directions share no pairs, so they land in separate
  # groups; `service` then joins the directions of the same routes back
  # together for the table.
  ptab[, group := connected_groups(node, ed$node, ed$i.node)]
  route_edges <- ptab[, list(node, key = paste(source, route_id))]
  re <- route_edges[route_edges, on = "key", allow.cartesian = TRUE][node < i.node]
  ptab[, service := connected_groups(node,
                                     c(ed$node, re$node),
                                     c(ed$i.node, re$i.node))]

  # cross-source similarity of each pattern (best match in the other source)
  best <- ed[substr(node, 1, 4) != substr(i.node, 1, 4)]
  best <- data.table::rbindlist(list(best[, list(node, sim)],
                                     best[, list(node = i.node, sim)]))
  best <- if (nrow(best)) best[, list(best_sim = max(sim)), by = node] else
    data.table::data.table(node = character(0), best_sim = numeric(0))
  ptab <- merge(ptab, best, by = "node", all.x = TRUE)
  ptab[is.na(best_sim), best_sim := 0]

  # Each pattern's single best counterpart in the other source: highest
  # similarity, then the same route number, then the busier pattern. Patterns
  # linked by those best-counterpart edges form `partner` sets, the first
  # matching pass's unit.
  xe <- ed[substr(node, 1, 4) != substr(i.node, 1, 4)]
  if (nrow(xe)) {
    xe <- data.table::rbindlist(list(xe[, list(node, other = i.node, sim)],
                                     xe[, list(node = i.node, other = node, sim)]))
    rn <- ptab[, list(node, rkey = toupper(gsub("[^A-Za-z0-9]", "",
                                                ifelse(is.na(route_short_name), "",
                                                       route_short_name))),
                      runs)]
    xe <- merge(xe, rn, by = "node")
    xe <- merge(xe, rn[, list(other = node, okey = rkey, oruns = runs)],
                by = "other")
    xe[, same_no := rkey != "" & rkey == okey]
    data.table::setorder(xe, node, -sim, -same_no, -oruns)
    xb <- xe[, .SD[1], by = node]
    ptab[, partner := connected_groups(node, xb$node, xb$other)]
    # A pattern with no counterpart is in a set of its own
    ptab[!node %in% xb$node & !node %in% xb$other, partner := NA_integer_]
  } else {
    ptab[, partner := NA_integer_]
  }

  # --- 3. journeys at the stop ---------------------------------------------
  # Every journey through the focus stop, with its date and departure time.
  jt <- data.table::rbindlist(lapply(srcs, function(src) {
    tt <- tts[[src]]
    k <- match(id, tt$stops$stop_id)
    if (is.na(k)) return(NULL)
    x <- trip_stop_times(tt, k)
    x <- merge(x, pat[[src]]$trip_pattern, by = "trip")
    x <- merge(x, tt$trips[, list(trip, service_id)], by = "trip")
    x <- merge(x, tt$sdates, by = "service_id", allow.cartesian = TRUE)
    x[, node := paste(src, pattern, sep = ":")]
    x[, list(source = src, trip, k, node, date, dep)]
  }))
  if (is.null(jt)) jt <- data.table::data.table(source = character(0),
                                                trip = integer(0), k = integer(0),
                                                node = character(0),
                                                date = as.Date(character(0)),
                                                dep = integer(0))
  jt <- merge(jt, ptab[, list(node, group, service, partner)], by = "node",
              all.x = TRUE)

  # Match date by date in two passes. A directional group can chain several
  # routes that share a corridor - the 5, 15, 115 and N15 through Canning
  # Town share most of their stop pairs - and matching on time alone across
  # the whole group would pair a 15 with a 115 two minutes apart. So journeys
  # are first matched only against their pattern's best counterpart in the
  # other source (`partner`), and what is left is then matched across the
  # group, which catches a journey the two sources file under different
  # patterns. A group one source lacks entirely matches nothing, which is the
  # "route absent" case.
  jt[, matched := FALSE][, offset := NA_real_]
  jt[, row := seq_len(.N)]
  for (by_col in c("partner", "group")) {
    cand <- jt[!is.na(get(by_col)) & !matched,
               list(row, source, dep, key = paste(get(by_col), date))]
    # only keys where both sources have journeys can match anything
    both <- cand[, data.table::uniqueN(source), by = key][V1 == 2L, key]
    cand <- cand[key %in% both]
    if (!nrow(cand)) next
    data.table::setorder(cand, key, dep)
    res <- cand[, {
      a <- which(source == "tnds"); b <- which(source == "bods_gtfs")
      m <- match_sorted_times(dep[a], dep[b], tol)
      off <- dep[b][m$b] - dep[a][m$a]
      list(row = c(row[a][m$a], row[b][m$b]), off = c(off, off))
    }, by = key]
    if (nrow(res)) jt[res$row, `:=`(matched = TRUE, offset = res$off)]
  }

  daily <- jt[, list(departures = .N, matched = sum(matched)),
              by = list(source, date)]
  daily <- merge(data.table::CJ(source = srcs, date = dates), daily,
                 by = c("source", "date"), all.x = TRUE)
  data.table::setnafill(daily, fill = 0, cols = c("departures", "matched"))

  hourly <- jt[date == day, list(departures = .N, matched = sum(matched)),
               by = list(source, hour = dep %/% 3600)]

  # Per directional group: who carries it, and how the journeys line up
  gsum <- jt[, list(dep_win = .N, matched_win = sum(matched),
                    dep_day = sum(date == day),
                    matched_day = sum(matched & date == day),
                    last = max(date), first = min(date),
                    median_offset = stats::median(abs(offset), na.rm = TRUE)),
             by = list(group, source)]
  vv <- c("dep_win", "matched_win", "dep_day", "matched_day", "first", "last",
          "median_offset")
  gsum <- data.table::dcast(gsum, group ~ source, value.var = vv)
  # dcast only makes the columns of sources present; the report wants both
  for (v in vv) for (src in srcs) {
    cn <- paste(v, src, sep = "_")
    if (!cn %in% names(gsum)) {
      gsum[, (cn) := if (v %in% c("first", "last")) as.Date(NA) else
        if (v == "median_offset") NA_real_ else 0L]
    }
  }
  glab <- ptab[order(-runs), list(
    service = service[1],
    names_tnds = paste(unique(stats::na.omit(route_short_name[source == "tnds"])),
                       collapse = ", "),
    names_bods = paste(unique(stats::na.omit(route_short_name[source == "bods_gtfs"])),
                       collapse = ", "),
    operator = paste(utils::head(unique(stats::na.omit(agency_name)), 2),
                     collapse = " / "),
    patterns_tnds = sum(source == "tnds"),
    patterns_bods = sum(source == "bods_gtfs"),
    runs_tnds = sum(runs[source == "tnds"]),
    runs_bods = sum(runs[source == "bods_gtfs"]),
    best_sim = max(best_sim)), by = group]
  groups <- merge(glab, gsum, by = "group", all.x = TRUE)
  # Groups that never call at the stop (the opposite direction, or the other
  # source's route at a neighbouring code) have no journeys here: zero, not NA
  for (cn in grep("^(dep|matched)_", names(groups), value = TRUE)) {
    data.table::set(groups, which(is.na(groups[[cn]])), cn, 0L)
  }

  # Terminal stops of the busiest pattern in each group, to describe it
  ends <- data.table::rbindlist(lapply(srcs, function(src) {
    tt <- tts[[src]]
    nodes <- ptab[source == src]
    if (!nrow(nodes)) return(NULL)
    tp <- pat[[src]]$trip_pattern[pattern %in% nodes$pattern]
    first_trip <- tp[, list(trip = trip[1]), by = pattern]
    st <- tt$st[trip %in% first_trip$trip]
    st <- merge(st, first_trip, by = "trip")
    data.table::setorder(st, pattern, seq)
    e <- st[, list(from = tt$stops$stop_name[stop[1]],
                   to = tt$stops$stop_name[stop[.N]]), by = pattern]
    e[, node := paste(src, pattern, sep = ":")][]
  }))
  ptab <- merge(ptab, ends[, list(node, from, to)], by = "node", all.x = TRUE)
  gdesc <- ptab[order(-runs), list(from = from[1], to = to[1]), by = group]
  groups <- merge(groups, gdesc, by = "group", all.x = TRUE)

  # --- geometry for the maps -----------------------------------------------
  lines <- data.table::rbindlist(lapply(srcs, function(src) {
    tt <- tts[[src]]
    nodes <- ptab[source == src]
    if (!nrow(nodes)) return(NULL)
    tp <- pat[[src]]$trip_pattern[pattern %in% nodes$pattern]
    first_trip <- tp[, list(trip = trip[1]), by = pattern]
    st <- tt$st[trip %in% first_trip$trip]
    st <- merge(st, first_trip, by = "trip")
    data.table::setorder(st, pattern, seq)
    st[, `:=`(lon = tt$stops$stop_lon[stop], lat = tt$stops$stop_lat[stop])]
    st[, node := paste(src, pattern, sep = ":")]
    st[!is.na(lon), list(node, seq, lon, lat)]
  }))

  # Stops near the focus, with both counts, for the close-up
  near <- s[abs(x - focus_row$x) <= 400 & abs(y - focus_row$y) <= 400,
            list(stop_id, stop_name, x, y, win_tnds, win_bods, day_tnds,
                 day_bods, type_win, type_day)]

  list(stop = focus_row, patterns = ptab[], groups = groups[], daily = daily[],
       hourly = hourly[], lines = lines[], near = near[],
       offsets = jt[matched == TRUE & source == "tnds", offset])
}

#' Connected components of a graph given as an edge list, as integer labels
connected_groups <- function(nodes, from, to) {
  g <- igraph::graph_from_data_frame(
    data.frame(from = from, to = to, stringsAsFactors = FALSE),
    directed = FALSE, vertices = data.frame(name = unique(nodes)))
  comp <- igraph::components(g)$membership
  as.integer(comp[nodes])
}

#' Knit the stop disagreement report to markdown
#'
#' @param rmd the report source, passed as a file target so that editing the
#'   Rmd alone rebuilds the report (the LSOA report's Rmd is not tracked, and
#'   needs tar_invalidate() after an edit)
render_stop_gap_report <- function(gap_path, rmd, zones_path = NULL,
                                   cfg = load_cfg()) {
  dir.create(cfg$report_dir, showWarnings = FALSE, recursive = TRUE)
  env <- new.env(parent = globalenv())
  env$gap_path <- normalizePath(gap_path)
  env$map_zones_path <- if (!is.null(zones_path)) map_zones_file(zones_path)
  old_wd <- setwd(cfg$report_dir)
  on.exit(setwd(old_wd), add = TRUE)
  knitr::knit(input = basename(rmd), output = "stop_disagreement.md",
              envir = env, quiet = TRUE)
  file.path(cfg$report_dir, "stop_disagreement.md")
}
