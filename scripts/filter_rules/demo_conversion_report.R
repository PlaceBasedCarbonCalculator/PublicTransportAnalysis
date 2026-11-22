# Demonstrate UK2GTFS 0.4.2's conversion report on one real TNDS region.
#
#   Rscript scripts/filter_rules/demo_conversion_report.R [region] [cores]
#
# Converts TNDS 2.5 <region>.zip from the 18 November 2026 snapshot with the
# pipeline's settings (file filter on, filter date 18 Nov, naptan_fill), applies
# gtfs_deduplicate_copies(), and writes the report to
# data/filter_rules/conversion_report_<region>/. The feed itself is not kept.
args <- commandArgs(TRUE)
region <- if (length(args) >= 1) args[1] else "EA"
cores <- if (length(args) >= 2) as.integer(args[2]) else 20L
source("R/config.R")
cfg <- load_cfg()
src <- file.path(cfg$data_root, "TransXChange", "data_20261118", "TNDSV2.5",
                 paste0(region, ".zip"))
naptan <- targets::tar_read(naptan)
cal <- targets::tar_read(txc_cal)
gtfs <- UK2GTFS::transxchange2gtfs(src, silent = TRUE, cal = cal, naptan = naptan,
                                   ncores = cores, scotland = "no", try_mode = TRUE,
                                   force_merge = TRUE, filter_duplicate_files = TRUE,
                                   filter_date = as.Date("2026-11-18"),
                                   stop_locations = "naptan_fill")
gtfs <- UK2GTFS::gtfs_deduplicate_copies(gtfs)
gtfs <- UK2GTFS::gtfs_clean(gtfs)
gtfs <- UK2GTFS::gtfs_deduplicate(gtfs)
out <- file.path("data", "filter_rules", paste0("conversion_report_", region))
print(UK2GTFS::write_conversion_report(gtfs, out))
print(UK2GTFS::conversion_report(gtfs))
