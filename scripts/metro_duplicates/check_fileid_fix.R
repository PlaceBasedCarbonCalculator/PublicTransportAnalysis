# Did the gtfs_merge() file_id fix hold, in every snapshot?
#
# gtfs_merge() used to number file_id per TABLE, over only the feeds that
# contained that table. The NCSD coach archive carries no calendar_dates, so
# every region after it had its cancellations applied to the PRECEDING
# region's services.
#
# The invariant that catches it needs no reference data: a merge moves rows
# between feeds but must not create or destroy cancelled trip-days. So
#
#     sum over regions of (cancelled trip-days)  ==  merged cancelled trip-days
#
# must hold exactly. Before the fix it did not: 2018 gave 238,428 summed
# against 391,769 merged.
#
# This checks the invariant for every TNDS snapshot the pipeline built, which
# the original diagnosis never did - it only ever measured 2018.
#
# Run from the repo root:
#   Rscript scripts/metro_duplicates/check_fileid_fix.R

suppressPackageStartupMessages({
  library(data.table)
})
for (f in list.files("R", full.names = TRUE, pattern = "[.][Rr]$")) source(f)

OUT <- "data/fileid_fix_check.Rds"

# snapshot -> the counting window's reference date, from the pipeline's own
# configuration rather than a second copy of the mapping
cfg <- load_cfg()
snaps <- list.dirs("gtfs/cache", full.names = FALSE, recursive = FALSE)
snaps <- grep("^tnds_", snaps, value = TRUE)

ref_of <- function(snap) as.Date(sub("^tnds_", "", snap), format = "%Y%m%d")

#' Cancelled trip-days in one feed, by day of week
#'
#' Trip-days, not calendar_dates rows: services differ enormously in size, and
#' a service-level count hid the whole effect on the first pass through this
#' investigation.
#'
#' @param g a gtfs list
#' @return a named integer vector, one entry per weekday
cancelled_trip_days <- function(g) {
  if (is.null(g$calendar_dates) || nrow(g$calendar_dates) == 0) {
    return(setNames(integer(7), c("Mon", "Tue", "Wed", "Thu", "Fri",
                                  "Sat", "Sun")))
  }
  cd <- as.data.table(g$calendar_dates)[exception_type == 2]
  if (nrow(cd) == 0) {
    return(setNames(integer(7), c("Mon", "Tue", "Wed", "Thu", "Fri",
                                  "Sat", "Sun")))
  }
  cd[, sid := as.character(service_id)]
  d <- as.character(cd$date)
  dd <- as.Date(d, format = "%Y%m%d")
  if (all(is.na(dd))) dd <- as.Date(cd$date)
  cd[, wday := ((as.integer(dd) + 3L) %% 7L) + 1L]
  n <- as.data.table(g$trips)[, list(n = .N),
                              by = list(sid = as.character(service_id))]
  z <- merge(cd, n, by = "sid", all.x = TRUE)
  z[is.na(n), n := 0L]
  out <- z[, list(v = sum(n)), by = "wday"]
  v <- setNames(integer(7), c("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"))
  v[out$wday] <- out$v
  v
}

read_trimmed <- function(path, ref) {
  g <- UK2GTFS::gtfs_read(path)
  UK2GTFS::gtfs_trim_dates(g, startdate = ref - tnds_trim_days(),
                           enddate = ref + tnds_trim_days())
}

rows <- list()
for (snap in snaps) {
  ref <- ref_of(snap)
  merged <- file.path("gtfs", paste0(snap, "_merged.zip"))
  regions <- list.files(file.path("gtfs/cache", snap), pattern = "[.]zip$",
                        full.names = TRUE)
  if (!file.exists(merged) || length(regions) == 0) {
    message(snap, ": skipped")
    next
  }
  message(snap, ": ", length(regions), " regions")

  per <- lapply(regions, function(p) {
    g <- read_trimmed(p, ref)
    has_cd <- !is.null(g$calendar_dates) && nrow(g$calendar_dates) > 0
    v <- cancelled_trip_days(g)
    trips <- nrow(g$trips)
    rm(g); gc(verbose = FALSE)
    list(region = sub("[.]zip$", "", basename(p)), has_cd = has_cd,
         trips = trips, v = v)
  })
  summed <- Reduce(`+`, lapply(per, `[[`, "v"))
  trips_regions <- sum(vapply(per, `[[`, numeric(1), "trips"))
  gaps <- vapply(per, `[[`, logical(1), "has_cd")
  gap_names <- vapply(per, `[[`, character(1), "region")[!gaps]

  gm <- read_trimmed(merged, ref)
  mv <- cancelled_trip_days(gm)
  trips_merged <- nrow(gm$trips)
  rm(gm); gc(verbose = FALSE)

  rows[[snap]] <- data.table(
    snapshot = snap,
    regions = length(regions),
    feeds_without_calendar_dates = length(gap_names),
    which_gap = paste(gap_names, collapse = ","),
    day = names(summed),
    summed = as.integer(summed),
    merged = as.integer(mv),
    trips_regions = trips_regions,
    trips_merged = trips_merged)
}

res <- rbindlist(rows, fill = TRUE)
res[, diff := merged - summed]
res[, pct := ifelse(summed > 0, round(100 * diff / summed, 2), NA_real_)]
saveRDS(res, OUT)
message("Written ", OUT)

cat("\n=== Cancelled trip-days: regions summed vs merged ===\n")
cat("A merge redistributes cancellations; it must not create them.\n")
cat("diff must be 0 on every row.\n\n")
print(dcast(res, snapshot + regions + feeds_without_calendar_dates +
              which_gap ~ day, value.var = "diff"), nrows = 60)

cat("\n=== Wednesday only, the published measure's day ===\n")
print(res[day == "Wed", list(snapshot, which_gap, summed, merged, diff, pct)])

cat("\n=== Trips: regions summed vs merged (dedup removes some) ===\n")
print(unique(res[, list(snapshot, trips_regions, trips_merged,
                        removed = trips_regions - trips_merged)]))

bad <- res[diff != 0]
cat("\nrows where the invariant fails: ", nrow(bad), "\n")
if (nrow(bad) > 0) {
  print(bad[, list(snapshot, day, summed, merged, diff, pct)])
  cat("\nFAIL - the file_id defect is still present\n")
} else {
  cat("PASS - every snapshot conserves cancelled trip-days across the merge\n")
}
