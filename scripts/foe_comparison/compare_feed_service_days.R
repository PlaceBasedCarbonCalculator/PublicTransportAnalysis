# Separate what the feeds say from what the counting code does.
#
# The gap between the previous and rebuilt trips-per-zone outputs could come
# from three places: the conversion (the feeds describe different service), the
# counting code (UK2GTFS changed between the two runs), or deduplication (a
# stage the previous pipeline did not have at all).
#
# This isolates the first. It takes the previous pipeline's converted feed and
# this pipeline's, and applies one identical piece of arithmetic to both:
# how many scheduled departures does each feed describe inside the 28-day
# window? That is the quantity `runs_*` aggregates over zones, so the ratio
# here is the conversion's contribution on its own, with no counting code and
# no spatial join involved.
#
# GTFS semantics are applied as the current UK2GTFS does: a base weekly
# calendar, plus exception_type 1 adding a date the calendar does not run and
# exception_type 2 removing one it does.
#
#   Rscript scripts/foe_comparison/compare_feed_service_days.R

suppressPackageStartupMessages({library(data.table); library(dplyr)})
source("scripts/foe_comparison/foe_functions.R")
for (f in list.files("R", full.names = TRUE)) source(f)

OLD_ROOT <- Sys.getenv("UK2GTFS_DATA",
                       "D:/OneDrive - University of Leeds/Data/UK2GTFS")

# The previous pipeline counted feeds it had converted earlier and kept on the
# data drive: the NPTDR years in June-July 2023, the TransXChange years in
# November 2023. Both are compared against this pipeline's 2026 reconversions.
ALL_PAIRS <- list(
  `2006` = list(year = 2006, old = "NPTDR/GTFS/NPTDR_2006.zip",
                new = "gtfs/nptdr_2006.zip", ref = "2006-10-01"),
  `2008` = list(year = 2008, old = "NPTDR/GTFS/NPTDR_2008.zip",
                new = "gtfs/nptdr_2008.zip", ref = "2008-10-01"),
  `2010` = list(year = 2010, old = "NPTDR/GTFS/NPTDR_2010.zip",
                new = "gtfs/nptdr_2010.zip", ref = "2010-10-01"),
  `2018` = list(year = 2018, old = "TransXChange/GTFS/20180515_merged.zip",
                new = "gtfs/tnds_20180515_merged.zip", ref = "2018-05-15"),
  `2023` = list(year = 2023, old = "TransXChange/GTFS/20231101_merged.zip",
                new = "gtfs/tnds_20231101_merged.zip", ref = "2023-11-01"))

args <- commandArgs(trailingOnly = TRUE)
PAIRS <- if (length(args)) ALL_PAIRS[args] else ALL_PAIRS

extract <- function(path, files) {
  fls <- utils::unzip(path, list = TRUE)$Name
  tmp <- tempfile(); dir.create(tmp)
  utils::unzip(path, files = fls[basename(fls) %in% files], exdir = tmp,
               junkpaths = TRUE)
  tmp
}

