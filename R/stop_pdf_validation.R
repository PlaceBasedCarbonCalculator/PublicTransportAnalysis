# Checking the stop-level disagreement cases against published timetables.
#
# reports/stop_disagreement.md ranks the stops where TNDS and the DfT's BODS
# GTFS disagree most and draws the routes through each. It says what the two
# feeds contain, not which is right. This takes every route through those
# stops on which the two feeds disagree and sets it against the operator's
# own timetable.
#
# Two halves, kept apart on purpose:
#
#  * the documents. Each is read once, by scripts/stop_pdf_validation/
#    read_docs.py, into data/stop_pdf_documents.csv: the journeys per day, by
#    day type, that it prints at a named timing point, and where that timing
#    point is. A document does not change when the pipeline does, so this is
#    a fixed input; the script is rerun only when a document is added.
#  * the feeds. Counted here, by the pipeline, at the same place, from the
#    compact timetables the stop report already saved. They change whenever
#    the data or the conversion do, and so does the case list: a new case
#    stop arrives as routes "with no document yet", not as a silent gap.

#' How far round a case stop the feeds are counted for the disagreement list
#'
#' The stop report found many one-source stops to be the same buses filed
#' under a neighbouring stop code - Durham's Millburngate D and J are 1 m
#' apart. A document names a place, not a NaPTAN code, so a route is counted
#' at every stop within this distance, a journey once however many of them
#' it calls at. A pure stop-code difference therefore drops out of the list,
#' which is right: no timetable can settle it.
stop_check_radius <- function() 100

#' Day type of a date, as the documents print them
stop_dtype <- function(d) {
  w <- lubridate::wday(d, week_start = 1)
  data.table::fifelse(w == 7, "Su", data.table::fifelse(w == 6, "Sa", "MF"))
}

#' Journeys per day by route at a set of stops
#'
#' A journey (a trip on a date, times its frequency multiplier) is counted
#' once however many of `stops` it calls at. Per-day means divide by every
#' date of that type in the window, so a route that stops running part way
#' through is averaged over the days it does not run too.
#'
#' @param tt a compact timetable (compact_timetable())
#' @param stops integer stop indices into tt$stops
#' @param win,day the window and the single day
#' @return data.table route, dtype (MF/Sa/Su/day), per_day, operators
route_journeys_at <- function(tt, stops, win, day) {
  trips <- unique(tt$st[stop %in% stops, trip])
  if (!length(trips)) return(NULL)
  rt <- tt$routes[, list(route_id, route = toupper(trimws(route_short_name)),
                         agency_name)]
  tr <- merge(tt$trips[trip %in% trips, list(trip, route_id, service_id)],
              rt, by = "route_id")
  tr <- merge(tr, trip_departure_multiplier(tt), by = "trip", all.x = TRUE)
  tr[is.na(mult), mult := 1]
  sd <- merge(tr, tt$sdates, by = "service_id", allow.cartesian = TRUE)
  n_dates <- table(stop_dtype(seq(win$startdate, win$enddate, by = 1)))
  sd[, dtype := stop_dtype(date)]
  a <- sd[, list(n = sum(mult)), by = list(route, dtype)]
  a[, per_day := n / as.numeric(n_dates[dtype])]
  d <- sd[date == day, list(per_day = sum(mult)), by = route][, dtype := "day"]
  ops <- tr[, list(operators = paste(sort(unique(agency_name)), collapse = " / ")),
            by = route]
  res <- data.table::rbindlist(list(a[, list(route, dtype, per_day)], d),
                               use.names = TRUE)
  merge(res, ops, by = "route")
}

#' Stops within `radius_m` of a stop, optionally only those whose name matches
stops_near <- function(tt, centre_id, radius_m, name_regex = NULL, gap = NULL) {
  k <- match(centre_id, tt$stops$stop_id)
  if (is.na(k) && !is.null(gap)) {
    # the centre may be served only by the other source
    s <- gap$stops[stop_id == centre_id]
    lon <- s$stop_lon[1]; lat <- s$stop_lat[1]
  } else {
    lon <- tt$stops$stop_lon[k]; lat <- tt$stops$stop_lat[k]
  }
  if (is.na(lon)) return(integer(0))
  near <- which(geo_dist_m(lon, lat, tt$stops$stop_lon, tt$stops$stop_lat) <= radius_m)
  if (!is.null(name_regex) && !is.na(name_regex) && nzchar(name_regex)) {
    near <- near[grepl(name_regex, tt$stops$stop_name[near])]
  }
  near
}

