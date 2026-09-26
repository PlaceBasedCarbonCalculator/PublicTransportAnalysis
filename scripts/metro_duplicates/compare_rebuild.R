# Compare the outputs before and after the metro fixes.
#
# The seven fixes in reports/metro_duplicate_copies.md all change conversion,
# so nothing moved until the pipeline was rebuilt (rebuild_metro_fixes.R).
# This measures what actually changed, against the copy taken immediately
# before the rebuild.
#
# The point is not to confirm the metro change - that was predicted and
# measured - but to find the changes that were *not* predicted. Every fix has
# a stated blast radius, and anything moving outside it is either a second
# defect the fixes exposed or a regression they introduced. So every mode is
# compared, not just metro, and the zones with the largest movements are
# listed whatever mode they are in.
#
# Run from the repo root, after a rebuild:
#   Rscript scripts/metro_duplicates/compare_rebuild.R
#
# Writes data/rebuild_comparison.Rds and prints every table the report quotes.

suppressPackageStartupMessages({
  library(data.table)
})

OLD_DIR <- "backups/pre_metro_fixes_2026-09-11"
NEW_DIR <- "data"
OUT <- "data/rebuild_comparison.Rds"

# The measure the report leads on. Afternoon peak is the band the Leytonstone
# defect was found in, and Wednesday is the representative weekday the repo
# uses elsewhere.
MEASURE <- "tph_Wed_Afternoon Peak"

MODE_NAME <- c(`0` = "tram", `1` = "metro", `2` = "rail", `3` = "bus",
               `4` = "ferry", `6` = "aerial lift", `11` = "trolleybus",
               `200` = "coach", `1100` = "air")

# The zone the defect was found in. Only this one is named: the zone file
# carries no names, so any other label would be a guess, and the per-system
# question is answered from the feeds instead (see feed_systems() below),
# where a system can be identified exactly by the NaPTAN names of its stops.
LEYTONSTONE <- "E01004440"

# Feeds to compare system by system. The old copies were taken before the
# rebuild overwrote them; without them the per-system question could not be
# asked again, because reproducing them needs the old package.
OLD_GTFS <- "backups/gtfs_pre_metro_fixes"
FEED_PAIRS <- c("tnds_20180515_merged.zip", "tnds_20211012_merged.zip",
                "tnds_20241004_merged.zip", "tnds_20251003_merged.zip",
                "nptdr_2004.zip", "nptdr_2011.zip",
                "rail_atoc_2024-10-05.zip", "rail_rdp_20251006.zip")


#' Read one year, before and after, as one long table
#'
#' @param year the analysis year
#' @return a data.table of zone_id, route_type, old and new, one row per zone
#'   and mode that appears in either
read_pair <- function(year) {
  f <- sprintf("trips_per_lsoa21_22_by_mode_%s.Rds", year)
  fo <- file.path(OLD_DIR, f)
  fn <- file.path(NEW_DIR, f)
  if (!file.exists(fo) || !file.exists(fn)) return(NULL)
  grab <- function(p) {
    x <- as.data.table(readRDS(p))
    if (!MEASURE %in% names(x)) return(NULL)
    x[, list(zone_id, route_type = as.integer(route_type),
             v = as.numeric(get(MEASURE)))]
  }
  o <- grab(fo); n <- grab(fn)
  if (is.null(o) || is.null(n)) return(NULL)
  # a mode can appear in one and not the other - Fix F creates route_type 6
  # and can empty a mode entirely - so the join must keep both sides
  m <- merge(o, n, by = c("zone_id", "route_type"), all = TRUE,
             suffixes = c("_old", "_new"))
  setnames(m, c("v_old", "v_new"), c("old", "new"))
  m[is.na(old), old := 0]
  m[is.na(new), new := 0]
  m[, year := year]
  m[]
}


