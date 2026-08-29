# Deduplication removal rate, per feed.
#
# This repo's read_feed() runs UK2GTFS::gtfs_deduplicate() between cleaning and
# counting. The previous pipeline had no such stage - the function was only
# added to UK2GTFS on 2026-08-01 (commit a1e2153), and TransportBlackspots
# scripts/make-stats/trips_per_lsoa.R goes straight from gtfs_clean() to
# gtfs_trips_per_zone().
#
# Everything else has been ruled out as the main cause of the gap in the
# pre-2018 years: the two conversions of the same NPTDR archive describe the
# same service to within half a percent
# (scripts/foe_comparison/compare_feed_service_days.R), and the counting-code
# changes since the previous run all push counts up rather than down. This
# measures what is left.
#
#   Rscript scripts/foe_comparison/dedup_rate.R

source("scripts/foe_comparison/foe_functions.R")

DEFAULT_FEEDS <- c("nptdr_2006.zip", "nptdr_2008.zip", "nptdr_2010.zip",
                   "busarchive_2016_merged.zip", "tnds_20231101_merged.zip")

# One feed per run keeps peak memory down when the pipeline is busy elsewhere;
# results accumulate into the same file.
args <- commandArgs(trailingOnly = TRUE)
FEEDS <- if (length(args)) args else DEFAULT_FEEDS

BUS <- c(3, 200)

rate <- function(file) {
  path <- file.path("gtfs", file)
  if (!file.exists(path)) { message("missing ", path); return(NULL) }
  message("\n=== ", file, " ===")

  gtfs <- UK2GTFS::gtfs_read(path)
  gtfs$shapes <- NULL
  gtfs$stops <- gtfs$stops[!is.na(gtfs$stops$stop_lon), ]
  gtfs <- UK2GTFS::gtfs_clean(gtfs)

  bus_trips <- function(g) {
    rt <- g$routes$route_id[g$routes$route_type %in% BUS]
    g$trips$trip_id[g$trips$route_id %in% rt]
  }
  before <- bus_trips(gtfs)
  calls_before <- sum(gtfs$stop_times$trip_id %in% before)

  gtfs <- UK2GTFS::gtfs_deduplicate(gtfs)

  after <- bus_trips(gtfs)
  calls_after <- sum(gtfs$stop_times$trip_id %in% after)
  rm(gtfs); gc()

  out <- data.frame(
    feed = file,
    trips_before = length(before), trips_after = length(after),
    trips_removed_pct = 1 - length(after) / length(before),
    calls_before = calls_before, calls_after = calls_after,
    calls_removed_pct = 1 - calls_after / calls_before)
  print(out)
  out
}

result <- dplyr::bind_rows(lapply(FEEDS, function(f) {
  r <- try(rate(f), silent = TRUE)
  if (inherits(r, "try-error")) {
    message("  failed: ", conditionMessage(attr(r, "condition"))); NULL
  } else r
}))

path <- "data/dedup_rate.Rds"
prev <- if (file.exists(path)) readRDS(path) else NULL
result <- rbind(prev[!prev$feed %in% result$feed, , drop = FALSE], result)
saveRDS(result, path)
print(result)
message("Wrote ", path)
