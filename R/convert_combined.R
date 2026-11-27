# A combined bus feed: TNDS and BODS TransXChange, chosen service by service
#
# reports/gtfs_iteration_nov2026.md §5 found that TNDS and UK2GTFS's
# conversion of the BODS TransXChange archive fail in different places: TNDS
# lags BODS and runs out early, BODS lacks London, Scotland, Wales and a
# number of English services. It proposed a per-service choice between them,
# not the wholesale merge source_triangulation.md rejected (that counted every
# service both carry twice):
#
#  1. match services across the two sources on line name plus at least half
#     their stops (operator codes differ between them);
#  2. for a matched service take the source whose newest timetable is newer
#     and covers the window, and drop the other's; a service in one source
#     only is taken from that source;
#  3. filter each source's files as now.
#
# Here the choice is made on the two converted feeds, after each source has
# been filtered and converted on its own, not on the raw files before. Two
# reasons. txc_filter_files() decides between versions by looking at every
# file of a service; removing a source's current file before filtering could
# let an older version that matched nothing come back. And the untrimmed
# conversion caches still carry each timetable's real operating period, which
# is what says which source is newer. The feeds are the same ones the
# comparisons already use, so any difference is the choice alone.
#
# A second matching pass catches the same service under different line names
# in the two sources (project naming gap: "X1" against "X1 Express"): the
# same departures from the same first stop, over at least half the stops.

#' Days each calendar service_id runs between two dates
#' @return data.table(service_id, date)
calendar_active_days <- function(cal, cd, from, to) {
  wdn <- c("sunday", "monday", "tuesday", "wednesday", "thursday", "friday",
           "saturday")
  days <- data.table::data.table(
    date = data.table::as.IDate(seq(as.Date(from), as.Date(to), by = "day")))
  days[, wd := wdn[data.table::wday(date)]]
  cl <- data.table::melt(cal[, c("service_id", "start_date", "end_date", wdn),
                             with = FALSE],
                         id.vars = c("service_id", "start_date", "end_date"),
                         variable.name = "wd", value.name = "flag",
                         variable.factor = FALSE)
  cl <- cl[flag == 1L & start_date <= max(days$date) & end_date >= min(days$date)]
  act <- cl[days, on = "wd", allow.cartesian = TRUE, nomatch = 0L][
    date >= start_date & date <= end_date, list(service_id, date)]
  from <- data.table::as.IDate(from); to <- data.table::as.IDate(to)
  add <- cd[exception_type == 1L & date >= from & date <= to, list(service_id, date)]
  rem <- cd[exception_type == 2L & date >= from & date <= to, list(service_id, date)]
  act <- unique(data.table::rbindlist(list(act, add)))
  act[!rem, on = c("service_id", "date")]
}

