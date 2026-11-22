# Prototype: remove cross-file copies (UK2GTFS::gtfs_deduplicate_copies())
#
# The X6 and 439 doubled in TNDS 2.5 on 20 Nov 2026 because one timetable was
# published by two files that gtfs_deduplicate() cannot match (different
# operator names, different intermediate timings; see
# reports/stop_disagreement_cities_1120.md). UK2GTFS 0.4.2 adds a route-level
# rule for this. These functions apply it to the November 2026 conversions
# without touching them: they read the region caches the _nf targets already
# wrote, which are untrimmed - the rule needs each copy's real calendar start
# to tell the newer version from the older - apply the rule to the merged
# feed, and only then trim to the snapshot window.

#' Apply gtfs_deduplicate_copies() to a merged feed and save its report
#'
#' Both scopes are measured; the feed written uses `scope`.
#' @return the deduplicated gtfs object
apply_copies_rule <- function(gtfs, report_stem, scope = "trips") {
  other <- setdiff(c("trips", "route"), scope)
  alt <- UK2GTFS::gtfs_deduplicate_copies(gtfs, scope = other)
  rep_alt <- attr(alt, "copies_report")
  rm(alt)
  gtfs <- UK2GTFS::gtfs_deduplicate_copies(gtfs, scope = scope)
  rep <- attr(gtfs, "copies_report")
  dir.create(dirname(report_stem), showWarnings = FALSE, recursive = TRUE)
  data.table::fwrite(rep, paste0(report_stem, "_", scope, ".csv"))
  data.table::fwrite(rep_alt, paste0(report_stem, "_", other, ".csv"))
  gtfs
}

#' TNDS edition conversion with the cross-file copy rule
#'
#' Reads the region caches of convert_tnds_edition() (pass its output as
#' `after` so targets orders the two), merges them untrimmed, removes copies,
#' trims to +/- tnds_trim_days() and cleans, as convert_tnds_edition() does.
#' Output gtfs/tnds_<snapshot><tag>_xcopy_merged.zip; the copies report goes
#' to data/copies/.
convert_tnds_copies <- function(snapshot, tag, after, scope = "trips",
                                cfg = load_cfg()) {
  dir <- file.path(cfg$gtfs_dir, "cache", paste0("tnds_", snapshot, tag))
  zips <- list.files(dir, "\\.zip$", full.names = TRUE)
  if (!length(zips)) stop("No region caches in ", dir)
  message("Copies rule on ", length(zips), " region caches in ", dir)
  gtfs <- UK2GTFS::gtfs_merge(lapply(zips, UK2GTFS::gtfs_read), force = TRUE)
  gtfs <- apply_copies_rule(gtfs, file.path("data", "copies",
                                            paste0("tnds_", snapshot, tag)),
                            scope = scope)
  snap_date <- lubridate::ymd(snapshot)
  gtfs <- UK2GTFS::gtfs_trim_dates(gtfs,
                                   startdate = snap_date - tnds_trim_days(),
                                   enddate = snap_date + tnds_trim_days())
  gtfs <- UK2GTFS::gtfs_clean(gtfs)
  write_repo_gtfs(gtfs, paste0("tnds_", snapshot, tag, "_xcopy_merged"))
}

#' BODS TransXChange conversion with the cross-file copy rule
#'
#' Reads the untrimmed cache of convert_bods_txc_sl().
convert_bods_txc_copies <- function(snapshot, after, scope = "trips",
                                    stop_locations = "naptan_fill",
                                    cfg = load_cfg()) {
  tag <- stop_location_tag(stop_locations)
  cache <- file.path(cfg$gtfs_dir, "cache",
                     paste0("bods_txc_", snapshot, tag, "_full.zip"))
  gtfs <- UK2GTFS::gtfs_read(cache)
  gtfs <- apply_copies_rule(gtfs, file.path("data", "copies",
                                            paste0("bods_txc_", snapshot, tag)),
                            scope = scope)
  snap_date <- lubridate::ymd(snapshot)
  gtfs <- UK2GTFS::gtfs_trim_dates(gtfs, startdate = snap_date - 31,
                                   enddate = snap_date + 31)
  write_repo_gtfs(gtfs, paste0("bods_txc_", snapshot, tag, "_xcopy"))
}

#' The 20 Nov comparison with and without the copy rule
stop_city_comparisons_xcopy <- function() {
  data.table::data.table(
    map = c("london_tnds25", "london_tnds25xc", "wm_tnds25", "wm_tnds25xc",
            "wm_bods_txc", "wm_bods_txcxc"),
    city = c("London", "London", rep("West Midlands", 4)),
    txc = c("tnds25", "tnds25xc", "tnds25", "tnds25xc", "bods_txc",
            "bods_txcxc"),
    label = c("London: TNDS 2.5", "London: TNDS 2.5 + copy rule",
              "West Midlands: TNDS 2.5", "West Midlands: TNDS 2.5 + copy rule",
              "West Midlands: BODS TransXChange",
              "West Midlands: BODS TransXChange + copy rule"))
}

#' Render reports/filtering_rules_overview.Rmd
#'
#' `...` carries file dependencies (the copies feeds, whose reports the Rmd
#' reads from data/copies/, and the example extract) so targets re-renders
#' when they change.
render_filter_rules_report <- function(rmd, xcopy_path, zones_path = NULL, ...,
                                       cfg = load_cfg()) {
  dir.create(cfg$report_dir, showWarnings = FALSE, recursive = TRUE)
  env <- new.env(parent = globalenv())
  env$xcopy_path <- normalizePath(xcopy_path)
  env$map_zones_path <- if (!is.null(zones_path)) map_zones_file(zones_path)
  old_wd <- setwd(cfg$report_dir)
  on.exit(setwd(old_wd), add = TRUE)
  out <- "filtering_rules_overview.md"
  knitr::knit(input = basename(rmd), output = out, envir = env, quiet = TRUE)
  file.path(cfg$report_dir, out)
}
