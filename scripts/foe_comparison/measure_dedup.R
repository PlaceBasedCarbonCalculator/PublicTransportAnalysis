# How much of the gap between the previous and rebuilt trips-per-zone outputs
# is deduplication rather than conversion?
#
# The previous pipeline counted a feed as gtfs_read() -> gtfs_clean() ->
# gtfs_trips_per_zone() (TransportBlackspots
# scripts/make-stats/trips_per_lsoa.R). This repo's read_feed() inserts
# UK2GTFS::gtfs_deduplicate() between the clean and the count. That function
# was added to UK2GTFS on 2026-08-01 (commit a1e2153), months after the
# previous outputs were built, so the previous numbers include every journey
# its sources described more than once.
#
# This re-counts a year with deduplication switched off, over exactly the same
# window and zones the pipeline uses, and puts the result beside the previous
# and rebuilt outputs. The no-dedup column is the like-for-like comparison
# with the previous pipeline, so:
#
#   previous vs rebuilt-no-dedup  = the conversion
#   rebuilt-no-dedup vs rebuilt   = deduplication
#
# Counting a national feed is slow, so this does one year at a time.
#
#   Rscript scripts/foe_comparison/measure_dedup.R 2006

source("scripts/foe_comparison/foe_functions.R")
for (f in list.files("R", full.names = TRUE)) source(f)

args <- commandArgs(trailingOnly = TRUE)
years <- if (length(args)) as.integer(args) else c(2006, 2023)

suppressMessages(sf::sf_use_s2(FALSE))
cfg <- cfg_cores(30)
zones <- readRDS(ensure_zones(cfg))
zones <- sf::st_transform(zones, 4326)

lookup <- build_zone_lookup()

#' Population-weighted mean daytime tph over a trips-per-zone table
weighted_daytime <- function(res) {
  res <- res[res$route_type %in% c(3, 200) & !is.na(res$zone_id), ]
  names(res) <- gsub(" ", "_", names(res))
  value_cols <- setdiff(names(res), c("zone_id", "route_type"))
  m <- as.matrix(res[, value_cols]); m[is.na(m)] <- 0
  agg <- rowsum(m, res$zone_id, reorder = TRUE)
  x <- data.frame(zone_id = rownames(agg), agg, check.names = FALSE,
                  row.names = NULL)
  x <- add_derived_periods(x)
  x <- merge(x, lookup[, c("zone_id", "population")], by = "zone_id")
  x <- x[!is.na(x$population), ]
  stats::weighted.mean(x$tph_daytime_avg, x$population)
}

out <- list()
for (y in years) {
  spec <- year_sources(cfg)[[as.character(y)]]
  feed <- spec$bus[[1]]
  win <- study_window(feed$ref)
  message("Year ", y, ": ", feed$path, " over ", win$startdate, " to ", win$enddate)

  gtfs <- read_feed(feed$path, cfg, deduplicate = FALSE)
  trips_before <- nrow(gtfs$trips)
  res_nodedup <- as.data.frame(
    UK2GTFS::gtfs_trips_per_zone(gtfs, zone = zones,
                                 startdate = win$startdate,
                                 enddate = win$enddate,
                                 ncores = cfg$ncores))

  gtfs <- UK2GTFS::gtfs_deduplicate(gtfs)
  trips_after <- nrow(gtfs$trips)
  rm(gtfs); gc()

  old <- readRDS(file.path(INPUT_DATA, "pt_frequency",
                           sprintf("trips_per_lsoa21_22_by_mode_%s.Rds", y)))
  new <- readRDS(sprintf("data/trips_per_lsoa21_22_by_mode_%s.Rds", y))

  out[[as.character(y)]] <- data.frame(
    year = y,
    feed = basename(feed$path),
    trips_in_feed = trips_before,
    trips_after_dedup = trips_after,
    trips_removed_pct = 1 - trips_after / trips_before,
    tph_previous = weighted_daytime(old),
    tph_rebuilt_nodedup = weighted_daytime(res_nodedup),
    tph_rebuilt = weighted_daytime(new))
  print(out[[as.character(y)]])
}

result <- do.call(rbind, out)
result$conversion_ratio <- result$tph_rebuilt_nodedup / result$tph_previous
result$dedup_ratio <- result$tph_rebuilt / result$tph_rebuilt_nodedup
result$total_ratio <- result$tph_rebuilt / result$tph_previous

path <- "data/dedup_effect.Rds"
prev <- if (file.exists(path)) readRDS(path) else NULL
result <- rbind(prev[!prev$year %in% result$year, , drop = FALSE], result)
saveRDS(result, path)
print(result)
message("Wrote ", path)
