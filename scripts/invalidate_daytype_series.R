# Put the whole series on the fixed txc_filter_files().
#
# post_convert() - which applies patch_naptan() - runs BEFORE the conversion
# cache is written, and convert_txc_cached() skips conversion entirely when
# the cache exists. So the package version and patch state are baked into
# each cache at write time and never revisited: deleting the cache is the
# only way a code fix reaches a feed.
#
# NPTDR and rail are untouched - txc_filter_files() is reachable only from
# transxchange2gtfs(). naptan/txc_cal/noc stay pinned (cue = never).
# gtfs/cache/coverage is left alone: it keys on each feed's mtime, so a
# reconverted year re-measures itself.
suppressMessages(library(targets))

# caches whose feeds must be reconverted
live <- file.path("gtfs", "cache", c(
  "tnds_20180515", "tnds_20191008", "tnds_20200701", "tnds_20211012",
  "tnds_20221102_v25", "tnds_20231101_v25", "tnds_20241004_v25",
  "tnds_20251003_v25", "tnds_20260726_v25",
  "bods_txc_20221102_full.zip", "bods_txc_20231101_full.zip",
  "bods_txc_20241007_full.zip", "bods_txc_20251006_full.zip",
  "bods_coach_20241007.zip", "bods_coach_20251006.zip",
  "bods_coach_20261003.zip",
  "busarchive_2014", "busarchive_2015", "busarchive_2016", "busarchive_2017"))

# pre-2.5 caches that tnds_edition() no longer resolves to; nothing reads them
stale <- file.path("gtfs", "cache", c(
  "tnds_20221102", "tnds_20231101", "tnds_20241004", "tnds_20251003",
  "tnds_20260726"))

# already converted with the fix - must NOT be touched
keep <- file.path("gtfs", "cache", c("tnds_20261002_v25",
                                     "bods_txc_20261003_full.zip",
                                     "coverage"))

sz <- function(p) {
  if (!file.exists(p)) return(NA_real_)
  if (dir.exists(p)) sum(file.size(list.files(p, recursive = TRUE,
                                              full.names = TRUE)), na.rm = TRUE)
  else file.size(p)
}
report <- function(ps, head) {
  cat("\n===", head, "===\n")
  tot <- 0
  for (p in ps) {
    s <- sz(p)
    cat(sprintf("  %-42s %s\n", p,
        if (is.na(s)) "absent" else paste0(round(s / 2^20), " MB")))
    if (!is.na(s)) tot <- tot + s
  }
  cat(sprintf("  -> %.1f GB\n", tot / 2^30))
  invisible(tot)
}
a <- report(live, "delete: reconvert these")
b <- report(stale, "delete: stale, nothing reads them")
report(keep, "keep: already built with the fix")
cat(sprintf("\ntotal to free: %.1f GB\n", (a + b) / 2^30))

stopifnot(!any(keep %in% c(live, stale)))
for (p in c(live, stale)) if (file.exists(p)) unlink(p, recursive = TRUE)
cat("\ndeleted. still present:",
    sum(file.exists(c(live, stale))), "of", length(c(live, stale)), "\n")
cat("kept, still present:", sum(file.exists(keep)), "of", length(keep), "\n")

redo <- c("tnds_20180515", "tnds_20191008", "tnds_20200701", "tnds_20211012",
          "tnds_20221102", "tnds_20231101", "tnds_20241004", "tnds_20251003",
          "tnds_20260726",
          "bods_txc_2022", "bods_txc_2023", "bods_txc_2024", "bods_txc_2025",
          "bods_coach_2024", "bods_coach_2025", "bods_coach_2026",
          "busarchive_2014", "busarchive_2015", "busarchive_2016",
          "busarchive_2017")
cat("\ninvalidating", length(redo), "conversion targets\n")
tar_invalidate(any_of(!!redo))

cat("\n=== outdated after invalidation ===\n")
od <- tar_outdated()
cat(length(od), "targets\n")
print(sort(od))
saveRDS(od, file.path("C:/Users/earmmor/AppData/Local/Temp/claude",
  "f--GitHub-PlaceBasedCarbonCalculator-PublicTransportAnalysis",
  "8d0009c3-2cc7-4dc5-ba41-23031b8f2076/scratchpad/outdated.Rds"))
