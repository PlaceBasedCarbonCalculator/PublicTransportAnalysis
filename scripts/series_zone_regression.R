# The regression check for the series reconversion: across every year and
# every zone, did anywhere lose service? Zone counts are all modes summed,
# because a mode-level fall can be a stop moving between zones rather than
# service disappearing.
suppressMessages(library(data.table))
SP <- "C:/Users/earmmor/AppData/Local/Temp/claude/f--GitHub-PlaceBasedCarbonCalculator-PublicTransportAnalysis/8d0009c3-2cc7-4dc5-ba41-23031b8f2076/scratchpad"
allmode <- function(p) {
  d <- as.data.table(as.data.frame(readRDS(p)))
  rc <- grep("^runs_", names(d), value = TRUE)
  d[, list(runs = sum(unlist(.SD), na.rm = TRUE)), by = zone_id, .SDcols = rc]
}
res <- rbindlist(lapply(2014:2026, function(y) {
  a <- allmode(sprintf("data/trips_per_lsoa21_22_by_mode_%d.Rds", y))
  b <- allmode(file.path(SP, "head_outputs", paste0(y, ".Rds")))
  m <- merge(b[, list(zone_id, before = runs)], a[, list(zone_id, after = runs)],
             by = "zone_id", all = TRUE)
  m[is.na(before), before := 0]; m[is.na(after), after := 0]
  data.table(year = y,
             zones_before = m[before > 0, .N], zones_after = m[after > 0, .N],
             lost_all = m[before > 0 & after == 0, .N],
             gained_from_zero = m[before == 0 & after > 0, .N],
             zones_down = m[after < before, .N], zones_up = m[after > before, .N])
}))
cat("=== all modes together, per zone ===\n")
print(res, nrows = 20)
cat("\ntotal zones that lost ALL service across the whole series:",
    sum(res$lost_all), "\n")
cat("\n=== compact ===\n")
res[, net := zones_up - zones_down]
for (i in seq_len(nrow(res))) {
  cat(sprintf("  %d  zones %6d -> %6d | down %4d  up %4d | lost all %d  new %d\n",
      res$year[i], res$zones_before[i], res$zones_after[i],
      res$zones_down[i], res$zones_up[i], res$lost_all[i],
      res$gained_from_zero[i]))
}
