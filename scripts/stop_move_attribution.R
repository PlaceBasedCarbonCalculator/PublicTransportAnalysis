# Why did 178 stops change position between two builds of the same snapshot?
#
# The first reading was that keeping more TransXChange files had exercised the
# stop-identity non-determinism (one stop_id, several definitions). It had not:
# the TransXChange files carry no coordinates at all, so surviving-file choice
# cannot vote on a position. The moves are UK2GTFS's own stop-location
# corrections (naptan_replace, naptan_missing) landing where the earlier build
# did not have them. Why the earlier build applied fewer of them is still open
# - the leading explanation is that reinstalling the package to apply a code
# change resets inst/extdata/date.txt and so re-downloads the separately
# versioned package data, but both build logs do report patch_naptan() running.
#
# The naptan_missing column below is measured against that table, which is
# stale for every stop it flags here (all 22 have since been added to NaPTAN
# proper); measured against live NaPTAN the group moves 8 -> 14 correct, which
# the last block reports.
#
# Usage: Rscript scripts/stop_move_attribution.R <before.zip> <after.zip>
suppressMessages(library(data.table))

args <- commandArgs(TRUE)
BEFORE <- if (length(args) >= 1) args[1] else
  "gtfs/prefix_daytype/tnds_20261002_merged.zip"
AFTER <- if (length(args) >= 2) args[2] else
  "gtfs/tnds_20261002_merged.zip"
# the per-region conversion caches the AFTER feed was merged from, used for the
# check that the filter cannot be the cause
CACHE <- if (length(args) >= 3) args[3] else "gtfs/cache/tnds_20261002_v25"

read_tbl <- function(zip, name, cols = NULL) {
  con <- unz(zip, name)
  on.exit(try(close(con), silent = TRUE), add = TRUE)
  fread(text = readLines(con, warn = FALSE), select = cols,
        showProgress = FALSE)
}
stops_of <- function(zip) {
  read_tbl(zip, "stops.txt",
           c("stop_id", "stop_name", "stop_lat", "stop_lon"))
}
# metres, near enough at these latitudes
metres <- function(lat1, lon1, lat2, lon2) {
  sqrt((111320 * (lat1 - lat2))^2 + (67000 * (lon1 - lon2))^2)
}

e <- new.env()
UK2GTFS::load_data("naptan_replace", envir = e)
UK2GTFS::load_data("naptan_missing", envir = e)
replace_tbl <- as.data.table(e$naptan_replace)
missing_tbl <- unique(as.data.table(e$naptan_missing), by = "stop_id")
naptan <- unique(as.data.table(UK2GTFS::get_naptan()), by = "stop_id")

b <- stops_of(BEFORE)
a <- stops_of(AFTER)
m <- merge(b[, list(stop_id, name_b = stop_name,
                    lat_b = stop_lat, lon_b = stop_lon)],
           a[, list(stop_id, name_a = stop_name,
                    lat_a = stop_lat, lon_a = stop_lon)],
           by = "stop_id")
m[, dist := metres(lat_a, lon_a, lat_b, lon_b)]
mv <- m[dist > 0.5]

cat("stops in both feeds:", nrow(m), "\n")
for (th in c(0.5, 200, 1000, 10000)) {
  cat(sprintf("  moved > %6.0f m: %4d\n", th, m[dist > th, .N]))
}

# 1. which patch table does each mover belong to, and did it land on the
#    position that table publishes as correct?
mv[, group := fifelse(stop_id %in% replace_tbl$stop_id, "naptan_replace",
              fifelse(stop_id %in% missing_tbl$stop_id, "naptan_missing",
                      "neither"))]
target <- rbind(
  replace_tbl[, list(stop_id, t_lat = stop_lat, t_lon = stop_lon)],
  missing_tbl[!stop_id %in% replace_tbl$stop_id,
              list(stop_id, t_lat = stop_lat, t_lon = stop_lon)])
mv <- merge(mv, target, by = "stop_id", all.x = TRUE)
mv[, `:=`(d_before = metres(lat_b, lon_b, t_lat, t_lon),
          d_after  = metres(lat_a, lon_a, t_lat, t_lon))]
cat("\n=== the movers, by patch table ===\n")
print(mv[, list(n = .N, over_1km = sum(dist > 1000),
                at_corrected_before = sum(!is.na(d_before) & d_before <= 1),
                at_corrected_after  = sum(!is.na(d_after) & d_after <= 1)),
         by = group][order(-n)])

