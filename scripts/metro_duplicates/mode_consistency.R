# Is each fixed-track system given the SAME route_type in every year?
#
# compare_rebuild.R's per-system table showed Docklands Light Railway as metro
# in the 2018 and 2024 snapshots but rail in 2021 and 2025, and the Glasgow
# Subway as metro in 2018/2024 but tram in 2021/2025. If that is real the metro
# series is not comparable between years, which is a worse defect than the one
# the rebuild set out to fix.
#
# That table reports the route_type of routes whose stops match a system's
# NaPTAN pattern at the 0.8 threshold apply_standard_modes() uses. This script
# asks the question directly of every merged feed in the series, and also
# reports the agency, so a system can be told apart from a lookalike.
#
# Run from the repo root:
#   Rscript scripts/metro_duplicates/mode_consistency.R

suppressPackageStartupMessages({
  library(data.table)
})

OUT <- "data/mode_consistency.Rds"

FEEDS <- c(
  sprintf("gtfs/nptdr_%d.zip", c(2004:2011)),
  sprintf("gtfs/busarchive_%d_merged.zip", 2014:2017),
  "gtfs/tnds_20180515_merged.zip", "gtfs/tnds_20191008_merged.zip",
  "gtfs/tnds_20200701_merged.zip", "gtfs/tnds_20211012_merged.zip",
  "gtfs/tnds_20221102_merged.zip", "gtfs/tnds_20231101_merged.zip",
  "gtfs/tnds_20241004_merged.zip", "gtfs/tnds_20251003_merged.zip")

MODE_NAME <- c(`0` = "tram", `1` = "metro", `2` = "rail", `3` = "bus",
               `4` = "ferry", `6` = "aerial", `11` = "trolley",
               `200` = "coach", `1100` = "air")

#' Which system each route belongs to, and what mode it was given
#'
#' Identical in method to apply_standard_modes(): a route belongs to a system
#' when at least `threshold` of the distinct stops it calls at match that
#' system's NaPTAN name pattern. Reporting the route's *actual* route_type
#' next to that is what exposes a system the rules did not reach.
#'
#' @param path a converted GTFS zip
#' @return a data.table of system, route_type, routes, trips and agencies
system_modes <- function(path, threshold = 0.8) {
  if (!file.exists(path)) {
    message("  missing: ", path)
    return(NULL)
  }
  g <- UK2GTFS::gtfs_read(path)
  ov <- UK2GTFS::standard_mode_overrides()
  ov <- ov[!is.na(ov$stop_pattern) & nzchar(ov$stop_pattern), , drop = FALSE]

  sp <- as.data.table(g$stops)[, list(stop_id = as.character(stop_id),
                                      stop_name = as.character(stop_name))]
  sp[, sys := NA_character_]
  for (i in seq_len(nrow(ov))) {
    hit <- is.na(sp$sys) & grepl(ov$stop_pattern[i], sp$stop_name,
                                 ignore.case = TRUE, useBytes = TRUE)
    sp[hit, sys := ov$system[i]]
  }

  st <- as.data.table(g$stop_times)[, list(trip_id = as.character(trip_id),
                                           stop_id = as.character(stop_id))]
  tr <- as.data.table(g$trips)[, list(trip_id = as.character(trip_id),
                                      route_id = as.character(route_id))]
  ro <- as.data.table(g$routes)[, list(route_id = as.character(route_id),
                                       agency_id = as.character(agency_id),
                                       route_type = as.integer(route_type))]
  rs <- unique(merge(st, tr, by = "trip_id")[, list(route_id, stop_id)])
  rs <- merge(rs, sp[, list(stop_id, sys)], by = "stop_id", all.x = TRUE)
  n <- rs[, list(n = .N), by = "route_id"]
  h <- rs[!is.na(sys), list(n_hit = .N), by = c("route_id", "sys")]
  h <- merge(h, n, by = "route_id")[n_hit / n >= threshold]
  if (nrow(h) == 0) {
    rm(g); gc(verbose = FALSE)
    return(NULL)
  }
  setorderv(h, c("route_id", "n_hit"), c(1L, -1L))
  h <- h[!duplicated(h$route_id)]
  h <- merge(h, ro, by = "route_id")
  nt <- tr[, list(trips = .N), by = "route_id"]
  h <- merge(h, nt, by = "route_id", all.x = TRUE)
  out <- h[, list(routes = .N, trips = sum(trips, na.rm = TRUE),
                  agencies = paste(sort(unique(agency_id)), collapse = "/")),
           by = c("sys", "route_type")]
  rm(g); gc(verbose = FALSE)
  out[, feed := basename(path)]
  out[]
}

res <- rbindlist(lapply(FEEDS, function(f) {
  message(basename(f))
  system_modes(f)
}), fill = TRUE)

saveRDS(res, OUT)
message("Written ", OUT)

res[, mode := MODE_NAME[as.character(route_type)]]

cat("\n=== Mode given to each system, by feed ===\n")
w <- dcast(res, sys ~ feed, value.var = "mode",
           fun.aggregate = function(x) paste(sort(unique(x)), collapse = "+"),
           fill = "")
print(w, nrows = 60)

cat("\n=== Systems given more than one mode across the series ===\n")
chk <- res[, list(modes = paste(sort(unique(mode)), collapse = ", "),
                  n_modes = uniqueN(route_type),
                  feeds = .N),
           by = "sys"]
setorder(chk, -n_modes)
print(chk, nrows = 60)

bad <- chk[n_modes > 1]
cat("\nsystems with an inconsistent mode: ", nrow(bad), "\n")
if (nrow(bad) > 0) {
  cat("\n=== Detail for the inconsistent systems ===\n")
  print(res[sys %in% bad$sys,
            list(sys, feed, route_type, mode, routes, trips, agencies)],
        nrows = 200)
}