#' The services of a converted feed, with what the choice needs to know
#'
#' A service is an agency plus the TransXChange ServiceCode UK2GTFS writes
#' into route_desc ("[ServiceCode: PB0002717:87]"), or the route where there
#' is none: the registration, which can span several lines and files.
#'
#' @param win study window (study_window()): trips per service are counted
#'   over it, and it decides which timetable is newest and whether a source
#'   covers it
#' @param span the period the output keeps (Date pair); services wholly
#'   outside it take no part
#' @return list(svc, trips, lines, stops, keys)
combined_services <- function(gtfs, source, win, span) {
  r <- data.table::as.data.table(as.data.frame(gtfs$routes))
  r <- r[, list(route_id = as.character(route_id),
                agency_id = as.character(agency_id),
                line = line_key(route_short_name),
                route_type = as.integer(route_type),
                desc = as.character(route_desc))]
  r[, sc := data.table::fifelse(grepl("[ServiceCode: ", desc, fixed = TRUE),
                                sub("^.*\\[ServiceCode: ([^]]*)\\].*$", "\\1", desc),
                                NA_character_)]
  r[, svc := paste(source, agency_id,
                   data.table::fifelse(is.na(sc) | sc == "",
                                       paste0("route ", route_id), sc),
                   sep = " | ")]
  ag <- data.table::as.data.table(as.data.frame(gtfs$agency))[
    , list(agency_id = as.character(agency_id),
           agency_name = as.character(agency_name))]
  r <- merge(r, unique(ag, by = "agency_id"), by = "agency_id", all.x = TRUE)

  tr <- data.table::data.table(trip_id = as.character(gtfs$trips$trip_id),
                               route_id = as.character(gtfs$trips$route_id),
                               service_id = as.character(gtfs$trips$service_id))
  tr <- merge(tr, r[, list(route_id, svc)], by = "route_id")

  cal <- data.table::as.data.table(as.data.frame(gtfs$calendar))
  cal[, `:=`(service_id = as.character(service_id),
             start_date = data.table::as.IDate(start_date),
             end_date = data.table::as.IDate(end_date))]
  cd <- data.table::as.data.table(as.data.frame(gtfs$calendar_dates))
  cd[, `:=`(service_id = as.character(service_id),
            date = data.table::as.IDate(date),
            exception_type = as.integer(exception_type))]
  span_id <- rbind(cal[, list(service_id, start = start_date, end = end_date)],
                   cd[exception_type == 1L & !service_id %in% cal$service_id,
                      list(start = min(date), end = max(date)), by = service_id])
  act <- calendar_active_days(cal, cd, win$startdate, win$enddate)
  nd <- act[, list(ndays = .N, last_day = max(date)), by = service_id]
  sid <- merge(span_id, nd, by = "service_id", all.x = TRUE)
  sid[is.na(ndays), ndays := 0L]

  tr <- merge(tr, sid, by = "service_id", all.x = TRUE)
  tr[is.na(ndays), ndays := 0L]
  w_end <- data.table::as.IDate(win$enddate)
  mx <- function(x) if (all(is.na(x))) data.table::as.IDate(NA) else max(x, na.rm = TRUE)
  svc <- tr[, list(n_trips = .N, trips_win = sum(ndays),
                   start_min = min(start, na.rm = TRUE),
                   end_max = max(end, na.rm = TRUE),
                   # the newest timetable running in the window
                   newest = mx(start[ndays > 0]),
                   last_day = mx(last_day[ndays > 0])),
            by = svc]
  # still running in the window's last week: a source that "runs out early"
  # fails this, whatever its weekly pattern
  svc[, covers := !is.na(last_day) & last_day >= w_end - 6L]
  svc[, in_span := start_min <= data.table::as.IDate(span[2]) &
        end_max >= data.table::as.IDate(span[1])]
  info <- r[, list(agency_id = agency_id[1], agency = agency_name[1],
                   lines = paste(sort(unique(line[line != ""])), collapse = ";"),
                   route_type = paste(sort(unique(route_type)), collapse = ";")),
            by = svc]
  svc <- merge(info, svc, by = "svc")
  svc[, source := source]

  keep <- svc[in_span == TRUE, svc]
  trs <- tr[svc %in% keep]
  lines <- unique(merge(trs[, list(route_id, svc)], r[, list(route_id, line)],
                        by = "route_id")[line != "", list(svc, line)])
  st <- data.table::data.table(trip_id = as.character(gtfs$stop_times$trip_id),
                               stop_id = toupper(as.character(gtfs$stop_times$stop_id)),
                               seq = as.integer(gtfs$stop_times$stop_sequence),
                               row = seq_len(nrow(gtfs$stop_times)))
  st <- st[trip_id %in% trs$trip_id]
  st[, svc := trs$svc[match(trip_id, trs$trip_id)]]
  stops <- unique(st[, list(svc, stop_id)])
  data.table::setorder(st, trip_id, seq)
  first <- st[!duplicated(trip_id)]
  rm(st)
  # the Period columns are indexed as vectors, never row-subset as a table
  dep <- lubridate::period_to_seconds(gtfs$stop_times$departure_time[first$row])
  arr <- lubridate::period_to_seconds(gtfs$stop_times$arrival_time[first$row])
  first[, dep := data.table::fifelse(is.na(dep), arr, dep)]
  first <- first[trip_id %in% trs[ndays > 0, trip_id]]
  keys <- unique(first[, list(svc, key = paste(stop_id, dep))])
  ns <- stops[, list(n_stops = .N), by = svc]
  svc <- merge(svc, ns, by = "svc", all.x = TRUE)
  svc[is.na(n_stops), n_stops := 0L]
  list(svc = svc[], trips = tr[, list(trip_id, svc)], lines = lines,
       stops = stops, keys = keys)
}

