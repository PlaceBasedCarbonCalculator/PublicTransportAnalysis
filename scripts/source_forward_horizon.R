# How far forward each bus timetable source actually carries service.
#
# A TransXChange snapshot holds the registration operative on the day it was
# taken. TNDS is a current-data download, so a service whose registration
# lapses shortly after the snapshot simply stops: the feed has no forward
# horizon beyond what each operator happened to have filed. The BODS change
# archive holds every revision of every dataset, so in principle a successor
# revision is already in it and the service continues.
#
# That is the question this measures: not how many services each source has,
# but how long each source keeps running the services it has. It counts bus
# vehicle journeys operating on every date from two weeks before the snapshot
# to six months after, for all three sources, and keeps the per-service
# operating patterns so the last-operating-date comparison can be made.
#
# It reads only routes/trips/calendar/calendar_dates - never stop_times, which
# is 1.4 GB in the BODS archive - so it runs in a couple of minutes rather than
# the hour a full read of three national feeds costs.
#
# The feeds read are the UNTRIMMED conversion caches, not the feeds in gtfs/.
# convert_txc_cached() writes its cache before applying the +/- 45 day trim and
# convert_bods_txc() before its +/- 31 day trim, so the trimmed feeds would
# show the trim cliff edge rather than the source's own horizon, which is
# precisely what is being measured.
#
# Usage: Rscript scripts/source_forward_horizon.R

suppressMessages({library(data.table); library(lubridate)})
source("R/config.R")
source("R/comparison.R")

cfg <- load_cfg()
SNAP <- as.Date("2026-10-03")
FROM <- SNAP - 14
TO   <- SNAP + 183

read_tbl <- function(zip, name, cols = NULL) {
  con <- unz(zip, name)
  on.exit(try(close(con), silent = TRUE), add = TRUE)
  txt <- tryCatch(readLines(con, warn = FALSE), error = function(e) NULL)
  if (is.null(txt) || !length(txt)) return(NULL)
  fread(text = txt, select = cols, showProgress = FALSE,
        colClasses = "character")
}

# UK2GTFS writes YYYY-MM-DD; the DfT feed writes YYYYMMDD
as_date <- function(x) {
  x <- as.character(x)
  if (!length(x)) return(as.Date(character(0)))
  s <- x[!is.na(x)]
  if (length(s) && grepl("-", s[1])) as.Date(x) else
    as.Date(x, format = "%Y%m%d")
}

DOW <- c("monday", "tuesday", "wednesday", "thursday", "friday",
         "saturday", "sunday")

#' Bus trips per service plus that service operating pattern, for one feed
#'
#' Only services with at least one bus trip are kept, so the date expansion
#' stays small.
feed_service_table <- function(zip) {
  routes <- read_tbl(zip, "routes.txt", c("route_id", "route_type"))
  trips  <- read_tbl(zip, "trips.txt", c("trip_id", "route_id", "service_id"))
  cal    <- read_tbl(zip, "calendar.txt")
  cd     <- read_tbl(zip, "calendar_dates.txt",
                     c("service_id", "date", "exception_type"))
  if (is.null(routes) || is.null(trips)) return(NULL)

  routes[, rt := map_route_type_simple(route_type)]
  bus <- routes[rt == 3L, route_id]
  trips <- trips[route_id %in% bus]
  if (!nrow(trips)) return(NULL)
  n <- trips[, list(bus_trips = .N), by = service_id]

  if (is.null(cal)) {
    svc <- n[, list(service_id, bus_trips)]
    for (d in DOW) svc[, (d) := 0L]
    svc[, `:=`(start_date = as.Date(NA), end_date = as.Date(NA))]
  } else {
    svc <- cal[, c("service_id", DOW, "start_date", "end_date"), with = FALSE]
    for (d in DOW) svc[[d]] <- as.integer(svc[[d]])
    svc[, `:=`(start_date = as_date(start_date), end_date = as_date(end_date))]
    svc <- merge(svc, n, by = "service_id", all.y = TRUE)
    # A service defined only in calendar_dates has no calendar row: give it an
    # all-zero pattern so the exceptions supply its dates.
    for (d in DOW) svc[is.na(get(d)), (d) := 0L]
  }

  if (!is.null(cd)) {
    cd <- cd[service_id %in% svc$service_id]
    cd[, `:=`(date = as_date(date),
              exception_type = as.integer(exception_type))]
    cd <- cd[date >= FROM & date <= TO]
  } else {
    cd <- data.table(service_id = character(0), date = as.Date(character(0)),
                     exception_type = integer(0))
  }
  list(svc = svc, cd = cd)
}

