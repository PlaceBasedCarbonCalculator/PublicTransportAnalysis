# What the day-type fix changed in the October 2026 comparison.
#
# The fix keys rule 1 of txc_filter_files() on the operating day set and stops
# rule 4 reconciling files whose days do not intersect, so both TransXChange
# sources are reconverted. The DfT's BODS GTFS is untouched by it - that feed
# is read as supplied - which makes its column the fixed point the other two
# move against, and the one check that says whether a change is real or just
# the pipeline moving under us.
#
# Run after the reconversion. Compares the rebuilt comparison against the
# pre-fix copy kept in gtfs/prefix_daytype/, which is where
# scripts/.. the rebuild driver put it before deleting the caches.
#
# Usage: Rscript scripts/daytype_fix_effect.R

suppressMessages(library(data.table))
source("R/config.R")
source("R/comparison.R")
cfg <- load_cfg()

BEFORE <- file.path(cfg$gtfs_dir, "prefix_daytype",
                    "bus_source_comparison_2026.Rds")
AFTER <- file.path(cfg$out_dir, "bus_source_comparison_2026.Rds")
stopifnot(file.exists(BEFORE), file.exists(AFTER))

b <- readRDS(BEFORE)
a <- readRDS(AFTER)
stopifnot(identical(b$window, a$window))
cat("window:", as.character(a$window$startdate), "to",
    as.character(a$window$enddate), "\n")

pc <- function(new, old) {
  ifelse(old == 0, NA_real_, round(100 * (new / old - 1), 2))
}

cat("\n=== feed size ===\n")
sb <- as.data.table(b$stats)[, list(source, routes, trips, trips_in_window)]
sa <- as.data.table(a$stats)[, list(source, routes, trips, trips_in_window)]
m <- merge(sb, sa, by = "source", suffixes = c("_before", "_after"))
m[, `:=`(routes_pct = pc(routes_after, routes_before),
         trips_pct = pc(trips_after, trips_before),
         win_pct = pc(trips_in_window_after, trips_in_window_before))]
print(m[])

cat("\n=== zone-level mean daytime trips per hour ===\n")
zb <- as.data.table(b$bus_wide); za <- as.data.table(a$bus_wide)
z <- merge(zb, za, by = "zone_id", suffixes = c("_b", "_a"))
cat("zones compared:", nrow(z), "\n")
for (s in comparison_sources()) {
  ob <- mean(z[[paste0(s, "_b")]]); oa <- mean(z[[paste0(s, "_a")]])
  cat(sprintf("  %-10s %.4f -> %.4f  (%+.2f%%)\n", s, ob, oa,
              100 * (oa / ob - 1)))
}

cat("\n=== by country ===\n")
z[, country := substr(zone_id, 1, 1)]
print(z[, list(zones = .N,
               tnds_b = round(mean(tnds_b), 3),
               tnds_a = round(mean(tnds_a), 3),
               tnds_pct = pc(mean(tnds_a), mean(tnds_b)),
               txc_b = round(mean(bods_txc_b), 3),
               txc_a = round(mean(bods_txc_a), 3),
               txc_pct = pc(mean(bods_txc_a), mean(bods_txc_b)),
               gtfs_pct = pc(mean(bods_gtfs_a), mean(bods_gtfs_b))),
         by = country])

cat("\n=== zones with no bus service ===\n")
for (s in comparison_sources()) {
  cat(sprintf("  %-10s %5d -> %5d\n", s,
              sum(z[[paste0(s, "_b")]] == 0),
              sum(z[[paste0(s, "_a")]] == 0)))
}

cat("\n=== the check that it is the fix and not drift ===\n")
gd <- z[, max(abs(bods_gtfs_a - bods_gtfs_b))]
cat("largest per-zone change in the untouched BODS GTFS column:", gd, "\n")
if (gd < 1e-9) {
  cat("  zero, as it must be: that column was not reconverted\n")
} else {
  cat("  NOT ZERO - something other than the fix moved as well\n")
}

cat("\n=== agreement with BODS GTFS, before and after ===\n")
# The measure the validation uses: mean |log(ratio)| against the DfT's feed on
# zones where both carry service. Lower is closer.
dist <- function(x, y) {
  ok <- x > 0 & y > 0
  mean(abs(log(x[ok] / y[ok])))
}
cat(sprintf("  TNDS vs BODS GTFS      %.4f -> %.4f\n",
            dist(z$tnds_b, z$bods_gtfs_b), dist(z$tnds_a, z$bods_gtfs_a)))
cat(sprintf("  BODS TXC vs BODS GTFS  %.4f -> %.4f\n",
            dist(z$bods_txc_b, z$bods_gtfs_b),
            dist(z$bods_txc_a, z$bods_gtfs_a)))

cat("\n=== expiry inside the window (TransXChange sources) ===\n")
eb <- as.data.table(b$expiry)[, list(source, share_ending_early,
                                     runs_counted)]
ea <- as.data.table(a$expiry)[, list(source, share_ending_early,
                                     runs_counted)]
print(merge(eb, ea, by = "source", suffixes = c("_before", "_after")))

cat("\n=== service-level totals ===\n")
sv_b <- as.data.table(b$services); sv_a <- as.data.table(a$services)
cat(sprintf("  matched service groups  %d -> %d\n", nrow(sv_b), nrow(sv_a)))
for (s in comparison_sources()) {
  cat(sprintf("  runs %-10s %9.0f -> %9.0f  (%+.2f%%)\n", s,
              sum(sv_b[[s]]), sum(sv_a[[s]]),
              100 * (sum(sv_a[[s]]) / sum(sv_b[[s]]) - 1)))
}

cat("\n=== weekend service, which is what the fix recovers ===\n")
# The defect deleted Saturday and Sunday files, so the gain should be
# concentrated there rather than spread across the week.
bb <- as.data.table(b$bands)[, list(runs = sum(runs)), by = list(source, day)]
ba <- as.data.table(a$bands)[, list(runs = sum(runs)), by = list(source, day)]
bands <- merge(bb, ba, by = c("source", "day"),
               suffixes = c("_before", "_after"))
bands[, pct := pc(runs_after, runs_before)]
print(dcast(bands, day ~ source, value.var = "pct"))

saveRDS(list(stats = m, zones = z[, list(zone_id, country, tnds_b, tnds_a,
                                         bods_txc_b, bods_txc_a,
                                         bods_gtfs_b, bods_gtfs_a)],
             bands = bands),
        file.path(cfg$out_dir, "daytype_fix_effect_2026.Rds"))
cat("\nwrote", file.path(cfg$out_dir, "daytype_fix_effect_2026.Rds"), "\n")