#' National totals by mode, before and after
by_mode <- function(p) {
  s <- p[, list(old = sum(old), new = sum(new),
                zones_old = sum(old > 0), zones_new = sum(new > 0)),
         by = c("year", "route_type")]
  s[, `:=`(diff = new - old,
           pct = ifelse(old > 0, round(100 * (new - old) / old, 1), NA_real_))]
  s[, mode := MODE_NAME[as.character(route_type)]]
  setorderv(s, c("year", "route_type"))
  s[]
}


#' How the change is distributed across zones, within one mode
#'
#' A fix that removes duplicate copies should move a minority of zones a long
#' way, not every zone a little. The share of zones that moved at all is the
#' test of that, and a mode where nearly every zone moves slightly is a sign
#' of something systemic rather than a duplicate.
spread <- function(p, rt) {
  s <- p[route_type == rt & (old > 0 | new > 0)]
  if (nrow(s) == 0) return(NULL)
  s[, d := new - old]
  s[, list(zones = .N,
           unchanged = sum(abs(d) < 1e-9),
           pct_unchanged = round(100 * sum(abs(d) < 1e-9) / .N, 1),
           fell = sum(d < -1e-9), rose = sum(d > 1e-9),
           median_d = round(median(d), 2),
           p05 = round(quantile(d, 0.05), 1),
           p95 = round(quantile(d, 0.95), 1),
           worst_fall = round(min(d), 1), worst_rise = round(max(d), 1)),
    by = "year"]
}


#' The zones that moved most, in either direction
movers <- function(p, n = 15, rt = NULL) {
  s <- if (is.null(rt)) copy(p) else p[route_type == rt]
  s <- s[(old > 0 | new > 0)]
  s[, d := new - old]
  s[, mode := MODE_NAME[as.character(route_type)]]
  setorder(s, -d)
  rbind(head(s, n), tail(s, n))[, list(year, zone_id, mode, old = round(old, 1),
                                       new = round(new, 1), d = round(d, 1))]
}


years <- c(2004:2011, 2014:2025)
message("Reading ", length(years), " year pairs")
pairs <- rbindlist(lapply(years, function(y) {
  p <- read_pair(y)
  if (is.null(p)) message("  ", y, ": skipped, one side missing")
  else message("  ", y, ": ", nrow(p), " zone-modes")
  p
}), fill = TRUE)

if (nrow(pairs) == 0) stop("no year could be compared")

res <- list(measure = MEASURE, years = sort(unique(pairs$year)))
res$by_mode <- by_mode(pairs)
res$spread <- rbindlist(lapply(sort(unique(pairs$route_type)), function(rt) {
  s <- spread(pairs, rt)
  if (is.null(s)) NULL else s[, route_type := rt][]
}), fill = TRUE)
res$movers_all <- movers(pairs, 20)
res$movers_bus <- movers(pairs, 15, rt = 3L)
res$leytonstone <- pairs[zone_id == LEYTONSTONE]
res$leytonstone[, d := new - old]

