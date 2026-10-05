# Exactly how many files the overlap patch gives back, per region.
#
# scripts/filter_effect_check.R compares the old conversion with the new one,
# but two things changed at once there: the input moved from the TransXChange
# 2.1 edition to 2.5, and the overlap rule was patched. Some of the files 2.5
# removes are files the rule would have removed anyway, so the difference in
# removals is an upper bound on the patch, not a measurement of it.
#
# This isolates the patch. The last run on the old pipeline logged, per
# regional archive, how many files the UNPATCHED rule removed from the 2.1
# edition. Running the PATCHED rule over the same 2.1 archives and comparing
# removals changes one thing only, so the difference is the patch and nothing
# else. The investigation predicted it from a Python port of the rule
# (reports/tnds_conversion_investigation.md, section 1): 110 files restored
# nationally, 91 of them live in the window. This is the same quantity
# measured in R, by the code that actually runs.
#
# It only reads TransXChange headers, so it is far cheaper than a conversion,
# but it is not free - about four minutes a region - and it is meant to run
# alongside a rebuild, so it defaults to a modest worker count.
#
# Usage: Rscript scripts/patch_effect_exact.R [snapshot] [ncores] [regions...]

suppressMessages(library(data.table))
source("R/config.R")
source("R/convert.R")

args <- commandArgs(TRUE)
snapshot <- if (length(args) >= 1) args[1] else "20260726"
ncores <- if (length(args) >= 2) as.integer(args[2]) else 6L
only <- if (length(args) >= 3) args[-(1:2)] else NULL

cfg <- load_cfg()
src <- file.path(cfg$data_root, "TransXChange", paste0("data_", snapshot))
snap_date <- lubridate::ymd(snapshot)

# The 2.1 archives, which is what the old log's removals were counted on.
zips <- list.files(src, pattern = "[.]zip$", full.names = TRUE)
zips <- zips[!grepl("NCSD", basename(zips), ignore.case = TRUE)]
if (!is.null(only)) {
  zips <- zips[sub("[.]zip$", "", basename(zips)) %in% only]
}
if (!length(zips)) stop("no 2.1 regional archives found in ", src)

message("UK2GTFS built: ", packageDescription("UK2GTFS")$Built)
message(length(zips), " regional archives, ", ncores, " workers")

work <- file.path(tempdir(), paste0("patchfx_", snapshot))
dir.create(work, recursive = TRUE, showWarnings = FALSE)

res <- rbindlist(lapply(zips, function(z) {
  region <- sub("[.]zip$", "", basename(z))
  d <- file.path(work, region)
  if (!dir.exists(d)) {
    dir.create(d, recursive = TRUE, showWarnings = FALSE)
    message("unzipping ", region)
    unzip(z, exdir = d)
  }
  f <- list.files(d, "[.]xml$", full.names = TRUE, recursive = TRUE)
  message("filtering ", region, ": ", length(f), " files")
  t0 <- Sys.time()
  kept <- UK2GTFS::txc_filter_files(f, date = snap_date, ncores = ncores)
  message("  kept ", length(kept), " in ",
          round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1),
          " min")
  unlink(d, recursive = TRUE)
  data.table(snapshot = snapshot, region = region, edition = "2.1",
             files = length(f), kept_patched = length(kept),
             removed_patched = length(f) - length(kept))
}))

setorder(res, region)
cat("\n=== patched rule on the 2.1 archives ===\n")
print(res)

# Join the unpatched removals from the previous run's log, if it is still
# there. The scan is re-implemented rather than borrowed from
# scripts/filter_effect_check.R: that script runs its analysis at top level,
# so sourcing it for one function would run the whole thing.
old <- "logs/rerun_20261002.log"

# `want` not `snapshot`: inside the data.table call below a parameter named
# after a column resolves to the column, and `snapshot == snapshot` is then
# always true.
scan_removed <- function(path, want) {
  raw <- readBin(path, "raw", file.size(path))
  enc <- if (sum(raw[seq_len(min(2000, length(raw)))] == as.raw(0)) > 100) {
    "UTF-16LE"
  } else "UTF-8"
  l <- strsplit(iconv(list(raw), from = enc, to = "UTF-8"), "\r?\n")[[1]]
  l <- l[grepl("Converting .*[.]zip|Removed [0-9]+ superseded", l)]
  out <- list(); cur <- NULL
  for (x in l) {
    if (grepl("Converting", x)) {
      m <- regmatches(x, regexpr("data_[0-9]{8}(/TNDSV2[.]5)?/[A-Za-z]+[.]zip", x))
      cur <- if (length(m)) m else NA_character_
    } else if (!is.null(cur) && !is.na(cur)) {
      out[[length(out) + 1L]] <- data.table(
        snapshot = sub("^data_([0-9]{8}).*$", "\\1", cur),
        edition = ifelse(grepl("TNDSV2[.]5", cur), "2.5", "2.1"),
        region = sub("^.*/([A-Za-z]+)[.]zip$", "\\1", cur),
        removed_unpatched = as.integer(sub(".*Removed ([0-9]+) superseded.*",
                                           "\\1", x)))
      cur <- NULL
    }
  }
  if (!length(out)) return(NULL)
  r <- rbindlist(out)
  r[snapshot == want & edition == "2.1"]
}

if (file.exists(old)) {
  u <- scan_removed(old, snapshot)
  if (!is.null(u) && nrow(u)) {
    m <- merge(res, u[, list(region, removed_unpatched)], by = "region")
    m[, restored := removed_unpatched - removed_patched]
    cat("\n=== the patch alone, same 2.1 input ===\n")
    cat("restored = files the unpatched rule removed and the patched one keeps\n\n")
    print(m[, list(region, files, removed_unpatched, removed_patched, restored)])
    cat("\nTOTAL restored:", sum(m$restored), "files over", nrow(m),
        "regions\n")
    # Merged with whatever is already there rather than overwritten. Each
    # region takes minutes, so this is normally run a few at a time, and a
    # plain save silently threw away the earlier runs - the file ended up
    # holding 8 of the 11 regions and a national total that was wrong by the
    # three biggest.
    out <- "data/patch_effect_exact.Rds"
    if (file.exists(out)) {
      prev <- as.data.table(readRDS(out))
      m <- unique(rbindlist(list(m, prev), fill = TRUE),
                  by = c("snapshot", "region"))
    }
    setorderv(m, c("snapshot", "restored"), c(1L, -1L))
    saveRDS(as.data.frame(m), out)
    message("wrote ", out, " (", nrow(m), " regions, ",
            sum(m$restored), " files restored in total)")
  } else {
    message("no 2.1 removals for ", snapshot, " found in ", old)
    saveRDS(res, "data/patch_effect_exact.Rds")
  }
} else {
  message("no previous-run log at ", old, "; reporting the patched side only")
  saveRDS(res, "data/patch_effect_exact.Rds")
}
