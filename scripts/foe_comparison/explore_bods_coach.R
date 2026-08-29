# Can the BODS Coach dataset replace the coach services TNDS has stopped
# carrying?
#
# TNDS distributes national coach services in a separate NCSD archive inside
# each snapshot. That archive disappears after February 2025, and the coach
# content of the converted feeds collapses with it: 208 routes in the October
# 2024 snapshot, 22 in October 2025, 6 in July 2026
# (scripts/foe_comparison/coach_coverage.R).
#
# BODS publishes a standalone Coach dataset - TransXChange 2.4 and ATCO-CIF -
# on the same dates as the bus feeds. This converts it, reports what it
# contains, and checks how much of it TNDS already has, which is what decides
# whether it can be added to a year without double counting.
#
#   Rscript scripts/foe_comparison/explore_bods_coach.R 20251006
#
# Exploration only: nothing here writes a pipeline feed.

source("scripts/foe_comparison/foe_functions.R")
for (f in list.files("R", full.names = TRUE)) source(f)

args <- commandArgs(trailingOnly = TRUE)
snapshots <- if (length(args)) args else c("20241007", "20251006")

cfg <- load_cfg()
# The same inputs the pipeline's own TransXChange conversions use
cal <- txc_calendar()
naptan <- UK2GTFS::get_naptan()

TNDS_FOR <- c(`20241007` = "gtfs/tnds_20241004_merged.zip",
              `20251006` = "gtfs/tnds_20251003_merged.zip")

convert_coach <- function(snapshot) {
  src <- file.path(cfg$data_root, "OpenBusData/Coach", snapshot, "TxC-2.4.zip")
  if (!file.exists(src)) stop("no coach archive at ", src)
  out <- file.path("gtfs", "cache", paste0("bods_coach_", snapshot, ".zip"))
  if (file.exists(out)) {
    message("using cached ", out)
    return(UK2GTFS::gtfs_read(out))
  }
  message("Converting ", src)
  gtfs <- UK2GTFS::transxchange2gtfs(src, silent = TRUE, cal = cal,
                                     naptan = naptan, ncores = cfg$ncores,
                                     try_mode = TRUE, force_merge = TRUE)
  gtfs <- post_convert(gtfs, cfg$ncores)
  dir.create(dirname(out), showWarnings = FALSE, recursive = TRUE)
  write_repo_gtfs(gtfs, gsub("\\.zip$", "", basename(out)), dirname(out))
  UK2GTFS::gtfs_read(out)
}

describe <- function(gtfs, label) {
  rt <- merge(gtfs$routes[, c("route_id", "route_type", "route_short_name",
                              "agency_id")],
              as.data.frame(table(route_id = gtfs$trips$route_id),
                            stringsAsFactors = FALSE),
              by = "route_id", all.x = TRUE)
  rt$Freq[is.na(rt$Freq)] <- 0
  message("\n--- ", label, " ---")
  print(stats::aggregate(cbind(routes = route_id != "", trips = Freq) ~ route_type,
                         data = rt, FUN = sum))
  rt
}

for (snap in snapshots) {
  message("\n================ ", snap, " ================")
  coach <- convert_coach(snap)
  crt <- describe(coach, paste("BODS Coach", snap))

  agencies <- merge(coach$routes[, c("route_id", "agency_id")],
                    coach$agency[, c("agency_id", "agency_name")],
                    by = "agency_id", all.x = TRUE)
  message("operators in the coach feed:")
  print(sort(table(agencies$agency_name), decreasing = TRUE)[1:15])

  tnds_path <- TNDS_FOR[[snap]]
  if (!is.null(tnds_path) && file.exists(tnds_path)) {
    tnds <- UK2GTFS::gtfs_read(tnds_path)
    trt <- describe(tnds, paste("TNDS", basename(tnds_path)))

    # Which coach services does TNDS already carry? Compare on operator name
    # plus line name, which is what survives a change of source.
    key <- function(g) {
      a <- merge(g$routes[, c("route_id", "agency_id", "route_short_name")],
                 g$agency[, c("agency_id", "agency_name")], by = "agency_id",
                 all.x = TRUE)
      unique(toupper(paste(a$agency_name, a$route_short_name, sep = "|")))
    }
    coach_keys <- key(coach)
    tnds_keys <- key(tnds)
    overlap <- intersect(coach_keys, tnds_keys)
    message("\ncoach services in BODS feed: ", length(coach_keys))
    message("of which TNDS already carries (operator + line): ", length(overlap),
            sprintf("  (%.1f%%)", 100 * length(overlap) / length(coach_keys)))
    if (length(overlap)) print(utils::head(sort(overlap), 20))
  }
}
