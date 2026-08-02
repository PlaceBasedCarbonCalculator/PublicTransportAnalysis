# Journeys a feed describes twice with slightly different times.
#
# UK2GTFS::gtfs_deduplicate() matches itineraries exactly: same stops, same
# arrival and departure times, at every call. That catches most duplication,
# but not the case where one service is registered twice and the two
# registrations were written from different working timetables, so the same bus
# is booked at 08:14 in one and 08:15 in the other. Nothing in either file says
# they are the same bus, and no exact test can find them.
#
# This measures how much of that a feed contains and what a time-tolerant rule
# would cost, so the question "should gtfs_deduplicate gain a tolerance?" can be
# settled with numbers rather than with the handful of routes that raised it.
#
# The measurement deliberately runs on what SURVIVES exact deduplication, so
# everything it reports is additional to what is already removed.

#' How near-duplicate pairs are looked for
#'
#' Two trips are a candidate pair when all of these hold.
#'
#' 1. **Same service, to the same degree gtfs_deduplicate uses.** Same
#'    operator, `route_type` and `route_short_name`. `operator_keys()` supplies
#'    two readings of "same operator", and the difference between them is one
#'    of the results.
#' 2. **Same stops in the same order.** The stop sequence must be identical.
#'    Nothing weaker would do: two journeys over different roads are two
#'    journeys however close their times.
#' 3. **At least one shared operating day**, inside the 28-day window.
#' 4. **Within the tolerance at every stop.** The largest absolute difference
#'    anywhere on the journey is what is measured, not the difference at the
#'    first stop, so a pair that starts together and diverges is not a pair.
#'
#' Pairs are reported split by whether the two trips share a `route_id`,
#' because that split is the whole basis for judging false positives. Two
#' route_ids carrying the same journey is what a duplicate REGISTRATION looks
#' like. One route_id carrying two journeys a minute apart is what a genuine
#' close headway looks like - a relief bus, or a frequent corridor - and a
#' tolerant rule that swallowed those would delete real service. Neither is
#' proof, but the ratio between them at a given tolerance says whether that
#' tolerance is discriminating or guessing.
#'
#' @param tolerances seconds; the rule is evaluated at each
#' @param window_days length of the window the operating-day test uses. Must be
#'   at most 30: the days are held as bits of an integer.
near_duplicate_settings <- function() {
  list(tolerances = c(0L, 30L, 60L, 90L, 120L, 180L, 300L),
       # widest difference examined at all; bands beyond the tolerances are
       # what shows where the two populations cross over
       max_gap = 600L,
       # most neighbours examined per trip, in first-departure order
       max_neighbours = 60L,
       window_days = 28L,
       bands = list(breaks = c(-1, 0, 60, 120, 180, 300, 600),
                    labels = c("exactly 0", "1-60s", "61-120s", "121-180s",
                               "181-300s", "301-600s")))
}

#' The two readings of "the same operator"
#'
#' `name` is what UK2GTFS::gtfs_deduplicate() does by default: the feed's own
#' `agency_name`, lower-cased with punctuation collapsed. `noc` asks
#' Traveline's National Operator Codes register which company each agency
#' record belongs to, which joins records sharing neither an id nor a name -
#' TNDS files Stagecoach London both as `ELBG` and, where the operator
#' reference was never resolved to a code, as `IF` named "EAST LONDON BUS &
#' COACH COMPANY LIMITED".
operator_keys <- function() c("name", "noc")

#' Measure near-duplicate journeys in the validation snapshot's feeds
#'
#' Writes data/near_duplicates.Rds and returns its path.
#'
#' @param ... feed targets, taken for the dependency only
#' @param noc the NOC register; downloaded once if not supplied
near_duplicate_analysis <- function(..., cfg = load_cfg(),
                                    noc = UK2GTFS::get_noc()) {
  spec <- validation_snapshot()
  win <- study_window(spec$ref)
  set <- near_duplicate_settings()

  out <- list()
  for (src in validation_sources()) {
    message("near-duplicate scan: ", src)
    out[[src]] <- near_duplicates_one_feed(spec[[src]], win, noc, cfg, set)
    gc()
  }

  res <- list(snapshot = spec, window = win, settings = set, sources = out)
  dir.create(cfg$out_dir, showWarnings = FALSE, recursive = TRUE)
  path <- file.path(cfg$out_dir, "near_duplicates.Rds")
  saveRDS(res, path)
  path
}

