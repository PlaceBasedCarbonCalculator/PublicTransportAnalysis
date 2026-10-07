# Why did 178 stops change position between two builds of the same snapshot?
#
# The first reading was that keeping more TransXChange files had exercised the
# stop-identity non-determinism (one stop_id, several definitions). It had not.
# UK2GTFS ships its stop-location corrections as separately versioned package
# data, and reinstalling the package to apply a code change resets
# inst/extdata/date.txt, which forces a fresh download of that data. So the two
# feeds were built against different naptan_replace/naptan_missing tables and
# the moves are the corrections landing, not the filter.
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

# 3. the filter cannot be the cause: within a regional feed the patch is
#    applied to every entry present, so which files survive is irrelevant
cat("\n=== patch coverage inside each region of the AFTER build ===\n")
for (z in list.files(CACHE, pattern = "[.]zip$", full.names = TRUE)) {
  s <- try(stops_of(z), silent = TRUE)
  if (inherits(s, "try-error")) next
  s <- merge(s, replace_tbl[, list(stop_id, t_lat = stop_lat,
                                   t_lon = stop_lon)], by = "stop_id")
  if (!nrow(s)) next
  s[, d := metres(stop_lat, stop_lon, t_lat, t_lon)]
  cat(sprintf("  %-4s present %3d | patched %3d\n",
              sub("[.]zip$", "", basename(z)), nrow(s), s[d <= 1, .N]))
}

# 4. did any service move with them? the departures are what the published
#    measure counts, so identical call counts means nothing was gained or lost
calls <- function(zip) read_tbl(zip, "stop_times.txt", "stop_id")[, .N,
                                                                  by = stop_id]
cb <- calls(BEFORE); ca <- calls(AFTER)
cat("\n=== calls at the moved stops ===\n")
cat("before:", cb[stop_id %in% mv$stop_id, sum(N)],
    " after:", ca[stop_id %in% mv$stop_id, sum(N)], "\n")
cat("over 1 km, after:", ca[stop_id %in% mv[dist > 1000, stop_id], sum(N)],
    "of", sum(ca$N), "calls in the feed\n")
