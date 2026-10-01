# Measurements behind reports/source_disagreement_investigation.md
#
# Nothing here is wired into _targets.R and nothing here writes to gtfs/ or
# data/ except the one Rds at the end. Each function answers one question and
# can be run on its own; run_source_disagreement.R runs them all.
#
# These read the RAW TransXChange archives as well as the converted feeds,
# which is the point: the converted feeds cannot say whether a service is
# missing because it was never published or because conversion dropped it.

library(data.table)

# --- helpers ---------------------------------------------------------------

#' Read one table out of a GTFS zip without extracting the rest
#'
#' Everything as character: the arrival/departure columns are compared for
#' identity here, never arithmetic, and letting fread type them loses the
#' distinction between "08:05:00" and "8:05:00".
gtfs_table <- function(zip, file) {
  td <- tempfile(); dir.create(td)
  on.exit(unlink(td, recursive = TRUE), add = TRUE)
  ok <- try(utils::unzip(zip, files = file, exdir = td), silent = TRUE)
  if (inherits(ok, "try-error") || !file.exists(file.path(td, file))) return(NULL)
  data.table::fread(file.path(td, file), colClasses = "character")
}

#' The harmonised route types this repo uses, from a GTFS routes table
simple_route_type <- function(rt) {
  rt <- as.integer(rt)
  data.table::fcase(
    rt %in% 100:199, 2L, rt %in% 200:299, 200L, rt %in% 400:499, 1L,
    rt %in% 700:799, 3L, rt %in% 900:999, 0L, rt %in% c(1000L, 1200L), 4L,
    rt == 1400L, 0L, default = rt)
}

#' Header fields of one TransXChange file
#'
#' The same fields txc_filter_files() reads, plus the vehicle journey count,
#' which is what lets a dropped file be priced in service rather than in files.
txc_header <- function(f) {
  x <- try(xml2::read_xml(f), silent = TRUE)
  if (inherits(x, "try-error")) return(NULL)
  sv <- xml2::xml_find_first(x, "d1:Services/d1:Service")
  if (is.na(sv)) return(NULL)
  lns <- sort(unique(trimws(xml2::xml_text(
    xml2::xml_find_all(x, "//d1:LineName")))))
  rev <- xml2::xml_attr(sv, "RevisionNumber")
  if (is.na(rev)) rev <- xml2::xml_attr(x, "RevisionNumber")
  data.table::data.table(
    file = f, base = basename(f),
    NOC = xml2::xml_text(xml2::xml_find_first(x, "//d1:NationalOperatorCode")),
    ServiceCode = xml2::xml_text(xml2::xml_find_first(sv, "d1:ServiceCode")),
    Lines = paste(lns, collapse = "\r"),
    Start = xml2::xml_text(xml2::xml_find_first(sv, "d1:OperatingPeriod/d1:StartDate")),
    End = xml2::xml_text(xml2::xml_find_first(sv, "d1:OperatingPeriod/d1:EndDate")),
    Rev = suppressWarnings(as.numeric(rev)),
    nVJ = length(xml2::xml_find_all(x, "//d1:VehicleJourney")))
}

#' Every TransXChange header in one regional archive
txc_region_headers <- function(zip, workers = 1) {
  ex <- file.path(tempdir(), paste0("txc_", basename(zip)))
  dir.create(ex, showWarnings = FALSE, recursive = TRUE)
  on.exit(unlink(ex, recursive = TRUE), add = TRUE)
  utils::unzip(zip, exdir = ex)
  fs <- list.files(ex, pattern = "[.]xml$", full.names = TRUE, recursive = TRUE)
  if (workers > 1) {
    oldplan <- future::plan(future::multisession, workers = workers)
    on.exit(future::plan(oldplan), add = TRUE)
    out <- furrr::future_map(fs, txc_header)
  } else {
    out <- lapply(fs, txc_header)
  }
  data.table::rbindlist(Filter(Negate(is.null), out))
}

# --- 1. duplicates that survive gtfs_deduplicate() -------------------------