#' @describeIn near_duplicate_analysis one feed, both operator keys
#' @noRd
near_duplicates_one_feed <- function(feed_path, win, noc, cfg, set) {
  g <- read_feed(feed_path, cfg, deduplicate = FALSE)
  n_published <- nrow(g$trips)
  g <- UK2GTFS::gtfs_trim_dates(g, startdate = win$startdate,
                                enddate = win$enddate)
  n_window <- nrow(g$trips)

  # What the operator key alone is worth, before any tolerance. Measured
  # rather than argued, because the intuition is wrong: joining two agency
  # records for one company only helps if the copies it joins have identical
  # times, and the ones worth joining generally do not.
  n_exact_noc <- nrow(UK2GTFS::gtfs_deduplicate(g, match_operator = "noc",
                                                noc = noc, quiet = TRUE)$trips)

  g <- UK2GTFS::gtfs_deduplicate(g)
  n_exact <- nrow(g$trips)

  trips0 <- data.table::as.data.table(as.data.frame(g$trips))[, list(
    trip_id = as.character(trip_id), route_id = as.character(route_id),
    service_id = as.character(service_id))]

  routes <- data.table::as.data.table(as.data.frame(g$routes))[, list(
    route_id = as.character(route_id),
    route_short_name = as.character(route_short_name),
    route_type = as.character(route_type),
    agency_id = as.character(agency_id))]
  agency <- data.table::as.data.table(as.data.frame(g$agency))[, list(
    agency_id = as.character(agency_id),
    agency_name = as.character(agency_name))]
  routes <- merge(routes, unique(agency, by = "agency_id"), by = "agency_id",
                  all.x = TRUE)
  routes[, op_name := trimws(tolower(gsub("[^[:alnum:]]+", " ", agency_name)))]
  routes[is.na(op_name) | op_name == "", op_name := paste0("id:", agency_id)]
  routes[, op_noc := UK2GTFS::noc_operator_key(agency_id, agency_name, noc)]
  # keep a readable label for the report, one per key value
  labels <- list(
    name = unique(routes[, list(op = op_name, label = agency_name)],
                  by = "op"),
    noc = unique(routes[, list(op = op_noc, label = agency_name)], by = "op"))

  # Times are converted BEFORE any row is dropped: subsetting a data.table
  # whose time column is an S4 Period silently corrupts it.
  st <- as.data.frame(g$stop_times)
  st <- data.table::data.table(
    trip_id = as.character(st$trip_id),
    stop_id = as.character(st$stop_id),
    seq = as.integer(st$stop_sequence),
    dep = as.numeric(UK2GTFS:::gtfs_time_to_seconds(st$departure_time)))
  data.table::setorderv(st, c("trip_id", "seq"))
  st <- st[trip_id %in% trips0$trip_id]
  pat <- st[, list(pattern = paste(stop_id, collapse = ">"), dep0 = dep[1],
                   nstop = .N), by = trip_id]

  mask <- service_day_mask(g, win, set$window_days)
  rm(g); gc()

  keys <- lapply(operator_keys(), function(k) {
    near_duplicates_one_key(trips0, routes, pat, st, mask,
                            paste0("op_", k), set, n_exact, labels[[k]])
  })
  names(keys) <- operator_keys()

  list(n_published = n_published, n_window = n_window, n_exact = n_exact,
       n_exact_noc = n_exact_noc, keys = keys)
}

#' A bitmask of the days each service runs, inside the window
#'
#' One bit per day, so testing whether two services ever run together is a
#' single bitwAnd instead of a set intersection - the pairing step does it
#' millions of times.
#' @noRd
service_day_mask <- function(g, win, window_days) {
  sd <- UK2GTFS:::service_operating_dates(g)
  d0 <- as.integer(as.Date(win$startdate))
  sd <- sd[date >= d0 & date < d0 + window_days]
  sd[, bit := bitwShiftL(1L, as.integer(date - d0))]
  sd[, list(mask = Reduce(bitwOr, bit)), by = service_id]
}

