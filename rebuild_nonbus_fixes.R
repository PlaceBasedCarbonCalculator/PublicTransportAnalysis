# Rebuild what the September 2026 non-bus fixes reach, beyond the NPTDR years.
#
# Three defects were fixed in UK2GTFS (PR #88, fc9915f), and reinstalling the
# package invalidates nothing: targets hashes this repo's code, not the
# library. The full tar_make() run of 28 September rebuilt the NPTDR years,
# because convert_nptdr_year() itself changed to pass the archive year, and it
# skipped everything else - all eight rail_* conversions were marked `skipped`
# in that run's own progress file, straight after the reinstall. So one of the
# three fixes landed and two did not.
#
#   Manchester trams 2004-06   nptdr2gtfs() + the mode table.  Landed: the
#                              NPTDR conversions and counts were rebuilt.
#
#   Lancashire `LUL`           apply_standard_modes(), called inside
#                              transxchange2gtfs(). Needs the TransXChange
#                              feed reconverting. STAGE 1.
#
#   station/platform doubling  gtfs_deduplicate(), called by read_feed() at
#                              COUNTING time, so the feeds are fine and only
#                              the counts have to re-run. STAGE 2.
#
# Both remaining stages are far smaller than the earlier rebuilds, because the
# scope was measured rather than assumed:
#
#   Stage 1 reconverts two Bus Archive years, reusing 72 of their 80 cached
#   regional conversions. `LUL` is Lancashire United Ltd in the four NW weekly
#   files of 2016 and of 2017 and nowhere else in the archive, so those eight
#   are the only ones holding the wrong route_type. The rest are untouched.
#
#   Stage 2 recounts 2015-2023 and no other year. A station-level NAPTAN code
#   whose platform children carry the same name is what the deduplication fix
#   canonicalises, and counting those in each feed gives 15 stations in
#   2015-2017, 16 in 2018-2023, and none at all in 2014, 2024 or 2025 - NAPTAN
#   stopped issuing the station-level code in 2024. So 2014, 2024 and 2025
#   cannot change and are left alone; 2004-2011 were already recounted with
#   the fixed package on 28 September.
#
# Stage 3 re-runs the non-bus audit, which takes every feed as a dependency
# precisely so that a reconversion re-runs it.
#
# Requires the fixed UK2GTFS to be INSTALLED, not just checked out:
#   remotes::install_local("../../ITSleeds/UK2GTFS", force = TRUE)
# Do that with no pipeline running, and check
# packageDescription("UK2GTFS")$Built afterwards.
#
# Resumable: targets caches every completed target. Run one stage at a time:
#   Rscript rebuild_nonbus_fixes.R 1
# or all of them in order:
#   Rscript rebuild_nonbus_fixes.R

STAGES <- list(
  `1` = c("busarchive_2016", "busarchive_2017"),
  `2` = paste0("trips_", 2015:2023),
  `3` = c("non_bus", "non_bus_report")
)

# The regional caches that hold the misclassified routes, found by asking each
# cached feed who `LUL` is rather than trusting that it is always the NW file.
LUL_YEARS <- c(2016, 2017)

args <- commandArgs(trailingOnly = TRUE)
want <- if (length(args) == 0) names(STAGES) else args
stopifnot(all(want %in% names(STAGES)))

dir.create("logs", showWarnings = FALSE)

#' Refuse to start on top of a running pipeline
#'
#' Two tar_make() processes over one metadata file is a good way to lose a
#' day's work. targets records the pid of the process that owns the cache.
stop_if_pipeline_running <- function() {
  f <- "_targets/meta/process"
  if (!file.exists(f)) return(invisible(NULL))
  rec <- readLines(f, warn = FALSE)
  pid <- sub("^pid[|]", "", grep("^pid[|]", rec, value = TRUE))
  if (length(pid) != 1 || !nzchar(pid)) return(invisible(NULL))
  alive <- tryCatch({
    out <- system2("tasklist", c("/FI", shQuote(paste("PID eq", pid))),
                   stdout = TRUE, stderr = FALSE)
    any(grepl(paste0("\\b", pid, "\\b"), out))
  }, error = function(e) NA)
  if (isTRUE(alive)) {
    stop("a pipeline is already running in this cache (pid ", pid,
         "). Wait for it to finish.", call. = FALSE)
  }
  invisible(NULL)
}

#' Retire the cached regional conversions that name LUL as a bus operator
#'
#' convert_bus_archive_year() caches each weekly regional conversion, and
#' apply_standard_modes() runs inside that conversion, so the wrong
#' route_type is baked into the cache. Moved rather than deleted, the way the
#' earlier rebuilds retired theirs, so the old state stays inspectable.
#'
#' @param years Bus Archive years to check
#' @return invisibly, the files moved
retire_lul_caches <- function(years) {
  dest_root <- file.path("gtfs", "cache_stale_prelulguard")
  moved <- character(0)
  for (y in years) {
    dir <- file.path("gtfs", "cache", paste0("busarchive_", y))
    if (!dir.exists(dir)) next
    zips <- list.files(dir, pattern = "[.]zip$", full.names = TRUE)
    holds_lul <- vapply(zips, function(z) {
      ag <- tryCatch(readLines(unz(z, "agency.txt"), warn = FALSE),
                     error = function(e) character(0))
      any(grepl('"LUL"', ag, fixed = TRUE))
    }, logical(1), USE.NAMES = FALSE)
    hit <- zips[holds_lul]
    if (!length(hit)) {
      message("  ", y, ": no cached feed names LUL, nothing to retire")
      next
    }
    dest <- file.path(dest_root, paste0("busarchive_", y))
    dir.create(dest, recursive = TRUE, showWarnings = FALSE)
    ok <- file.rename(hit, file.path(dest, basename(hit)))
    if (!all(ok)) {
      stop("could not move: ", paste(hit[!ok], collapse = ", "))
    }
    message("  ", y, ": retired ", length(hit), " of ", length(zips),
            " cached regional feeds (", paste(basename(hit), collapse = ", "),
            ")")
    moved <- c(moved, hit)
  }
  invisible(moved)
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
stop_if_pipeline_running()

message(Sys.time(), "  UK2GTFS ", as.character(utils::packageVersion("UK2GTFS")),
        ", built ", packageDescription("UK2GTFS")$Built)

for (st in want) {
  nms <- STAGES[[st]]
  message("\n", strrep("=", 70))
  message(Sys.time(), "  STAGE ", st, ": ", length(nms), " targets")
  message(strrep("=", 70), "\n")
  if (st == "1") retire_lul_caches(LUL_YEARS)
  invalidate_by_meta(nms)
  # tar_make() evaluates `names` with tidyselect inside the pipeline's own
  # environment, where a local variable is not visible, so the vector is
  # injected into the call as a literal
  eval(bquote(targets::tar_make(names = tidyselect::all_of(.(nms)))))
  message("\n", Sys.time(), "  STAGE ", st, " complete\n")
}

message(Sys.time(), "  all requested stages finished")
