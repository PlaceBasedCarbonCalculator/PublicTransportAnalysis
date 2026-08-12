# Compare the calendar_dates tables of the previous pipeline's converted feeds
# with this pipeline's.
#
# Until UK2GTFS commit 8264968 (2026-07-11), gtfs_merge() condensed service
# patterns with
#
#     calendar_dates <- calendar_dates[!duplicated(calendar_dates$service_id), ]
#
# which keeps the first exception row for a service and discards every other
# one. NPTDR years are merged from hundreds of ATCO-CIF files, and their
# exceptions are overwhelmingly cancellations (exception_type 2) for school
# holidays and bank holidays, so dropping them leaves services running on days
# they do not run - counted service that never happened.
#
# The previous pipeline's NPTDR feeds were converted in June-July 2023 and so
# carry the bug; this pipeline's were reconverted in 2026 and do not. Reading
# both tells us how much cancellation was being lost, without reconverting
# anything.
#
#   Rscript scripts/foe_comparison/compare_feed_calendars.R

suppressPackageStartupMessages(library(dplyr))

OLD_ROOT <- Sys.getenv("UK2GTFS_DATA",
                       "D:/OneDrive - University of Leeds/Data/UK2GTFS")

PAIRS <- list(
  list(year = 2006, old = "NPTDR/GTFS/NPTDR_2006.zip", new = "gtfs/nptdr_2006.zip"),
  list(year = 2008, old = "NPTDR/GTFS/NPTDR_2008.zip", new = "gtfs/nptdr_2008.zip"),
  list(year = 2010, old = "NPTDR/GTFS/NPTDR_2010.zip", new = "gtfs/nptdr_2010.zip"))

#' Read just calendar_dates and calendar from a GTFS zip
read_cal <- function(path) {
  fls <- utils::unzip(path, list = TRUE)$Name
  tmp <- tempfile(); dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  want <- intersect(c("calendar_dates.txt", "calendar.txt", "trips.txt"), basename(fls))
  utils::unzip(path, files = fls[basename(fls) %in% want], exdir = tmp, junkpaths = TRUE)
  rd <- function(f) {
    p <- file.path(tmp, f)
    if (!file.exists(p)) return(NULL)
    data.table::fread(p, colClasses = "character", showProgress = FALSE)
  }
  list(calendar_dates = rd("calendar_dates.txt"),
       calendar = rd("calendar.txt"),
       trips = rd("trips.txt"))
}

summarise_feed <- function(path, label) {
  if (!file.exists(path)) {
    message("missing: ", path); return(NULL)
  }
  message("Reading ", label, ": ", path)
  x <- read_cal(path)
  cd <- x$calendar_dates
  n_services <- if (!is.null(x$calendar)) length(unique(x$calendar$service_id)) else NA_integer_
  data.frame(
    which = label,
    services = n_services,
    trips = if (!is.null(x$trips)) nrow(x$trips) else NA_integer_,
    exception_rows = if (is.null(cd)) 0L else nrow(cd),
    services_with_exceptions = if (is.null(cd)) 0L else length(unique(cd$service_id)),
    cancellations = if (is.null(cd)) 0L else sum(cd$exception_type == "2"),
    additions = if (is.null(cd)) 0L else sum(cd$exception_type == "1"),
    rows_per_service_with_exceptions =
      if (is.null(cd)) NA_real_ else nrow(cd) / length(unique(cd$service_id)))
}

out <- lapply(PAIRS, function(p) {
  a <- summarise_feed(file.path(OLD_ROOT, p$old), "previous (converted 2023)")
  b <- summarise_feed(file.path("gtfs", basename(p$new)), "rebuilt (converted 2026)")
  res <- bind_rows(a, b)
  if (!nrow(res)) return(NULL)
  res$year <- p$year
  print(res)
  res
})

result <- bind_rows(out)
saveRDS(result, "data/feed_calendar_comparison.Rds")
print(result)
message("Wrote data/feed_calendar_comparison.Rds")