#' Bus journeys operating on each date in [FROM, TO]
#'
#' GTFS semantics: the weekday flags apply inside [start_date, end_date], an
#' exception_type 2 removes a date the calendar operates and a type 1 adds one
#' it does not.
runs_by_date <- function(ft) {
  dates <- seq(FROM, TO, by = "day")
  dow <- as.integer(wday(dates, week_start = 1))
  svc <- ft$svc
  flags <- as.matrix(svc[, DOW, with = FALSE])

  base <- vapply(seq_along(dates), function(i) {
    ok <- !is.na(svc$start_date) & svc$start_date <= dates[i] &
      svc$end_date >= dates[i] & flags[, dow[i]] == 1L
    sum(svc$bus_trips[ok], na.rm = TRUE)
  }, numeric(1))

  add <- rem <- numeric(length(dates))
  if (nrow(ft$cd)) {
    cd <- unique(ft$cd, by = c("service_id", "date", "exception_type"))
    cd <- merge(cd, svc[, list(service_id, bus_trips, start_date, end_date)],
                by = "service_id")
    cd[, d := as.integer(wday(date, week_start = 1))]
    fl <- as.matrix(svc[match(cd$service_id, svc$service_id),
                        DOW, with = FALSE])
    cd[, operates := !is.na(start_date) & start_date <= date &
         end_date >= date & fl[cbind(seq_len(.N), d)] == 1L]
    a <- cd[exception_type == 1L & !operates, list(v = sum(bus_trips)),
            by = date]
    r <- cd[exception_type == 2L & operates, list(v = sum(bus_trips)),
            by = date]
    if (nrow(a)) add[match(a$date, dates)] <- a$v
    if (nrow(r)) rem[match(r$date, dates)] <- r$v
  }
  data.table(date = dates, runs = base + add - rem)
}

sources <- list(
  tnds = list.files(file.path(cfg$gtfs_dir, "cache", "tnds_20261002_v25"),
                    pattern = "[.]zip$", full.names = TRUE),
  bods_txc = file.path(cfg$gtfs_dir, "cache", "bods_txc_20261003_full.zip"),
  bods_gtfs = file.path(cfg$data_root,
                        "OpenBusData/GTFS/20261003/itm_all_gtfs.zip")
)

curves <- list(); svc_tables <- list()
for (nm in names(sources)) {
  zs <- sources[[nm]]
  message("\n=== ", nm, ": ", length(zs), " feed(s) ===")
  parts <- list()
  for (z in zs) {
    message("  reading ", basename(z))
    ft <- feed_service_table(z)
    if (is.null(ft)) { message("    no bus trips"); next }
    message("    ", nrow(ft$svc), " bus services, ",
            format(sum(ft$svc$bus_trips), big.mark = ","), " bus trips")
    parts[[z]] <- ft
  }
  curves[[nm]] <- rbindlist(lapply(parts, runs_by_date))[
    , list(runs = sum(runs)), by = date][order(date)]
  svc_tables[[nm]] <- rbindlist(lapply(names(parts), function(z) {
    s <- copy(parts[[z]]$svc)
    s[, feed := basename(z)][]
  }), fill = TRUE)
}

out <- list(snapshot = SNAP, from = FROM, to = TO,
            curves = rbindlist(curves, idcol = "source"),
            services = rbindlist(svc_tables, idcol = "source"))

dir.create(cfg$out_dir, showWarnings = FALSE, recursive = TRUE)
saveRDS(out, file.path(cfg$out_dir, "source_forward_horizon.Rds"))

cat("\n=== bus journeys operating, indexed to the first Monday of the window ===\n")
w <- dcast(out$curves, date ~ source, value.var = "runs")
base <- w[date == SNAP + 4]
for (s in names(curves)) {
  w[[paste0("i_", s)]] <- round(w[[s]] / base[[s]][1], 3)
}
print(w[date %in% (SNAP + c(4, 11, 18, 32, 60, 90, 120, 150, 180))])
cat("\nwrote", file.path(cfg$out_dir, "source_forward_horizon.Rds"), "\n")
