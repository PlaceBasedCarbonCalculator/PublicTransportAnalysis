# Measure the London Underground duplicate-copy defect and save everything
# reports/metro_duplicate_copies.md quotes.
#
# Run from the repo root:
#   Rscript scripts/metro_duplicates/run_metro_duplicates.R
#
# Standalone by design - not a targets pipeline stage, and it writes only
# data/metro_duplicates.Rds. Takes roughly fifteen minutes, almost all of it
# extracting and reading stop_times out of the eight merged TNDS feeds.

source("scripts/metro_duplicates/metro_duplicates.R")

OUT <- "data/metro_duplicates.Rds"
SPIKE_FEED <- "gtfs/tnds_20211012_merged.zip"   # the worked example, 2021
# The two Central line copies that share a calendar in October 2021. Route
# 1657 is the superseded 9-14 October timetable and is legitimate.
SPIKE_ROUTES <- c(1656, 1659)

years <- metro_feed_years()
res <- list(years = years)

# ---- what the published outputs say -------------------------------------
message("Published figures for ", LEYTONSTONE_LSOA)
res$published <- rbindlist(lapply(c(2004:2011, 2014:2025), published_zone_tph),
                           fill = TRUE)

# ---- the per-route decomposition that reproduces them --------------------
# One row per year per weekday: how many Central line departures land in the
# afternoon peak at Leytonstone, and which routes supply them. Two or more
# routes on a line is the defect.
message("Station profiles")
res$station <- rbindlist(lapply(seq_len(nrow(years)), function(i) {
  message("  ", years$year[i])
  p <- station_profile(years$feed[i], years$ref[i])
  p[, year := years$year[i]][]
}))

# ---- the route copies behind them ---------------------------------------
message("Underground route copies")
res$copies <- rbindlist(lapply(seq_len(nrow(years)), function(i) {
  route_copies(years$feed[i], years$ref[i],
               route_type = 1L, agency_id = "LUL")[, year := years$year[i]][]
}))

# ---- why deduplication cannot see them, part one -------------------------
# A blank route_short_name exempts a route from gtfs_deduplicate(), and
# UK2GTFS blanks any TransXChange LineName over six characters.
message("Blank route_short_name by mode")
res$blank_names <- rbindlist(lapply(seq_len(nrow(years)), function(i) {
  blank_short_name_by_mode(years$feed[i])[, year := years$year[i]][]
}))

# ---- why deduplication cannot see them, part two -------------------------
# Even with the names restored, the copies are not byte-identical.
message("Signature overlap for the 2021 Central line copies")
res$signatures <- signature_overlap(SPIKE_FEED, SPIKE_ROUTES[1], SPIKE_ROUTES[2])

# ---- how far it reaches --------------------------------------------------
message("Phantom trip-days by mode")
res$phantom_mode <- rbindlist(lapply(seq_len(nrow(years)), function(i) {
  phantom_trip_days(years$feed[i], years$ref[i],
                    by = "route_type")[, year := years$year[i]][]
}))

message("Phantom trip-days by Underground line")
res$phantom_line <- rbindlist(lapply(seq_len(nrow(years)), function(i) {
  phantom_trip_days(years$feed[i], years$ref[i], route_types = 1L,
                    agency_id = "LUL", by = "line")[, year := years$year[i]][]
}))

# ---- what a fix would do -------------------------------------------------
# The candidate rule for fixed-track modes, and its effect on the figure that
# started this. 2024 is the control: no Central line duplication that year.
message("Candidate rule")
res$fix <- rbindlist(lapply(seq_len(nrow(years)), function(i) {
  message("  ", years$year[i])
  drop <- fixed_track_duplicates(years$feed[i], years$ref[i],
                                 route_types = 1L, agency_id = "LUL")
  # neither call clears the extracted stop_times, so the second reuses it;
  # "before" is taken from res$station rather than measured twice
  after <- station_profile_excluding(years$feed[i], years$ref[i], drop)
  clear_gtfs_scratch(years$feed[i])
  before <- res$station[year == years$year[i]]
  data.table(year = years$year[i], removed = length(drop),
             dow = after$dow,
             tph_before = before$tph[match(after$dow, before$dow)],
             tph_after = after$tph)
}))
res$fix_totals <- res$copies[, list(lu_trips = sum(trips)), by = "year"]
res$fix <- merge(res$fix, res$fix_totals, by = "year")
res$fix[, pct_removed := round(100 * removed / lu_trips, 1)]

# ---- the second defect: metro counted from two feeds ---------------------
message("Underground in the rail CIF feeds")
res$rail_metro <- lapply(seq_len(nrow(years)), function(i) {
  if (is.na(years$rail_feed[i])) return(NULL)
  f <- resolve_feed_path(years$rail_feed[i])
  if (!file.exists(f)) return(NULL)
  o <- atoc_metro_overlap(f)
  o$by_agency[, year := years$year[i]]
  o$stops[, year := years$year[i]]
  o
})
names(res$rail_metro) <- years$year
res$rail_metro_by_agency <- rbindlist(
  lapply(res$rail_metro, function(x) if (is.null(x)) NULL else x$by_agency))

saveRDS(res, OUT)
message("Written ", OUT)

# ---- print everything the report quotes ----------------------------------
cat("\n=== Published metro tph, ", LEYTONSTONE_LSOA, " ===\n", sep = "")
print(res$published, row.names = FALSE)

cat("\n=== Central line afternoon-peak departures at Leytonstone ===\n")
print(res$station[, list(year, dow, departures, tph, routes)], row.names = FALSE)

cat("\n=== Blank route_short_name by mode ===\n")
print(dcast(res$blank_names, route_type ~ year, value.var = "pct_trips_blank"))

cat("\n=== 2021 Central line copies: shared journey signatures ===\n")
print(res$signatures, row.names = FALSE)

cat("\n=== Phantom trip-days by mode (% of trip-days) ===\n")
print(dcast(res$phantom_mode, route_type ~ year, value.var = "pct"))

cat("\n=== Phantom trip-days, London Underground ===\n")
print(res$phantom_mode[route_type == 1L,
                       list(year, trip_days, phantom, pct,
                            lines_affected, lines)], row.names = FALSE)

cat("\n=== Phantom trip-days by Underground line (% of trip-days) ===\n")
print(dcast(res$phantom_line, line ~ year, value.var = "pct"), nrow = 40)

cat("\n=== Candidate rule: effect at Leytonstone ===\n")
print(res$fix[, list(year, lu_trips, removed, pct_removed, dow,
                     tph_before, tph_after)], row.names = FALSE)

cat("\n=== London Underground inside the rail CIF feeds ===\n")
print(res$rail_metro_by_agency[agency_name %like% "Underground"],
      row.names = FALSE)
