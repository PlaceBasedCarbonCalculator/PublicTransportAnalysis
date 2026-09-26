# Reconvert everything the gtfs_merge file_id bug touched, in stages.
#
# gtfs_merge() assigned file_id per table rather than per input feed, so a feed
# missing one optional table shifted the numbering of every later feed in that
# table alone. A TNDS snapshot's NCSD coach archive has no calendar_dates, so
# eight of the twelve regions had their cancellations applied to the preceding
# region's services - inflating cancelled trip-days by about two thirds on
# every weekday. Fixed in UK2GTFS 1e06562.
#
# gtfs_merge is reached from transxchange2gtfs() and from the region merges in
# convert_tnds_snapshot() and convert_bus_archive_year(), so every
# TransXChange-derived feed is affected. nptdr2gtfs() and atoc2gtfs() never
# call it, so the NPTDR and rail conversions are not - the NPTDR years here are
# rebuilt for a different reason: the operator-code rule for the London cable
# car was firing on an unrelated 2007-2011 operator reusing the code CAB
# (UK2GTFS 8f29e6e).
#
# The per-region cache was retired to gtfs/cache_stale_prefileidfix, because
# those conversions were merged with the buggy code too.
#
# Affected targets are on 30 workers rather than the default 10: changing a
# target's command invalidates it, which is free when it has to rebuild anyway.
#
#   1  2018-2025 TNDS, BODS coach, and the counts
#   2  2007-2011 NPTDR, and the counts (the CAB false positive)
#   3  2014-2017 Bus Archive, and the counts
#   4  the comparison and validation targets
#
# Resumable: targets caches every completed target. Run one stage at a time:
#   Rscript rebuild_fileid_fix.R 1
# or all of them in order:
#   Rscript rebuild_fileid_fix.R

STAGES <- list(
  `1` = c("tnds_20180515", "tnds_20191008", "tnds_20200701", "tnds_20211012",
          "tnds_20221102", "tnds_20231101", "tnds_20241004", "tnds_20251003",
          "bods_coach_2024", "bods_coach_2025",
          paste0("trips_", 2018:2025)),
  `2` = c(paste0("nptdr_", 2007:2011), paste0("trips_", 2007:2011)),
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