#' Scheduled departures a feed describes inside [start, end]
departures_in_window <- function(path, start, end) {
  tmp <- extract(path, c("calendar.txt", "calendar_dates.txt", "trips.txt",
                         "stop_times.txt", "routes.txt"))
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)

  rd <- function(f, ...) {
    p <- file.path(tmp, f)
    if (!file.exists(p)) return(NULL)
    fread(p, showProgress = FALSE, ...)
  }

  routes <- rd("routes.txt", select = c("route_id", "route_type"),
               colClasses = list(character = "route_id"))
  trips <- rd("trips.txt", select = c("trip_id", "route_id", "service_id"),
              colClasses = "character")
  cal <- rd("calendar.txt", colClasses = list(character = "service_id"))
  cd <- rd("calendar_dates.txt", colClasses = list(character = "service_id"))
  st <- rd("stop_times.txt", select = "trip_id", colClasses = "character")

  # Bus and coach only, matching the report
  routes[, route_type := as.integer(route_type)]
  bus_routes <- routes[route_type %in% c(3, 200), route_id]
  trips <- trips[route_id %in% bus_routes]

  # Departures per trip
  calls <- st[, .(calls = .N), by = trip_id]
  trips <- merge(trips, calls, by = "trip_id", all.x = TRUE)
  trips[is.na(calls), calls := 0L]

  dates <- seq(as.Date(start), as.Date(end), by = "day")
  dow <- tolower(weekdays(dates))

  # Operating days per service from the base calendar
  days <- data.table(date = dates, dow = dow)
  cal[, `:=`(start_date = as.Date(as.character(start_date), "%Y%m%d"),
             end_date = as.Date(as.character(end_date), "%Y%m%d"))]
  cal_long <- melt(cal, id.vars = c("service_id", "start_date", "end_date"),
                   measure.vars = c("monday", "tuesday", "wednesday", "thursday",
                                    "friday", "saturday", "sunday"),
                   variable.name = "dow", value.name = "runs")
  cal_long[, dow := as.character(dow)]
  cal_long <- cal_long[runs == 1]
  base <- merge(cal_long, days, by = "dow", allow.cartesian = TRUE)
  base <- base[date >= start_date & date <= end_date, .(service_id, date)]
  base[, base := TRUE]

  if (!is.null(cd) && nrow(cd)) {
    cd[, date := as.Date(as.character(date), "%Y%m%d")]
    cd <- cd[date >= as.Date(start) & date <= as.Date(end)]
    cd[, exception_type := as.integer(exception_type)]
    cd <- unique(cd[, .(service_id, date, exception_type)])
    svc <- merge(base, cd, by = c("service_id", "date"), all = TRUE)
  } else {
    svc <- copy(base); svc[, exception_type := NA_integer_]
  }
  svc[is.na(base), base := FALSE]
  # exception 1 adds a date the calendar does not run; 2 removes one it does
  svc[, operates := (base & (is.na(exception_type) | exception_type != 2)) |
        (!base & !is.na(exception_type) & exception_type == 1)]
  svc <- svc[operates == TRUE, .(days = .N), by = service_id]

  trips <- merge(trips, svc, by = "service_id", all.x = TRUE)
  trips[is.na(days), days := 0L]

  list(trips = nrow(trips),
       trip_days = sum(as.numeric(trips$days)),
       departures = sum(as.numeric(trips$days) * as.numeric(trips$calls)))
}

out <- lapply(PAIRS, function(p) {
  win <- study_window(p$ref)
  message("\n=== ", p$year, " window ", win$startdate, " to ", win$enddate, " ===")
  old_path <- file.path(OLD_ROOT, p$old)
  if (!file.exists(old_path)) { message("missing ", old_path); return(NULL) }
  a <- departures_in_window(old_path, win$startdate, win$enddate)
  message("previous: ", a$trips, " trips, ", format(a$departures, big.mark = ","),
          " departures")
  b <- departures_in_window(p$new, win$startdate, win$enddate)
  message("rebuilt:  ", b$trips, " trips, ", format(b$departures, big.mark = ","),
          " departures")
  data.frame(year = p$year,
             trips_prev = a$trips, trips_reb = b$trips,
             trip_days_prev = a$trip_days, trip_days_reb = b$trip_days,
             departures_prev = a$departures, departures_reb = b$departures,
             trip_day_ratio = b$trip_days / a$trip_days,
             departure_ratio = b$departures / a$departures)
})

result <- bind_rows(out)
path <- "data/feed_service_days.Rds"
prev <- if (file.exists(path)) readRDS(path) else NULL
result <- rbind(prev[!prev$year %in% result$year, , drop = FALSE], result)
result <- result[order(result$year), ]
saveRDS(result, path)
print(result)
message("Wrote ", path)
