# Rebuild the four snapshots that were already correct, so the whole series
# comes from one converter.
#
# WHY THIS IS NOT A BUG FIX
#
# tnds_20180515, 20191008, 20200701 and 20241004 were converted before the
# transxchange speedup was installed on 2026-09-19, so their NAPTAN join ran
# per file and ahead of apply_standard_modes(). Their modes are correct - the
# Docklands Light Railway is metro, the Glasgow Subway is metro, the Gatwick
# shuttle is a tram - and mode_consistency.R confirms it feed by feed.
#
# What they do NOT share with the rest of the series is the converter. The
# measured difference is small: reconverting East Anglia 2018 under the new
# version gave byte-identical routes, trips, calendar, calendar_dates and all
# 880,860 stop_times, and differed in 4 stops of 13,102 - all of them
# naptan_replace entries, where the new version keeps the fuller NAPTAN name
# and ~0.2 m more coordinate precision.
#
# That difference cannot move a mode (none of the four names match any mode
# pattern, and a reassignment needs 80% of a route's stops) and cannot move a
# count. It is rebuilt anyway because a series assembled from two converters
# is the exact shape of the defect that was just fixed, and 10 hours is a
# cheap price for not having to argue that case again.
#
# PRECONDITION
#
# Run only after rebuild_mode_order_fix.R has finished cleanly AND the four
# verification harnesses report no new problems:
#   scripts/metro_duplicates/check_fileid_fix.R    invariant holds everywhere
#   scripts/metro_duplicates/mode_consistency.R    no system has two modes
#   scripts/metro_duplicates/compare_rebuild.R     no unexplained movement
#   scripts/metro_duplicates/verify_fixes.R        the metro fixes still hold
#
# Nothing here fixes anything, so running it on top of an unresolved problem
# would only spend ten hours making that problem uniform.
#
# Run from the repo root:
#   Rscript rebuild_converter_uniformity.R

SNAPSHOTS <- c("tnds_20180515", "tnds_20191008", "tnds_20200701",
               "tnds_20241004")

STAGES <- list(
  `1` = SNAPSHOTS,
  `2` = c("trips_2018", "trips_2019", "trips_2020", "trips_2024"),
  # pdf_validation, near_duplicates and lsoa_gap read tnds_20260726 and the
  # 2026 comparison only, so none of them is touched by these four. The 2024
  # source comparison is: cmp_2024_tnds reads tnds_20241004, and
  # comparison_report aggregates every year.
  `3` = c("comparison_2024", "comparison_report")
)

args <- commandArgs(trailingOnly = TRUE)
want <- if (length(args) == 0) names(STAGES) else args
stopifnot(all(want %in% names(STAGES)))

dir.create("logs", showWarnings = FALSE)

#' Drop targets from the metadata so the next tar_make() rebuilds them
#'
#' tar_invalidate() segfaults on this machine when called more than once in a
#' session, so the record is removed by rewriting the metadata file. meta is
#' pipe-delimited with `name` first, and a target with no row is simply one
#' targets has never built.
invalidate_by_meta <- function(nms) {
  meta <- "_targets/meta/meta"
  if (!file.exists(meta)) return(invisible(0L))
  bak <- paste0(meta, ".bak_", format(Sys.time(), "%Y%m%d_%H%M%S"))
  file.copy(meta, bak)
  lines <- readLines(meta, warn = FALSE)
  keep <- c(TRUE, !(sub("[|].*$", "", lines[-1]) %in% nms))
  writeLines(lines[keep], meta)
  message("  invalidated ", sum(!keep), " of ", length(nms),
          " targets (backup: ", basename(bak), ")")
  invisible(sum(!keep))
}

# ---- clear these four snapshots' caches ---------------------------------
# convert_txc_cached() skips conversion whenever the cache zip exists, so an
# invalidated target would otherwise be rebuilt from the same old-converter
# feed and nothing would change.
if ("1" %in% want) {
  dirs <- file.path("gtfs/cache", SNAPSHOTS)
  dirs <- dirs[dir.exists(dirs)]
  zips <- list.files(dirs, pattern = "[.]zip$", full.names = TRUE)
  if (length(zips) == 0) {
    message(Sys.time(), "  no cached regions to remove")
  } else {
    message(Sys.time(), "  removing ", length(zips), " cache files (",
            round(sum(file.size(zips)) / 2^30, 2), " GB)")
    print(table(basename(dirname(zips))))
    ok <- file.remove(zips)
    if (!all(ok)) stop("could not remove: ",
                       paste(zips[!ok], collapse = ", "))
  }
}

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
