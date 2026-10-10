# Measure what the day-type filter fix did to the published series, by
# comparing each trips_per_lsoa21_22_by_mode_<year>.Rds against the version
# committed before the reconversion:
#
#   for y in 2014..2026; git show HEAD:data/trips_..._$y.Rds > <dir>/$y.Rds
#
# Runs, not trips: a trip count rises when one file covering seven days is
# replaced by several covering one or two, with no change in service.
suppressMessages(library(data.table))
SP <- "C:/Users/earmmor/AppData/Local/Temp/claude/f--GitHub-PlaceBasedCarbonCalculator-PublicTransportAnalysis/8d0009c3-2cc7-4dc5-ba41-23031b8f2076/scratchpad"
mode_lab <- c(`0` = "tram", `1` = "metro", `2` = "rail", `3` = "bus",
              `4` = "ferry", `200` = "coach")
load1 <- function(p) {
  d <- as.data.table(as.data.frame(readRDS(p)))
  rc <- grep("^runs_", names(d), value = TRUE)
  d[, list(runs = sum(unlist(.SD), na.rm = TRUE), zones = uniqueN(zone_id)),
    by = route_type, .SDcols = rc]
}
yrs <- c(2014:2026)
out <- rbindlist(lapply(yrs, function(y) {
  a <- load1(sprintf("data/trips_per_lsoa21_22_by_mode_%d.Rds", y))
  b <- load1(file.path(SP, "head_outputs", paste0(y, ".Rds")))
  m <- merge(b[, list(route_type, runs_b = runs)],
             a[, list(route_type, runs_a = runs)],
             by = "route_type", all = TRUE)
  m[is.na(runs_b), runs_b := 0]; m[is.na(runs_a), runs_a := 0]
  m[, year := y][]
}))
out[, mode := mode_lab[as.character(route_type)]]
out[, pct := round(100 * (runs_a / runs_b - 1), 2)]

cat("=== runs by mode and year: before -> after (%) ===\n")
w <- dcast(out, year ~ mode, value.var = "pct")
print(w, nrows = 20)
cat("\n=== all-mode totals ===\n")
tot <- out[, list(before = sum(runs_b), after = sum(runs_a)), by = year]
tot[, pct := round(100 * (after / before - 1), 2)]
print(tot, nrows = 20)
cat("\n=== bus only ===\n")
bus <- out[mode == "bus", list(year, before = runs_b, after = runs_a, pct)]
print(bus, nrows = 20)
cat("\n=== tram only ===\n")
print(out[mode == "tram", list(year, before = runs_b, after = runs_a, pct)],
      nrows = 20)
cat("\n=== any mode/year that LOST runs ===\n")
print(out[runs_a < runs_b, list(year, mode, before = runs_b, after = runs_a,
                                pct)], nrows = 40)
saveRDS(out, file.path(SP, "series_effect.Rds"))
