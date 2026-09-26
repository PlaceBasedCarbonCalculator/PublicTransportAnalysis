# Prove why the stop-name mode rules stopped firing.
#
# transxchange2gtfs() now runs in this order (R/transxchange.R, after 39da3f5
# "transxchange speedup"):
#
#   284  gtfs_merged <- gtfs_merge(gtfs_all, ...)
#   297  gtfs_merged <- apply_standard_modes(gtfs_merged, source = "txc")
#   304  gtfs_merged$stops <- txc_join_naptan(gtfs_merged$stops, naptan)
#
# The NaPTAN join moved from per-file (before the merge) to once over the
# merged feed, for speed - but it moved to AFTER apply_standard_modes(). The
# code's own comment at 300 says "the per-file exports emitted bare stop_ids".
# So when the mode rules run, stop_name is empty, and every rule that matches
# on a stop name silently matches nothing.
#
# Operator-code rules (Luton DART, the London Cable Car, Weardale) are
# unaffected, which is why the logs still report a handful of corrections.
#
# The test: take the FINISHED feed, which does have stop names, and run
# apply_standard_modes() on it. If the rules then fire, they were only ever
# defeated by the ordering.
#
# Run from the repo root:
#   Rscript scripts/metro_duplicates/prove_mode_order.R

suppressPackageStartupMessages({
  library(data.table)
})

FEEDS <- c(new_converter_2021 = "gtfs/tnds_20211012_merged.zip",
           new_converter_2025 = "gtfs/tnds_20251003_merged.zip",
           old_converter_2024 = "gtfs/tnds_20241004_merged.zip")

WATCH <- c("Docklands Light Railway", "Glasgow Subway",
           "Gatwick Airport shuttle", "London Underground")

MODE_NAME <- c(`0` = "tram", `1` = "metro", `2` = "rail", `3` = "bus",
               `4` = "ferry", `6` = "aerial")

out <- list()
for (lab in names(FEEDS)) {
  path <- FEEDS[[lab]]
  message(lab, ": ", path)
  g <- UK2GTFS::gtfs_read(path)

  # how many stops actually carry a name, in the feed as published
  named <- sum(!is.na(g$stops$stop_name) & nzchar(as.character(g$stops$stop_name)))
  message("  stops with a name: ", named, " of ", nrow(g$stops))

  before <- as.data.table(g$routes)[, list(route_id = as.character(route_id),
                                           rt_before = as.integer(route_type))]

  # re-run the rules on the finished feed, where the names are present
  g2 <- UK2GTFS:::apply_standard_modes(g, source = "txc", quiet = FALSE)
  after <- as.data.table(g2$routes)[, list(route_id = as.character(route_id),
                                           rt_after = as.integer(route_type))]
  cmp <- merge(before, after, by = "route_id")
  moved <- cmp[rt_before != rt_after]

  # name the systems whose routes moved, by the stop names they call at
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
  rs <- unique(merge(st, tr, by = "trip_id")[, list(route_id, stop_id)])
  rs <- merge(rs, sp[, list(stop_id, sys)], by = "stop_id", all.x = TRUE)
  n <- rs[, list(n = .N), by = "route_id"]
  h <- rs[!is.na(sys), list(n_hit = .N), by = c("route_id", "sys")]
  h <- merge(h, n, by = "route_id")[n_hit / n >= 0.8]
  setorderv(h, c("route_id", "n_hit"), c(1L, -1L))
  h <- h[!duplicated(h$route_id)]
  nt <- tr[, list(trips = .N), by = "route_id"]

  k <- merge(cmp, h[, list(route_id, sys)], by = "route_id", all.x = TRUE)
  k <- merge(k, nt, by = "route_id", all.x = TRUE)
  s <- k[!is.na(sys) & sys %in% WATCH,
         list(routes = .N, trips = sum(trips, na.rm = TRUE)),
         by = c("sys", "rt_before", "rt_after")]
  s[, `:=`(before = MODE_NAME[as.character(rt_before)],
           after = MODE_NAME[as.character(rt_after)])]
  s[, feed := lab]
  out[[lab]] <- s

  message("  routes the rules would move now: ", nrow(moved),
          " (", sum(k$trips[k$rt_before != k$rt_after], na.rm = TRUE),
          " trips)")
  rm(g, g2); gc(verbose = FALSE)
}

res <- rbindlist(out, fill = TRUE)
saveRDS(res, "data/mode_order_proof.Rds")

cat("\n=== Re-running the mode rules on the PUBLISHED feed ===\n")
cat("'before' is the mode in the feed the pipeline produced.\n")
cat("'after' is what the rules give once stop names are present.\n")
cat("A row where before != after is a rule the conversion silently skipped.\n\n")
print(res[, list(feed, sys, before, after, routes, trips)], nrows = 60)

cat("\n=== Verdict ===\n")
for (lab in names(FEEDS)) {
  s <- res[feed == lab & before != after]
  cat(sprintf("%-20s rules skipped by the conversion: %d systems, %d trips\n",
              lab, nrow(s), sum(s$trips, na.rm = TRUE)))
}