# 2. the same question over every naptan_replace stop, not just the movers
cat("\n=== all naptan_replace stops present in the feeds ===\n")
for (lab in c("before", "after")) {
  s <- if (lab == "before") b else a
  s <- merge(s, replace_tbl[, list(stop_id, t_lat = stop_lat,
                                   t_lon = stop_lon)], by = "stop_id")
  s[, d := metres(stop_lat, stop_lon, t_lat, t_lon)]
  cat(sprintf("  %-6s present %3d | at the corrected position %3d\n",
              lab, nrow(s), s[d <= 1, .N]))
}

# 3. how much of this the filter could own: patch_naptan() runs per regional
#    feed and the merge keeps the first contributing region's copy, so the
#    filter could matter only for stops present in more than one region
cat("\n=== patch coverage inside each region of the AFTER build ===\n")
zips <- list.files(CACHE, pattern = "[.]zip$", full.names = TRUE)
for (z in zips) {
  s <- try(stops_of(z), silent = TRUE)
  if (inherits(s, "try-error")) next
  s <- merge(s, replace_tbl[, list(stop_id, t_lat = stop_lat,
                                   t_lon = stop_lon)], by = "stop_id")
  if (!nrow(s)) next
  s[, d := metres(stop_lat, stop_lon, t_lat, t_lon)]
  cat(sprintf("  %-4s present %3d | patched %3d\n",
              sub("[.]zip$", "", basename(z)), nrow(s), s[d <= 1, .N]))
}

# 3b. can merge order decide the patched state? only for a stop present in
#     more than one regional feed, and there are very few of those
reg <- rbindlist(lapply(seq_along(zips), function(i) {
  st <- try(stops_of(zips[i]), silent = TRUE)
  if (inherits(st, "try-error")) return(NULL)
  st <- merge(st, replace_tbl[, list(stop_id, t_lat = stop_lat,
                                     t_lon = stop_lon)], by = "stop_id")
  if (!nrow(st)) return(NULL)
  st[, list(stop_id, ord = i,
            patched = metres(stop_lat, stop_lon, t_lat, t_lon) <= 1)]
}))
cat("\n=== merge order: can it decide the patched state? ===\n")
cat("  naptan_replace stops across the regions:", uniqueN(reg$stop_id),
    " present in >1 region:", reg[, .N, by = stop_id][N > 1, .N], "\n")
mg <- merge(a, replace_tbl[, list(stop_id, t_lat = stop_lat,
                                  t_lon = stop_lon)], by = "stop_id")
mg[, merged_patched := metres(stop_lat, stop_lon, t_lat, t_lon) <= 1]
first <- reg[order(ord), list(first_patched = patched[1],
                              any_patched = any(patched)), by = stop_id]
cmp <- merge(mg[, list(stop_id, merged_patched)], first, by = "stop_id")
cat("  merged follows the first region:",
    cmp[first_patched == merged_patched, .N], "of", nrow(cmp), "\n")
cat("  merged-unpatched stops that no region patched:",
    cmp[merged_patched == FALSE & any_patched == FALSE, .N], "\n")

# 4. the naptan_missing group against LIVE naptan, since that table is stale
#    for them - this is the number the report quotes
nm_mv <- mv[group == "naptan_missing"]
nm_mv <- merge(nm_mv, naptan[, list(stop_id, n_lat = stop_lat,
                                    n_lon = stop_lon)],
               by = "stop_id", all.x = TRUE)
cat("
=== naptan_missing movers against live NaPTAN ===
")
cat("  n:", nrow(nm_mv), " present in live NaPTAN:", nm_mv[!is.na(n_lat), .N],
    "
")
cat("  on the live NaPTAN position before:",
    nm_mv[metres(lat_b, lon_b, n_lat, n_lon) <= 1, .N],
    " after:", nm_mv[metres(lat_a, lon_a, n_lat, n_lon) <= 1, .N], "
")

# 5. did any service move with them? the departures are what the published
#    measure counts, so identical call counts means nothing was gained or lost
calls <- function(zip) read_tbl(zip, "stop_times.txt", "stop_id")[, .N,
                                                                  by = stop_id]
cb <- calls(BEFORE); ca <- calls(AFTER)
cat("\n=== calls at the moved stops ===\n")
cat("before:", cb[stop_id %in% mv$stop_id, sum(N)],
    " after:", ca[stop_id %in% mv$stop_id, sum(N)], "\n")
cat("over 1 km, after:", ca[stop_id %in% mv[dist > 1000, stop_id], sum(N)],
    "of", sum(ca$N), "calls in the feed\n")