#' Trips by mode for each system the mode rules name, old feed against new
#'
#' The zone comparison says a mode moved; this says which system moved it. A
#' system is identified the way UK2GTFS::standard_mode_overrides() identifies
#' it, by the NaPTAN names of the stops its routes call at, so the answer does
#' not depend on operator codes, which are not stable between archives.
#'
#' @param feed file name, expected in both OLD_GTFS and the gtfs directory
#' @return a data.table of system, route_type and trips, on each side
feed_systems <- function(feed, threshold = 0.8) {
  fo <- file.path(OLD_GTFS, feed)
  fn <- file.path("gtfs", feed)
  if (!file.exists(fo) || !file.exists(fn)) return(NULL)
  ov <- UK2GTFS::standard_mode_overrides()
  ov <- ov[!is.na(ov$stop_pattern), , drop = FALSE]

  one <- function(path, side) {
    g <- UK2GTFS::gtfs_read(path)
    sp <- as.data.table(g$stops)[, list(stop_id = as.character(stop_id),
                                        stop_name = as.character(stop_name))]
    sp[, sys := NA_character_]
    for (i in seq_len(nrow(ov))) {
      hit <- is.na(sp$sys) & grepl(ov$stop_pattern[i], sp$stop_name,
                                   ignore.case = TRUE, useBytes = TRUE)
      sp[hit, sys := ov$system[i]]
    }
    marked <- sp[!is.na(sys)]
    if (nrow(marked) == 0) return(NULL)
    st <- as.data.table(g$stop_times)[, list(trip_id = as.character(trip_id),
                                             stop_id = as.character(stop_id))]
    tr <- as.data.table(g$trips)[, list(trip_id = as.character(trip_id),
                                        route_id = as.character(route_id))]
    ro <- as.data.table(g$routes)[, list(route_id = as.character(route_id),
                                         route_type = as.integer(route_type))]
    rs <- unique(merge(st, tr, by = "trip_id")[, list(route_id, stop_id)])
    rs <- merge(rs, sp[, list(stop_id, sys)], by = "stop_id", all.x = TRUE)
    n <- rs[, list(n = .N), by = "route_id"]
    h <- rs[!is.na(sys), list(n_hit = .N), by = c("route_id", "sys")]
    h <- merge(h, n, by = "route_id")[n_hit / n >= threshold]
    if (nrow(h) == 0) return(NULL)
    setorderv(h, c("route_id", "n_hit"), c(1L, -1L))
    h <- h[!duplicated(h$route_id)]
    h <- merge(h, ro, by = "route_id")
    nt <- tr[, list(trips = .N), by = "route_id"]
    h <- merge(h, nt, by = "route_id", all.x = TRUE)
    out <- h[, list(routes = .N, trips = sum(trips, na.rm = TRUE)),
             by = c("sys", "route_type")]
    out[, side := side]
    rm(g); gc(verbose = FALSE)
    out[]
  }
  a <- one(fo, "old"); b <- one(fn, "new")
  # rbindlist, not rbind: either side can be NULL when a feed contains no
  # marked system at all, and rbind() then dispatches to the data.frame
  # method and returns something := cannot be used on
  r <- data.table::rbindlist(list(a, b), fill = TRUE)
  if (nrow(r) == 0) return(NULL)
  # `feed` is this function's argument, so name the column explicitly rather
  # than relying on the self-referential form
  data.table::set(r, j = "feed", value = feed)
  r[]
}

message("Comparing feeds system by system")
res$systems <- rbindlist(lapply(FEED_PAIRS, function(f) {
  message("  ", f)
  feed_systems(f)
}), fill = TRUE)

# A mode appearing or vanishing entirely is the loudest possible signal, and
# route_type 6 should appear from nothing
res$mode_presence <- dcast(res$by_mode, route_type + mode ~ year,
                           value.var = "new")

saveRDS(res, OUT)
message("Written ", OUT)


cat("\n=== National", MEASURE, "by mode, before and after ===\n")
print(res$by_mode[, list(year, route_type, mode, old = round(old),
                         new = round(new), diff = round(diff), pct)],
      nrows = 200)

cat("\n=== Modes present after the rebuild (national tph) ===\n")
print(res$mode_presence, nrows = 50)

cat("\n=== How the change spreads across zones, by mode ===\n")
for (rt in sort(unique(res$spread$route_type))) {
  cat("\n-- route_type", rt, MODE_NAME[as.character(rt)], "--\n")
  print(res$spread[route_type == rt,
                   list(year, zones, pct_unchanged, fell, rose,
                        median_d, p05, p95, worst_fall, worst_rise)])
}

cat("\n=== Leytonstone, E01004440 ===\n")
print(res$leytonstone[order(route_type, year),
                      list(year, route_type, old = round(old, 1),
                           new = round(new, 1), d = round(d, 1))], nrows = 100)

cat("\n=== Each system's mode, old feed against new ===\n")
if (!is.null(res$systems) && nrow(res$systems) > 0) {
  w <- dcast(res$systems, feed + sys ~ side + route_type,
             value.var = "trips", fill = 0)
  print(w, nrows = 200)
} else {
  cat("no feed pair available\n")
}

cat("\n=== Largest movements, any mode ===\n")
print(res$movers_all)

cat("\n=== Largest movements, bus only (should be small) ===\n")
print(res$movers_bus)
