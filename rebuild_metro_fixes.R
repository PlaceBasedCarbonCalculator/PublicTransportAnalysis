# Reconvert everything with the fixed UK2GTFS, in stages.
#
# All seven fixes in reports/metro_duplicate_copies.md change the *conversion*,
# not the counting, so every feed has to be rebuilt from raw data before any
# output changes. That is about 135 hours of compute, so this runs in stages,
# most-affected first, and each stage leaves a usable set of outputs behind.
#
#   1  2018-2025: TNDS, rail CIF, BODS coach, and the counts.  ~31 h
#      The metro defect lives entirely here, and so does Fix D.
#   2  2004-2011: NPTDR, and the counts.                       ~15 h
#      Fix F moves the Underground out of the bus totals in 2004 and sorts
#      the trams from the metros throughout.
#   3  2014-2017: Bus Archive, and the counts.                 ~71 h
#      Bus only, so only Fixes A and C can reach it. Slowest and least
#      affected, hence last.
#   4  the comparison and validation targets that hang off the feeds.
#
# Resumable: targets caches every completed target, so re-running picks up
# where it stopped. Run one stage at a time:
#   Rscript rebuild_metro_fixes.R 1
# or all of them in order:
#   Rscript rebuild_metro_fixes.R

STAGES <- list(
  `1` = c(paste0("rail_", 2018:2024), "rail_rdp_2025",
          "tnds_20180515", "tnds_20191008", "tnds_20200701", "tnds_20211012",
          "tnds_20221102", "tnds_20231101", "tnds_20241004", "tnds_20251003",
          "bods_coach_2024", "bods_coach_2025",
          paste0("trips_", 2018:2025)),
  `2` = c(paste0("nptdr_", 2004:2011), paste0("trips_", 2004:2011)),
  `3` = c(paste0("busarchive_", 2014:2017), paste0("trips_", 2014:2017)),
  `4` = c("tnds_20260726", paste0("bods_txc_", 2022:2026),
          "near_duplicates", "near_duplicates_report",
          "pdf_validation", "pdf_validation_report",
          "lsoa_gap", "lsoa_gap_report",
          paste0("comparison_", 2022:2026), "comparison_report")
)

args <- commandArgs(trailingOnly = TRUE)
want <- if (length(args) == 0) names(STAGES) else args
stopifnot(all(want %in% names(STAGES)))

dir.create("logs", showWarnings = FALSE)

for (st in want) {
  nms <- STAGES[[st]]
  message("\n", strrep("=", 70))
  message(Sys.time(), "  STAGE ", st, ": ", length(nms), " targets")
  message(strrep("=", 70), "\n")
  # tar_make() evaluates `names` with tidyselect inside the pipeline's own
  # environment, where a local variable is not visible, so the vector is
  # injected into the call as a literal
  eval(bquote(targets::tar_make(names = tidyselect::all_of(.(nms)))))
  message("\n", Sys.time(), "  STAGE ", st, " complete\n")
}

message(Sys.time(), "  all requested stages finished")