#' How much duplication a looser journey signature would remove
#'
#' gtfs_deduplicate() keys a journey on (stop_id, arrival_time,
#' departure_time, pickup_type, drop_off_type) at every call, so two
#' publications of one journey that differ only in the layover recorded at a
#' terminus never group. This prices that, against two looser signatures.
#'
#' Only copies that share a `service_id` are counted, so the package's
#' date-redundancy test is satisfied by construction and nothing is counted
#' that could leave a date with less service. That makes this a lower bound,
#' and deliberately so.
signature_sensitivity <- function(zip) {
  r <- gtfs_table(zip, "routes.txt"); tp <- gtfs_table(zip, "trips.txt")
  st <- gtfs_table(zip, "stop_times.txt"); ag <- gtfs_table(zip, "agency.txt")
  if (is.null(r) || is.null(tp) || is.null(st)) return(NULL)

  if (!"route_short_name" %in% names(r)) r[, route_short_name := ""]
  r[, rsn := fifelse(is.na(route_short_name) | route_short_name == "",
                     paste0("\rrid\r", route_id), route_short_name)]
  if (!is.null(ag) && "agency_id" %in% names(r)) {
    r <- merge(r, ag[, .(agency_id, agency_name)], by = "agency_id", all.x = TRUE)
    r[, akey := fifelse(is.na(agency_name), agency_id, agency_name)]
  } else {
    r[, akey := ""]
  }
  r[, rkey := paste(akey, route_type, rsn, sep = "\r")]
  tp <- merge(tp, r[, .(route_id, rkey)], by = "route_id", all.x = TRUE)

  # match_block = FALSE is the package default, so block_id is NOT a key
  for (nm in c("direction_id", "wheelchair_accessible", "bikes_allowed")) {
    if (!nm %in% names(tp)) tp[, (nm) := ""]
    tp[is.na(get(nm)), (nm) := ""]
  }
  tp[, tkey := paste(direction_id, wheelchair_accessible, bikes_allowed, sep = "\r")]

  for (nm in c("arrival_time", "departure_time", "pickup_type", "drop_off_type")) {
    if (!nm %in% names(st)) st[, (nm) := ""]
    st[is.na(get(nm)), (nm) := ""]
  }
  st[, seq := as.integer(stop_sequence)]
  data.table::setorder(st, trip_id, seq)

  mk <- function(cols, nm) {
    st[, g := .GRP, by = cols]
    s <- st[, .(sig = paste(g, collapse = ",")), by = trip_id]
    data.table::setnames(s, "sig", nm); s
  }
  sA <- mk(c("stop_id","arrival_time","departure_time","pickup_type","drop_off_type"), "sigA")
  sB <- mk(c("stop_id","departure_time","pickup_type","drop_off_type"), "sigB")
  st[, first := seq == min(seq), by = trip_id]
  st[, kc := fifelse(first, paste0(stop_id, "|FIRST"),
                     paste(stop_id, departure_time, pickup_type,
                           drop_off_type, sep = "|"))]
  sC <- st[, .(sigC = paste(kc, collapse = ",")), by = trip_id]

  x <- Reduce(function(a, b) merge(a, b, by = "trip_id"), list(sA, sB, sC))
  x <- merge(x, tp[, .(trip_id, service_id, rkey, tkey)], by = "trip_id")
  data.table::rbindlist(lapply(c("sigA", "sigB", "sigC"), function(s) {
    g <- x[, .N, by = c("rkey", "tkey", "service_id", s)]
    data.table::data.table(signature = s, trips = nrow(tp),
                           removable = sum(g$N - 1L),
                           pct = round(100 * sum(g$N - 1L) / nrow(tp), 3))
  }))
}

# --- 2. how long a snapshot stays valid ------------------------------------

#' Bus trips live on each Wednesday of a counting window
#'
#' Wednesdays only, so that a feed losing service across its own window cannot
#' be confused with the ordinary weekday/weekend pattern.
wednesday_profile <- function(zip, win_start, win_end) {
  r <- gtfs_table(zip, "routes.txt"); tp <- gtfs_table(zip, "trips.txt")
  cal <- gtfs_table(zip, "calendar.txt"); cd <- gtfs_table(zip, "calendar_dates.txt")
  if (is.null(r) || is.null(tp) || is.null(cal)) return(NULL)
  r[, rts := simple_route_type(route_type)]
  tp <- tp[route_id %in% r[rts == 3L, route_id], .(trip_id, service_id)]
  n_by_svc <- tp[, .N, by = service_id]
  cal <- copy(cal)
  cal[, `:=`(sd = as.Date(start_date, "%Y%m%d"), ed = as.Date(end_date, "%Y%m%d"))]
  weds <- seq(as.Date(win_start), as.Date(win_end), by = 1)
  weds <- weds[format(weds, "%u") == "3"]
  data.table::rbindlist(lapply(weds, function(d) {
    s <- cal[!is.na(sd) & sd <= d & ed >= d & wednesday == "1", service_id]
    if (!is.null(cd) && nrow(cd)) {
      d2 <- copy(cd); d2[, dd := as.Date(date, "%Y%m%d")]
      s <- setdiff(s, d2[dd == d & exception_type == "2", service_id])
      s <- union(s, d2[dd == d & exception_type == "1", service_id])
    }
    data.table::data.table(date = d,
                           trips = sum(n_by_svc$N[n_by_svc$service_id %in% s]))
  }))
}