#' The stop check: feeds against documents, case stop by case stop
#'
#' @param gap_path the stop_gap target (data/stop_disagreement_2026.Rds)
#' @param freq_paths named character, the stopfreq_* targets
#' @param docs_path data/stop_pdf_documents.csv
#' @param min_week,min_share a route is a disagreement worth a document when
#'   the two feeds differ by at least `min_week` journeys a week and by at
#'   least `min_share` of the larger, at the case stop
#' @param tol a source agrees with a document within this share, the rule of
#'   the zone checks
#' @return path of data/stop_pdf_validation.Rds
stop_pdf_check <- function(gap_path, freq_paths, docs_path,
                           out_path = "data/stop_pdf_validation.Rds",
                           min_week = 20, min_share = 0.1, tol = 0.15) {
  gap <- readRDS(gap_path)
  win <- gap$window
  ids <- unique(gap$cases$stop_id)
  docs <- read_stop_documents(docs_path)
  places <- unique(docs[, list(read_centre, read_radius_m, read_name, read_zone)])
  places[, place := seq_len(.N)]
  docs <- merge(docs, places, by = c("read_centre", "read_radius_m", "read_name",
                                     "read_zone"))

  at_case <- list(); at_doc <- list()
  for (src in names(freq_paths)) {
    tt <- readRDS(freq_paths[[src]])$tt
    for (id in ids) {
      r <- route_journeys_at(tt, stops_near(tt, id, stop_check_radius(), gap = gap),
                             win, gap$day)
      if (!is.null(r)) at_case[[length(at_case) + 1]] <- r[, `:=`(case_stop = id,
                                                                  source = src)]
    }
    for (i in seq_len(nrow(places))) {
      p <- places[i]
      st <- if (nzchar(p$read_zone)) {
        which(tt$stops$stop_id %in% gap$stops[zone_id == p$read_zone, stop_id])
      } else {
        stops_near(tt, p$read_centre, p$read_radius_m, p$read_name, gap = gap)
      }
      r <- route_journeys_at(tt, st, win, gap$day)
      if (!is.null(r)) at_doc[[length(at_doc) + 1]] <- r[, `:=`(place = p$place,
                                                               source = src)]
    }
    rm(tt); gc()
  }
  at_case <- data.table::rbindlist(at_case)
  at_doc <- data.table::rbindlist(at_doc)

  # --- the routes at each case stop, and which disagree ---------------------
  w <- stop_wide(at_case, c("case_stop", "route"), names(freq_paths))
  w[, disagree := abs(tnds_week - bods_gtfs_week) >= min_week &
      abs(tnds_week - bods_gtfs_week) >= min_share * pmax(tnds_week, bods_gtfs_week)]
  cases <- gap$cases[, list(cases = paste(sprintf(
    "%s %s #%d", ifelse(period == "win", "window", "day"), type, rank),
    collapse = "; ")), by = list(case_stop = stop_id)]
  info <- data.table::rbindlist(lapply(ids, function(id)
    gap$case[[id]]$stop[, list(case_stop = stop_id, stop_name, area, zone_id)]))
  routes <- merge(merge(info, cases, by = "case_stop"), w, by = "case_stop")

  # --- documents against the feeds at the document's own timing point -------
  fd <- stop_wide(at_doc, c("place", "route"), names(freq_paths))
  data.table::setnames(fd, setdiff(names(fd), c("place", "route")),
                       paste0("at_", setdiff(names(fd), c("place", "route"))))
  checks <- merge(docs, fd, by = c("place", "route"), all.x = TRUE)
  for (v in grep("^at_", names(checks), value = TRUE)) {
    data.table::set(checks, which(is.na(checks[[v]])), v, 0)
  }
  checks[, doc_week := week_journeys(doc_MF, doc_Sa, doc_Su)]
  checks[, `:=`(tnds_ratio = at_tnds_week / doc_week,
                bods_ratio = at_bods_gtfs_week / doc_week)]
  checks[, verdict := stop_doc_verdict(tnds_ratio, bods_ratio, tol)]
  # The same on the single day against the document's weekday column. A
  # source that stops part way through the window reads short over the
  # window and right on a day before it stops; the window figure alone cannot
  # tell that from a timetable that is short throughout. The day is a
  # weekday (stop_gap_day()), so it is compared with the Monday-Friday count.
  checks[, `:=`(tnds_day_ratio = at_tnds_day / doc_MF,
                bods_day_ratio = at_bods_gtfs_day / doc_MF)]
  checks[, verdict_day := stop_doc_verdict(tnds_day_ratio, bods_day_ratio, tol)]
  checks[reliable == FALSE, `:=`(verdict = NA_character_, verdict_day = NA_character_)]
  checks[, chosen := stop_doc_rank(edition_status, edition_from, win, reliable) ==
           min(stop_doc_rank(edition_status, edition_from, win, reliable)),
         by = list(case_stop, route)]
  # one document per case stop and route among equally good ones
  checks[chosen == TRUE, chosen := seq_len(.N) == 1L, by = list(case_stop, route)]
  checks[, place := NULL]

  routes <- merge(routes, checks[chosen == TRUE, list(case_stop, route, document,
                                                      edition_status, verdict,
                                                      verdict_day)],
                  by = c("case_stop", "route"), all.x = TRUE)
  out <- list(window = win, day = gap$day, radius_m = stop_check_radius(),
              min_week = min_week, min_share = min_share, tol = tol,
              routes = routes[], checks = checks[], docs_path = docs_path)
  saveRDS(out, out_path)
  out_path
}

