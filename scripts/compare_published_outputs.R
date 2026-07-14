# Quantify how the new outputs differ from the published TransportBlackspots
# outputs (data/trips_per_lsoa21_22_by_mode_<year>.Rds in that repo, built
# Nov 2025 with pre-audit UK2GTFS and non-standard windows).
#
# Run after the pipeline completes:
#   "C:\Program Files\R\R-4.3.3\bin\Rscript.exe" scripts/compare_published_outputs.R
#
# Writes data/method_change_summary.csv: per year and mode, total bus runs
# and mean daytime tph under both methods, plus the correlation between the
# per-zone values. Differences are expected (see README "Changes from
# TransportBlackspots"); this table documents their size.

source("R/config.R")
source("R/comparison.R") # for add_tph_daytime_avg

cfg <- load_cfg()
years <- intersect(analysis_years(), 2004:2023)

rows <- list()
for (y in years) {
  new_p <- file.path(cfg$out_dir, sprintf("trips_per_lsoa21_22_by_mode_%s.Rds", y))
  old_p <- file.path(cfg$tb_repo, "data",
                     sprintf("trips_per_lsoa21_22_by_mode_%s.Rds", y))
  if (!file.exists(new_p) || !file.exists(old_p)) {
    message("Skipping ", y, " (missing file)")
    next
  }
  new <- as.data.frame(readRDS(new_p))
  old <- as.data.frame(readRDS(old_p))
  # Like-for-like: the old outputs counted coach inside bus (route_type 3);
  # the new outputs separate coach as 200, so sum 3 + 200 per zone
  new <- new[!is.na(new$zone_id) & new$route_type %in% c(3, 200), ]
  new <- dplyr::summarise(dplyr::group_by(new, zone_id),
                          dplyr::across(dplyr::where(is.numeric), sum),
                          .groups = "drop")
  new$route_type <- 3
  new <- add_tph_daytime_avg(new)
  old <- old[!is.na(old$zone_id) & old$route_type == 3, ]
  old <- add_tph_daytime_avg(old)
  runs_cols <- grep("^runs_", names(new), value = TRUE)
  m <- merge(new[, c("zone_id", "tph_daytime_avg")],
             old[, c("zone_id", "tph_daytime_avg")],
             by = "zone_id", suffixes = c("_new", "_old"))
  rows[[as.character(y)]] <- data.frame(
    year = y,
    zones_new = nrow(new),
    zones_old = nrow(old),
    bus_runs_new = sum(new[runs_cols]),
    bus_runs_old = sum(old[intersect(runs_cols, names(old))]),
    negative_cells_old = sum(sapply(old[intersect(runs_cols, names(old))],
                                    function(x) sum(x < 0))),
    mean_tph_daytime_new = round(mean(new$tph_daytime_avg), 3),
    mean_tph_daytime_old = round(mean(old$tph_daytime_avg), 3),
    per_zone_pearson_r = round(cor(m$tph_daytime_avg_new,
                                   m$tph_daytime_avg_old), 4),
    per_zone_spearman = round(cor(m$tph_daytime_avg_new, m$tph_daytime_avg_old,
                                  method = "spearman"), 4)
  )
  message(y, " done")
}

out <- dplyr::bind_rows(rows)
utils::write.csv(out, file.path(cfg$out_dir, "method_change_summary.csv"),
                 row.names = FALSE)
print(out)