# --- 3. what the file filter costs -----------------------------------------

#' Simulate txc_filter_files() rules 1-3 under a chosen key
#'
#' `keycols` is "ServiceCode" to reproduce the package, or
#' c("NOC", "ServiceCode") to key on the operator as well. Rule 4, the overlap
#' resolution, is not simulated: it already groups on NationalOperatorCode and
#' is unaffected by the collision this measures.
simulate_filter <- function(meta, keycols, date) {
  d <- data.table::copy(meta)
  d[is.na(Rev), Rev := -1]
  d[, sd := as.Date(Start)]
  d[is.na(sd), sd := as.Date("1900-01-01")]
  d[, row := .I]
  d[, k := do.call(paste, c(.SD, sep = "\r")), .SDcols = keycols]
  # rule 1: per key + start date + line, keep the highest revision
  ll <- strsplit(d$Lines, "\r", fixed = TRUE)
  ll[lengths(ll) == 0] <- ""
  idx <- rep(seq_len(nrow(d)), lengths(ll))
  ex <- data.table::data.table(row = d$row[idx], k = d$k[idx], sd = d$sd[idx],
                               Line = unlist(ll), Rev = d$Rev[idx])
  data.table::setorder(ex, k, sd, Line, -Rev)
  best <- ex[!duplicated(ex[, .(k, sd, Line)])]
  d <- d[row %in% best$row]
  # rules 2 and 3: the version operative on `date`, plus all future versions
  d[, maxpast := {
    p <- sd[sd <= date]
    if (length(p)) max(p) else as.Date(NA)
  }, by = k]
  d[(sd <= date & !is.na(maxpast) & sd == maxpast) | sd > date]
}

#' What the ServiceCode collision costs one region
collision_cost <- function(meta, date) {
  a <- simulate_filter(meta, "ServiceCode", date)
  b <- simulate_filter(meta, c("NOC", "ServiceCode"), date)
  data.table::data.table(
    files = nrow(meta), journeys = sum(meta$nVJ),
    vj_current = sum(a$nVJ), vj_keyed_on_operator = sum(b$nVJ),
    lost = sum(b$nVJ) - sum(a$nVJ),
    lost_pct = round(100 * (sum(b$nVJ) - sum(a$nVJ)) / sum(meta$nVJ), 2))
}

# --- 4. one route, one stop, one day ---------------------------------------

#' Calls at one stop on one route, per day, from a feed read once
#'
#' The Birmingham route 74 test: if a feed carries two overlapping
#' registrations of one line, the doubling appears only on the days both
#' calendars are live, which is what distinguishes it from real service.
route_stop_profile <- function(zip, route_short, stop_id, days) {
  r <- gtfs_table(zip, "routes.txt"); tp <- gtfs_table(zip, "trips.txt")
  cal <- gtfs_table(zip, "calendar.txt"); cd <- gtfs_table(zip, "calendar_dates.txt")
  st <- gtfs_table(zip, "stop_times.txt")
  ids <- r[route_short_name == route_short, route_id]
  trips <- tp[route_id %in% ids, .(trip_id, service_id)]
  calls <- st[stop_id == ..stop_id & trip_id %in% trips$trip_id, .N, by = trip_id]
  calls <- merge(calls, trips, by = "trip_id")
  per_svc <- calls[, .(calls = sum(N)), by = service_id]
  rm(st); gc()
  cal <- copy(cal)
  cal[, `:=`(sd = as.Date(start_date, "%Y%m%d"), ed = as.Date(end_date, "%Y%m%d"))]
  dows <- c("monday","tuesday","wednesday","thursday","friday","saturday","sunday")
  data.table::rbindlist(lapply(as.Date(days), function(d) {
    col <- dows[as.integer(format(d, "%u"))]
    s <- cal[!is.na(sd) & sd <= d & ed >= d & get(col) == "1", service_id]
    if (!is.null(cd) && nrow(cd)) {
      d2 <- copy(cd); d2[, dd := as.Date(date, "%Y%m%d")]
      s <- setdiff(s, d2[dd == d & exception_type == "2", service_id])
      s <- union(s, d2[dd == d & exception_type == "1", service_id])
    }
    data.table::data.table(date = d, dow = format(d, "%a"),
                           calls = sum(per_svc$calls[per_svc$service_id %in% s]))
  }))
}