#' Match services between TNDS and BODS TransXChange
#'
#' Pass 1: a line name in common and at least `share` of the smaller
#' service's stops shared. Pass 2, for services pass 1 left unmatched on
#' either side: at least `share` of the smaller service's first-stop
#' departures (stop and time) the same, at least two, and the same stop test,
#' whatever the line names.
#' @return data.table(t, b, pass, shared, stop_share, key_share)
combined_match <- function(ts, bs, share = 0.5) {
  it <- ts$svc[in_span == TRUE, svc]
  ib <- bs$svc[in_span == TRUE, svc]
  st_t <- ts$stops[svc %in% it]
  st_b <- bs$stops[svc %in% ib]
  n_t <- st_t[, list(n_t = .N), by = list(t = svc)]
  n_b <- st_b[, list(n_b = .N), by = list(b = svc)]
  sh <- st_t[st_b, on = "stop_id", nomatch = 0L, allow.cartesian = TRUE][
    , list(shared = .N), by = list(t = svc, b = i.svc)]
  sh <- merge(merge(sh, n_t, by = "t"), n_b, by = "b")
  sh[, stop_share := shared / pmin(n_t, n_b)]

  lt <- ts$lines[svc %in% it]
  lb <- bs$lines[svc %in% ib]
  cand <- unique(lt[lb, on = "line", nomatch = 0L, allow.cartesian = TRUE][
    , list(t = svc, b = i.svc)])
  p1 <- merge(cand, sh, by = c("t", "b"))[stop_share >= share]
  p1[, `:=`(pass = 1L, key_share = NA_real_)]

  kt <- ts$keys[svc %in% it]
  kb <- bs$keys[svc %in% ib]
  nk_t <- kt[, list(nk_t = .N), by = list(t = svc)]
  nk_b <- kb[, list(nk_b = .N), by = list(b = svc)]
  ks <- kt[kb, on = "key", nomatch = 0L, allow.cartesian = TRUE][
    , list(nkey = .N), by = list(t = svc, b = i.svc)]
  ks <- merge(merge(ks, nk_t, by = "t"), nk_b, by = "b")
  ks[, key_share := nkey / pmin(nk_t, nk_b)]
  ks <- ks[nkey >= 2 & key_share >= share]
  ks <- ks[!t %in% p1$t | !b %in% p1$b]
  p2 <- merge(ks[, list(t, b, key_share)], sh, by = c("t", "b"))[stop_share >= share]
  p2[, pass := 2L]
  cols <- c("t", "b", "pass", "shared", "stop_share", "key_share")
  data.table::rbindlist(list(p1[, cols, with = FALSE], p2[, cols, with = FALSE]))
}

