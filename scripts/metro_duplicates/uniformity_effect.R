# What did reconverting the four already-correct snapshots actually change?
#
# tnds_20180515, 20191008, 20200701 and 20241004 had correct modes; they were
# rebuilt only so the whole series comes from one converter. The prediction was
# that nothing would move, on the basis that the two converters differed by 4
# naptan_replace stops in 13,102 on East Anglia 2018.
#
# This tests it. backups/post_modeorder_2026-09-24/ is the state immediately
# before the rebuild, so anything that differs is the converter and nothing
# else. The years that were NOT rebuilt are controls: they must be identical.
suppressPackageStartupMessages(library(data.table))

OLD <- "backups/post_modeorder_2026-09-24"
REBUILT <- c(2018, 2019, 2020, 2024)
MEASURES <- c("tph_Wed_Afternoon Peak", "tph_Wed_Morning Peak",
              "tph_Sat_Afternoon Peak", "runs_Wed_Afternoon Peak")

rows <- rbindlist(lapply(c(2004:2011, 2014:2025), function(y) {
  f <- sprintf("trips_per_lsoa21_22_by_mode_%s.Rds", y)
  fo <- file.path(OLD, f); fn <- file.path("data", f)
  if (!file.exists(fo) || !file.exists(fn)) return(NULL)
  o <- as.data.table(readRDS(fo)); n <- as.data.table(readRDS(fn))
  ms <- intersect(MEASURES, intersect(names(o), names(n)))
  rbindlist(lapply(ms, function(m) {
    a <- o[, list(zone_id, route_type = as.integer(route_type),
                  v = as.numeric(get(m)))]
    b <- n[, list(zone_id, route_type = as.integer(route_type),
                  v = as.numeric(get(m)))]
    k <- merge(a, b, by = c("zone_id", "route_type"), all = TRUE,
               suffixes = c("_o", "_n"))
    k[is.na(v_o), v_o := 0]; k[is.na(v_n), v_n := 0]
    data.table(year = y, measure = m,
               rebuilt = y %in% REBUILT,
               zone_modes = nrow(k),
               moved = sum(abs(k$v_n - k$v_o) > 1e-9),
               total_o = sum(k$v_o), total_n = sum(k$v_n),
               worst = max(abs(k$v_n - k$v_o)))
  }))
}))
rows[, d := round(total_n - total_o, 4)]
saveRDS(rows, "data/uniformity_effect.Rds")

cat("\n=== Zone-modes that moved, by year ===\n")
print(dcast(rows, year + rebuilt ~ measure, value.var = "moved"), nrows = 40)

cat("\n=== National totals, before and after ===\n")
print(rows[measure == "tph_Wed_Afternoon Peak",
           list(year, rebuilt, total_o = round(total_o), total_n = round(total_n),
                d, worst_zone_delta = round(worst, 3))], nrows = 40)

ctl <- rows[rebuilt == FALSE]
reb <- rows[rebuilt == TRUE]
cat("\n=== Verdict ===\n")
cat("controls (not rebuilt), zone-modes moved:", sum(ctl$moved), "\n")
cat("rebuilt years,          zone-modes moved:", sum(reb$moved), "\n")
cat("rebuilt years, largest single-zone change:", round(max(reb$worst), 4), "\n")
if (sum(ctl$moved) > 0) {
  cat("\nWARNING - a year that was not rebuilt changed:\n")
  print(ctl[moved > 0])
}