#' @describeIn near_duplicate_analysis the pairing, for one operator key
#' @noRd
near_duplicates_one_key <- function(trips0, routes, pat, st, mask, keycol,
                                    set, n_exact, labels) {
  trips <- merge(trips0, routes[, c("route_id", "route_short_name",
                                    "route_type", keycol), with = FALSE],
                 by = "route_id")
  data.table::setnames(trips, keycol, "op")
  trips[, rkey := paste(op, route_type, route_short_name, sep = "\r")]
  trips <- merge(trips, pat, by = "trip_id")
  trips <- trips[!is.na(dep0) & nstop >= 2L]
  trips[, grp := .GRP, by = list(rkey, pattern)]
  trips <- merge(trips, mask, by = "service_id")
  data.table::setorderv(trips, c("grp", "dep0", "trip_id"))
  trips[, idx := .I]
  trips[, k := seq_len(.N), by = grp]

  # Candidate pairs are neighbours in first-departure order. Walking outwards
  # one rank at a time and stopping when no neighbour is still within max_gap
  # avoids forming every pair in a group, which for a frequent city route over
  # 28 days would be millions of pairs almost all far apart.
  base <- trips[, list(grp, k, dep0, idx, route_id, mask)]
  acc <- list()
  truncated <- FALSE
  for (off in seq_len(set$max_neighbours)) {
    b <- data.table::copy(base)[, k := k - off]
    data.table::setnames(b, c("dep0", "idx", "route_id", "mask"),
                         c("dep0_b", "ib", "rid_b", "mask_b"))
    m <- merge(base, b, by = c("grp", "k"))
    m <- m[dep0_b - dep0 <= set$max_gap]
    if (!nrow(m)) break
    if (off == set$max_neighbours) truncated <- TRUE
    acc[[off]] <- m[, list(ia = idx, ib, same_route = route_id == rid_b,
                           shared = bitwAnd(mask, mask_b) != 0L)]
  }
  pairs <- data.table::rbindlist(acc)
  n_candidate <- nrow(pairs)
  pairs <- pairs[shared == TRUE]

  # the widest difference anywhere on the journey, not just at the first stop
  s <- st[trip_id %in% trips$trip_id]
  s[, tidx := trips$idx[match(trip_id, trips$trip_id)]]
  s[, pos := seq_len(.N), by = tidx]
  s <- s[, list(tidx, pos, dep)]
  p <- merge(pairs[, list(ia, ib)], s, by.x = "ia", by.y = "tidx",
             allow.cartesian = TRUE)
  p <- merge(p, s, by.x = c("ib", "pos"), by.y = c("tidx", "pos"),
             suffixes = c("_a", "_b"))
  mx <- p[, list(maxdiff = max(abs(dep_a - dep_b), na.rm = TRUE)),
          by = list(ia, ib)]
  rm(p, s); gc()
  pairs <- merge(pairs, mx[is.finite(maxdiff)], by = c("ia", "ib"))

  b <- set$bands
  pairs[, band := cut(maxdiff, b$breaks, b$labels)]
  # every band is present in the output even when empty, so the report can
  # index them by name without checking first
  counts <- pairs[!is.na(band), list(.N), by = list(band, same_route)]
  bands <- data.table::CJ(band = factor(b$labels, b$labels),
                          same_route = c(FALSE, TRUE))
  bands <- merge(bands, counts, by = c("band", "same_route"), all.x = TRUE)
  bands[is.na(N), N := 0L]
  bands <- data.table::dcast(bands, band ~ same_route, value.var = "N",
                             fill = 0L)
  data.table::setnames(bands, c("FALSE", "TRUE"),
                       c("cross_route", "within_route"), skip_absent = TRUE)

  cum <- data.table::rbindlist(lapply(set$tolerances, function(t) {
    x <- pairs[!same_route & maxdiff <= t]
    y <- pairs[same_route == TRUE & maxdiff <= t]
    data.table::data.table(
      tolerance = t,
      cross_pairs = nrow(x),
      cross_trips = data.table::uniqueN(c(x$ia, x$ib)),
      within_pairs = nrow(y),
      within_trips = data.table::uniqueN(c(y$ia, y$ib)))
  }))
  cum[, cross_pct := 100 * cross_trips / n_exact]
  cum[, extra_trips := cross_trips - cross_trips[tolerance == 0L]]

  list(n_groups = data.table::uniqueN(trips$grp),
       n_candidate_pairs = n_candidate, truncated = truncated,
       bands = bands, cumulative = cum,
       services = near_duplicate_services(pairs, trips, labels))
}

#' The services a tolerant rule would act on, and those it would risk
#'
#' Three lists, all keyed on the service rather than the pair: what a one
#' minute rule would newly act on, what widening to two minutes would add, and
#' the within-route pairs that widening would admit - the false positives, if
#' they are false positives.
#' @noRd
near_duplicate_services <- function(pairs, trips, labels) {
  named <- function(p) {
    if (!nrow(p)) {
      return(data.table::data.table(operator = character(0),
                                    line = character(0), routes = integer(0),
                                    trips = integer(0)))
    }
    inv <- unique(data.table::rbindlist(list(p[, list(idx = ia)],
                                             p[, list(idx = ib)])))
    inv <- merge(inv, trips[, list(idx, route_id, rkey, op, route_short_name)],
                 by = "idx")
    out <- inv[, list(routes = data.table::uniqueN(route_id), trips = .N),
               by = list(op, line = route_short_name)][order(-trips)]
    out[, operator := labels$label[match(op, labels$op)]]
    out[, op := NULL]
    out[, list(operator, line, routes, trips)]
  }
  list(
    at_60 = named(pairs[!same_route & maxdiff > 0 & maxdiff <= 60]),
    added_60_to_120 = named(pairs[!same_route & maxdiff > 60 & maxdiff <= 120]),
    risked_60_to_120 = named(pairs[same_route == TRUE & maxdiff > 60 &
                                     maxdiff <= 120]))
}

#' Knit the near-duplicate report to markdown
render_near_duplicate_report <- function(near_path, cfg = load_cfg()) {
  dir.create(cfg$report_dir, showWarnings = FALSE, recursive = TRUE)
  env <- new.env(parent = globalenv())
  env$near_path <- normalizePath(near_path)
  old_wd <- setwd(cfg$report_dir)
  on.exit(setwd(old_wd), add = TRUE)
  knitr::knit(input = "near_duplicate_journeys.Rmd",
              output = "near_duplicate_journeys.md", envir = env, quiet = TRUE)
  file.path(cfg$report_dir, "near_duplicate_journeys.md")
}