#' Choose a source for each group of matched services
#'
#' Matched services are grouped into connected components (one BODS
#' registration can match two TNDS files and the reverse). In each group:
#'
#'  * a doubling first: if one source runs between `doubling[1]` and
#'    `doubling[2]` times the other's journeys in the window, the smaller is
#'    taken. Not in the §5 design; added after the 18 November dry run, where
#'    184 of about 7,100 groups fell in that band, split evenly between the
#'    sources, and every case read was a bus counted twice: versions left
#'    open in BODS (National Express West Midlands republished beside West
#'    Midlands Bus, Green Line 757, London 372 and 465) and copies in TNDS
#'    (Arriva Cymru's North West and Wales files, Arriva SB1, Bee Network
#'    612). The one exception found was Preston 35, where the operator's
#'    timetable sides with BODS's larger count. The fresher source is often
#'    the doubled one, so freshness alone gets these wrong;
#'  * likewise at any ratio from `doubling[1]` up if the larger source runs
#'    the group under more operators than the smaller: a second operator's
#'    copy left beside the first (National Express Coventry 20 and 22 beside
#'    West Midlands Bus at 3.2 and 2.8 times; Harris and Stagecoach South
#'    Wales C16; Grant Palmer and Stagecoach East 25). Beyond the doubling
#'    band with one operator a side the larger count is sometimes right
#'    (Arriva North East X93, 2.4 times, where the timetable sides with
#'    BODS), so the ratio alone is not used there;
#'  * the source whose newest timetable running in the window started later
#'    is the fresher; if it also runs into the window's last week it wins;
#'  * otherwise a source that covers the window beats one that runs out;
#'  * otherwise the fresher one, and failing that TNDS, the better single
#'    source on the evidence so far.
#' @return the services of both sources, with comp, choice, reason and keep
combined_choose <- function(ts, bs, edges, doubling = c(1.7, 2.3)) {
  svc <- data.table::rbindlist(list(ts, bs), use.names = TRUE)
  if (nrow(edges)) {
    g <- igraph::graph_from_data_frame(edges[, list(t, b)], directed = FALSE)
    m <- igraph::components(g)$membership
    svc <- merge(svc, data.table::data.table(svc = names(m), comp = as.integer(m)),
                 by = "svc", all.x = TRUE)
  } else {
    svc[, comp := NA_integer_]
  }
  mx <- function(x) if (all(is.na(x))) data.table::as.IDate(NA) else max(x, na.rm = TRUE)
  dec <- svc[!is.na(comp), list(
    t_services = sum(source == "tnds"), b_services = sum(source == "bods_txc"),
    t_trips = sum(trips_win[source == "tnds"]),
    b_trips = sum(trips_win[source == "bods_txc"]),
    t_newest = mx(newest[source == "tnds"]),
    b_newest = mx(newest[source == "bods_txc"]),
    t_cov = any(covers[source == "tnds"]),
    b_cov = any(covers[source == "bods_txc"]),
    t_ops = data.table::uniqueN(agency_id[source == "tnds" & trips_win > 0]),
    b_ops = data.table::uniqueN(agency_id[source == "bods_txc" & trips_win > 0])),
    by = comp]
  dec[, fresh := data.table::fcase(
    is.na(t_newest) & is.na(b_newest), "",
    is.na(t_newest), "bods_txc",
    is.na(b_newest), "tnds",
    b_newest > t_newest, "bods_txc",
    t_newest > b_newest, "tnds",
    default = "")]
  dec[, ratio := pmax(t_trips, b_trips) / pmax(1, pmin(t_trips, b_trips))]
  dec[, doubled := !is.null(doubling) & t_trips > 0 & b_trips > 0 &
        ratio >= doubling[1] &
        (ratio < doubling[2] |
           (t_trips > b_trips & t_ops > b_ops) |
           (b_trips > t_trips & b_ops > t_ops))]
  # what the §5 rule alone would have chosen, kept for the report
  dec[, choice_fresh := data.table::fcase(
    fresh == "tnds" & t_cov, "tnds",
    fresh == "bods_txc" & b_cov, "bods_txc",
    t_cov & !b_cov, "tnds",
    b_cov & !t_cov, "bods_txc",
    fresh != "", fresh,
    default = "tnds")]
  dec[, `:=`(
    choice = data.table::fcase(
      doubled & t_trips < b_trips, "tnds",
      doubled & b_trips < t_trips, "bods_txc",
      fresh == "tnds" & t_cov, "tnds",
      fresh == "bods_txc" & b_cov, "bods_txc",
      t_cov & !b_cov, "tnds",
      b_cov & !t_cov, "bods_txc",
      fresh != "", fresh,
      default = "tnds"),
    reason = data.table::fcase(
      doubled, "the other source runs it about twice",
      fresh != "" & ((fresh == "tnds" & t_cov) | (fresh == "bods_txc" & b_cov)),
      "newer, and runs to the window's end",
      t_cov != b_cov, "the only one running to the window's end",
      fresh != "", "newer; neither runs to the window's end",
      default = "same start: TNDS by default"))]
  svc <- merge(svc, dec[, list(comp, choice, reason)], by = "comp", all.x = TRUE)
  svc[is.na(comp), `:=`(choice = source, reason = "in one source only")]
  svc[, keep := in_span & source == choice]
  list(svc = svc[], components = dec[])
}

