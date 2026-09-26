# Rebuild everything converted while the mode rules could not fire.
#
# UK2GTFS 5b0cfa5 "Name the stops before applying the mode rules" fixes an
# ordering defect introduced by 39da3f5 "transxchange speedup": the NAPTAN
# join moved to AFTER apply_standard_modes(), so the thirteen rules that
# recognise a system by its stops' names matched nothing, silently. The
# Docklands Light Railway stayed heavy rail, the Glasgow Subway stayed a tram
# and the Gatwick shuttle stayed metro.
#
# Only TXC-derived feeds converted after the speedup was installed on
# 2026-09-19 are affected. Confirmed feed by feed in
# scripts/metro_duplicates/mode_consistency.R:
#
#   correct (old converter)  tnds_20180515 20191008 20200701 20241004
#   wrong   (new converter)  tnds_20211012 20221102 20231101 20251003
#                            tnds_20260726, busarchive_2014-2017,
#                            bods_txc_2022-2026, bods_coach_2024-2025
#   unaffected (own path)    nptdr_2004-2011, all rail CIF
#
# convert_txc_cached() skips conversion when the cache zip exists, so the
# affected caches have to be deleted as well as the targets invalidated -
# invalidating alone would rebuild the target from the same stale cache.
#
# Cache deletion is done by the mtime of each zip rather than by naming
# snapshots, because tnds_20211012 is split: ten of its twelve regions were
# converted after the speedup and two before. A snapshot half-converted by
# each version is exactly the inconsistency being fixed, so the whole
# snapshot goes.
#
# Run from the repo root:
#   Rscript rebuild_mode_order_fix.R          # all stages
#   Rscript rebuild_mode_order_fix.R 2        # one stage

SPEEDUP_INSTALLED <- as.POSIXct("2026-09-19 15:00:00", tz = "")

STAGES <- list(
  # conversions, longest first so the tail is short
  `1` = c("busarchive_2014", "busarchive_2015", "busarchive_2016",
          "busarchive_2017",
          "tnds_20211012", "tnds_20221102", "tnds_20231101", "tnds_20251003",
          "tnds_20260726",
          "bods_coach_2024", "bods_coach_2025",
          "bods_txc_2022", "bods_txc_2023", "bods_txc_2024", "bods_txc_2025",
          "bods_txc_2026"),
  # counts. 2024 is in the list because it takes coach from bods_coach_2024,
  # even though its TNDS snapshot is one of the correct ones.
  `2` = c("trips_2014", "trips_2015", "trips_2016", "trips_2017",
          "trips_2021", "trips_2022", "trips_2023", "trips_2024",
          "trips_2025"),
  # the reports built on top of them
  `3` = c("near_duplicates", "near_duplicates_report",
          "pdf_validation", "pdf_validation_report",
          "lsoa_gap", "lsoa_gap_report",
          paste0("comparison_", 2022:2026), "comparison_report")
)

args <- commandArgs(trailingOnly = TRUE)
want <- if (length(args) == 0) names(STAGES) else args
stopifnot(all(want %in% names(STAGES)))

dir.create("logs", showWarnings = FALSE)

# ---- clear the stale caches, once, before any stage runs -----------------
if ("1" %in% want) {
  zips <- list.files("gtfs/cache", pattern = "[.]zip$", full.names = TRUE,
                     recursive = TRUE)
  stale <- zips[file.mtime(zips) > SPEEDUP_INSTALLED]
  # a partly converted snapshot must go entirely, or the rebuilt feed mixes
  # two converters' output in one file
  snap_dirs <- unique(dirname(stale))
  stale <- unique(c(stale,
                    list.files(snap_dirs[snap_dirs != "gtfs/cache"],
                               pattern = "[.]zip$", full.names = TRUE)))
  message(Sys.time(), "  removing ", length(stale), " stale cache files (",
          round(sum(file.size(stale)) / 2^30, 2), " GB)")
  print(table(sub("^gtfs/cache/", "", dirname(stale))))
  ok <- file.remove(stale)
  if (!all(ok)) stop("could not remove: ",
                     paste(stale[!ok], collapse = ", "))
  message(Sys.time(), "  caches cleared")
}

#' Drop targets from the metadata so the next tar_make() rebuilds them
#'
#' tar_invalidate() segfaults on this machine when it is called more than
#' once in a session, so the record is removed by rewriting the metadata
#' file. meta is pipe-delimited with `name` first, one row per target, and a
#' target with no row is simply one targets has never built.
#'
#' @param nms target names to forget
#' @return invisibly, the number of rows removed
invalidate_by_meta <- function(nms) {
  meta <- "_targets/meta/meta"
  if (!file.exists(meta)) return(invisible(0L))
  bak <- paste0(meta, ".bak_", format(Sys.time(), "%Y%m%d_%H%M%S"))
  file.copy(meta, bak)
  lines <- readLines(meta, warn = FALSE)
  keep <- c(TRUE, !(sub("[|].*$", "", lines[-1]) %in% nms))
  writeLines(lines[keep], meta)
  n <- sum(!keep)
  message("  invalidated ", n, " of ", length(nms),
          " targets (backup: ", basename(bak), ")")
  invisible(n)
}

# ---- invalidate, then build ---------------------------------------------
for (st in want) {
  nms <- STAGES[[st]]
  message("\n", strrep("=", 70))
  message(Sys.time(), "  STAGE ", st, ": ", length(nms), " targets")
  message(strrep("=", 70), "\n")
  invalidate_by_meta(nms)
  # tar_make() evaluates `names` with tidyselect inside the pipeline's own
  # environment, where a local variable is not visible, so the vector is
  # injected into the call as a literal
  eval(bquote(targets::tar_make(names = tidyselect::all_of(.(nms)))))
  message("\n", Sys.time(), "  STAGE ", st, " complete\n")
}

message(Sys.time(), "  all requested stages finished")