#' Per-day counts by source and day type, wide, with journeys a week
stop_wide <- function(x, by, srcs) {
  w <- data.table::dcast(x, stats::as.formula(paste(paste(by, collapse = "+"),
                                                    "~ source + dtype")),
                         value.var = "per_day", fill = 0)
  for (src in srcs) for (d in c("MF", "Sa", "Su", "day")) {
    v <- paste(src, d, sep = "_")
    if (!v %in% names(w)) w[, (v) := 0]
    w[, paste0(src, "_week") := week_journeys(get(paste0(src, "_MF")),
                                              get(paste0(src, "_Sa")),
                                              get(paste0(src, "_Su")))]
  }
  ops <- x[, list(operators = paste(unique(unlist(strsplit(operators, " / "))),
                                    collapse = " / ")), by = by]
  merge(w, ops, by = by)
}

#' Journeys a week from per-day means
week_journeys <- function(MF, Sa, Su) 5 * MF + Sa + Su

#' Preference between documents for the same route and stop: in force first,
#' then the edition nearest the window; an unreliable reading last
stop_doc_rank <- function(status, from, win, reliable) {
  base <- c("in force" = 0, "earlier edition" = 1e4, "changed in window" = 1e4,
            "later edition" = 1e4)[status]
  base[is.na(base)] <- 5e4
  d <- abs(as.numeric(as.Date(from) - win$startdate))
  d[is.na(d)] <- 9999
  base + ifelse(status == "in force", 0, d) + ifelse(reliable, 0, 1e5)
}

#' The documents, as read by scripts/stop_pdf_validation/read_docs.py
read_stop_documents <- function(path) {
  d <- data.table::fread(path, colClasses = list(
    character = c("case_stop", "route", "read_centre", "read_name", "read_zone",
                  "edition_from")))
  for (v in c("read_centre", "read_name", "read_zone")) {
    data.table::set(d, which(is.na(d[[v]])), v, "")
  }
  d[is.na(read_radius_m), read_radius_m := 0]
  d[, route := toupper(trimws(route))]
  d[, reliable := as.logical(reliable)]
  data.table::setnames(d, c("MF", "Sa", "Su"), c("doc_MF", "doc_Sa", "doc_Su"))
  d[]
}

#' Which feed the document supports
#'
#' The rule of the zone checks: a feed is right when within `tol` of the
#' document, absent when it carries nothing.
stop_doc_verdict <- function(rt, rb, tol = 0.15) {
  ok_t <- !is.na(rt) & abs(rt - 1) <= tol
  ok_b <- !is.na(rb) & abs(rb - 1) <= tol
  dist <- function(r) abs(log(pmax(r, 1e-3)))
  data.table::fcase(
    is.na(rt) | is.na(rb) | !is.finite(rt) | !is.finite(rb), NA_character_,
    ok_t & ok_b, "both agree",
    ok_t & rb == 0, "TNDS right; BODS GTFS absent",
    ok_b & rt == 0, "BODS GTFS right; TNDS absent",
    ok_t, "TNDS right",
    ok_b, "BODS GTFS right",
    rt == 0 & rb == 0, "neither carries it",
    dist(rt) < dist(rb), "neither; TNDS closer",
    dist(rb) < dist(rt), "neither; BODS GTFS closer",
    default = "neither")
}