#' Build the combined feed for one snapshot
#'
#' Reads the untrimmed TNDS region caches and the untrimmed BODS
#' TransXChange cache, chooses a source per service, keeps each kept
#' service's trips from its source, merges (TNDS first, so a stop in both
#' takes TNDS's record), and writes two feeds trimmed to the snapshot +/-
#' tnds_trim_days(): the choice alone, and the choice followed by the
#' cross-file copy rule (gtfs_deduplicate_copies(), run untrimmed as it must
#' be; R/convert_copies.R).
#'
#' @param tnds_dir folder under gtfs/cache with the TNDS region caches
#' @param bods_cache path to the BODS TransXChange cache (*_full.zip)
#' @param ref a date in the comparison window (study_window())
#' @param after the conversion targets this reads the caches of, so targets
#'   orders them
#' @return c(services csv, feed, feed with the copy rule)
build_combined_feed <- function(snapshot, tnds_dir, bods_cache, ref,
                                after = NULL, cfg = load_cfg(),
                                name = paste0("combined_", snapshot)) {
  win <- study_window(ref)
  snap <- lubridate::ymd(snapshot)
  span <- c(snap - tnds_trim_days(), snap + tnds_trim_days())
  zips <- list.files(file.path(cfg$gtfs_dir, "cache", tnds_dir), "\\.zip$",
                     full.names = TRUE)
  if (!length(zips)) stop("No TNDS region caches in ", tnds_dir)
  message("combined ", snapshot, ": reading ", length(zips), " TNDS caches")
  gt <- UK2GTFS::gtfs_merge(lapply(zips, UK2GTFS::gtfs_read), force = TRUE)
  message("combined ", snapshot, ": reading ", bods_cache)
  gb <- UK2GTFS::gtfs_read(bods_cache)

  ts <- combined_services(gt, "tnds", win, span)
  bs <- combined_services(gb, "bods_txc", win, span)
  edges <- combined_match(ts, bs)
  ch <- combined_choose(ts$svc, bs$svc, edges)
  out <- file.path("data", "combined", snapshot)
  dir.create(out, showWarnings = FALSE, recursive = TRUE)
  svc_csv <- file.path(out, "services.csv")
  data.table::fwrite(ch$svc, svc_csv)
  data.table::fwrite(edges, file.path(out, "matches.csv"))
  data.table::fwrite(ch$components, file.path(out, "components.csv"))
  message(sprintf("combined %s: %d matched groups, %d to BODS; kept %d TNDS and %d BODS services",
                  snapshot, nrow(ch$components),
                  ch$components[choice == "bods_txc", .N],
                  ch$svc[keep & source == "tnds", .N],
                  ch$svc[keep & source == "bods_txc", .N]))

  subset_feed <- function(g, s) {
    ids <- s$trips[svc %in% ch$svc[keep == TRUE, svc], trip_id]
    g <- UK2GTFS::gtfs_split_ids(g, ids)$true
    stopifnot(length(g$stop_times$departure_time) == nrow(g$stop_times))
    g
  }
  gt <- subset_feed(gt, ts)
  gb <- subset_feed(gb, bs)
  rm(ts, bs); gc()
  # an agency id both sources use for different operators would be merged
  # into one name; keep the BODS one apart
  clash <- merge(data.table::data.table(agency_id = as.character(gt$agency$agency_id),
                                        n_t = as.character(gt$agency$agency_name)),
                 data.table::data.table(agency_id = as.character(gb$agency$agency_id),
                                        n_b = as.character(gb$agency$agency_name)),
                 by = "agency_id")[n_t != n_b, agency_id]
  if (length(clash)) {
    message("combined ", snapshot, ": ", length(clash),
            " agency ids used for different operators; BODS ones prefixed")
    gb$agency$agency_id <- ifelse(gb$agency$agency_id %in% clash,
                                  paste0("bods:", gb$agency$agency_id),
                                  gb$agency$agency_id)
    gb$routes$agency_id <- ifelse(gb$routes$agency_id %in% clash,
                                  paste0("bods:", gb$routes$agency_id),
                                  gb$routes$agency_id)
  }
  merged <- UK2GTFS::gtfs_merge(list(gt, gb), force = TRUE)
  rm(gt, gb); gc()

  finish <- function(g, nm) {
    g <- UK2GTFS::gtfs_trim_dates(g, startdate = span[1], enddate = span[2])
    g <- UK2GTFS::gtfs_clean(g)
    write_repo_gtfs(g, nm)
  }
  p1 <- finish(merged, paste0(name, "_merged"))
  merged <- apply_copies_rule(merged, file.path("data", "copies", name))
  p2 <- finish(merged, paste0(name, "_xcopy_merged"))
  c(svc_csv, p1, p2)
}