# --- 4. the ServiceCode collision fix, verified ----------------------------

#' A/B the real `txc_filter_files()` before and after the operator key
#'
#' Runs the committed version and the working-tree version of
#' `UK2GTFS::txc_filter_files()` over one TNDS regional archive and compares
#' the files each keeps. The committed version is sourced into an environment
#' whose parent is the package namespace, so it can see the package internals
#' it calls without the package being rebuilt.
#'
#' `resolve_overlaps = FALSE` isolates rules 1 to 3, which is what the key
#' change affects, and keeps the kept-file paths comparable as sets; rule 4
#' rewrites truncated files under new names, so it is reported only as a count.
#'
#' The assertion that matters is `newly_dropped == 0`. A finer key can only
#' split a group, and each sub-group then keeps its own operative version, so
#' nothing the old key kept should ever disappear. If it does, the key is
#' wrong rather than finer.
filter_ab <- function(zip, pkg, date, workers = 1) {
  ex <- file.path(tempdir(), paste0("ab_", basename(zip)))
  dir.create(ex, showWarnings = FALSE, recursive = TRUE)
  on.exit(unlink(ex, recursive = TRUE), add = TRUE)
  utils::unzip(zip, exdir = ex)
  fs <- list.files(ex, pattern = "[.]xml$", full.names = TRUE, recursive = TRUE)

  oldsrc <- file.path(tempdir(), "txc_filter_files_HEAD.R")
  system2("git", c("-C", shQuote(pkg), "show", "HEAD:R/txc_filter_files.R"),
          stdout = oldsrc)
  oldenv <- new.env(parent = asNamespace("UK2GTFS"))
  sys.source(oldsrc, envir = oldenv)
  old_filter <- get("txc_filter_files", envir = oldenv)

  ko <- old_filter(fs, date = date, ncores = workers, resolve_overlaps = FALSE)
  kn <- UK2GTFS::txc_filter_files(fs, date = date, ncores = workers,
                                  resolve_overlaps = FALSE)
  add <- setdiff(kn, ko); lost <- setdiff(ko, kn)
  nvj <- function(x) {
    if (!length(x)) return(0L)
    sum(vapply(x, function(f) {
      length(xml2::xml_find_all(xml2::read_xml(f), "//d1:VehicleJourney"))
    }, integer(1)), na.rm = TRUE)
  }
  data.table::data.table(
    region = sub("[.]zip$", "", basename(zip)), files = length(fs),
    keep_old = length(ko), keep_new = length(kn),
    newly_kept = length(add), newly_dropped = length(lost),
    vj_gained = nvj(add), vj_lost = nvj(lost),
    keep_old_r4 = length(old_filter(fs, date = date, resolve_overlaps = TRUE)),
    keep_new_r4 = length(UK2GTFS::txc_filter_files(fs, date = date,
                                                   resolve_overlaps = TRUE)))
}

#' Are a ServiceCode's operator sets disjoint, or overlapping but unequal?
#'
#' The question that decides whether the operator key is safe. Disjoint sets
#' under one code are unrelated operators colliding, which is the bug. Sets
#' that overlap without being equal would be one registration whose operator
#' list changed, which the key would split wrongly - so this counts them. On
#' the 2026-07-26 archive: 136 groups all-disjoint, **none** overlapping, and
#' only 6 files in the whole country name more than one operator.
operator_set_classes <- function(headers) {
  d <- data.table::as.data.table(headers)
  g <- d[, .(nsets = data.table::uniqueN(NOCset), nfiles = .N,
             nVJ = sum(nVJ)), by = .(region, ServiceCode)][nsets > 1]
  if (!nrow(g)) return(g)
  d[g, on = .(region, ServiceCode)][, {
    ss <- unique(NOCset[nzchar(NOCset)])
    l <- strsplit(ss, "\r", fixed = TRUE)
    kinds <- if (length(l) < 2) character() else apply(
      utils::combn(length(l), 2), 2, function(ij) {
        a <- l[[ij[1]]]; b <- l[[ij[2]]]
        if (!length(intersect(a, b))) "disjoint"
        else if (setequal(a, b)) "equal" else "overlapping"
      })
    .(disjoint = sum(kinds == "disjoint"),
      overlapping = sum(kinds == "overlapping"), nVJ = sum(nVJ))
  }, by = .(region, ServiceCode)]
}
