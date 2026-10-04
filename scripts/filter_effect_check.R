# How many TransXChange files each conversion kept, before and after.
#
# txc_filter_files() reports, per regional archive, "Removed N superseded /
# duplicate files, M remain". Those lines are the most direct measurement
# there is of what the October 2026 changes did to the conversion, because
# they are counted on the real archive rather than emulated:
#
#   * the TransXChange 2.5 edition changes how many files go IN (it is 2.1
#     minus TNDS's own cross-boundary duplicates), and
#   * the UK2GTFS overlap patch changes how many of them are thrown away.
#
# The two have to be read together. A region whose input shrank by 18 files
# and whose removals did not move has gained nothing from the patch and lost
# 18 duplicate copies to the 2.5 edition; a region whose removals fell by more
# than its input shrank has gained sibling files back from the patch.
#
# `before` is the log of the last run on the old pipeline (2.1, unpatched);
# `after` is this rebuild's. Both are driver logs under logs/, which are not
# committed, so this reports what it could not find rather than failing.
#
# Usage: Rscript scripts/filter_effect_check.R [before.log] [after-dir]

suppressMessages(library(data.table))
source("R/config.R")
source("R/convert.R")

args <- commandArgs(TRUE)
before_log <- if (length(args) >= 1) args[1] else "logs/rerun_20261002.log"
after_dir <- if (length(args) >= 2) args[2] else "logs/targets"

# Pair each "Converting <archive>" line with the "Removed ... remain" line
# that follows it. UK2GTFS prints them in that order, one pair per archive.
read_log_lines <- function(path) {
  # The driver redirects through PowerShell, which writes UTF-16LE; a log from
  # a plain Rscript run is UTF-8. Decode from the raw bytes rather than
  # guessing, because a UTF-16 file read as UTF-8 comes back as text full of
  # embedded nulls that no regex here will match.
  raw <- readBin(path, "raw", file.size(path))
  if (length(raw) >= 2 && raw[1] == as.raw(0xFF) && raw[2] == as.raw(0xFE)) {
    enc <- "UTF-16LE"
  } else if (sum(raw[seq_len(min(2000, length(raw)))] == as.raw(0)) > 100) {
    enc <- "UTF-16LE"
  } else {
    enc <- "UTF-8"
  }
  txt <- iconv(list(raw), from = enc, to = "UTF-8")
  if (is.na(txt)) return(character(0))
  strsplit(txt, "\r?\n")[[1]]
}

scan_log <- function(path) {
  if (!file.exists(path)) return(NULL)
  l <- tryCatch(read_log_lines(path), error = function(e) character(0))
  keep <- grepl("Converting .*[.]zip|Removed [0-9]+ superseded", l)
  l <- l[keep]
  out <- list()
  cur <- NULL
  for (x in l) {
    if (grepl("Converting", x)) {
      m <- regmatches(x, regexpr("data_[0-9]{8}(/TNDSV2[.]5)?/[A-Za-z]+[.]zip", x))
      cur <- if (length(m)) m else NA_character_
    } else if (!is.null(cur) && !is.na(cur)) {
      n <- as.integer(sub(".*Removed ([0-9]+) superseded.*", "\\1", x))
      k <- as.integer(sub(".*files, ([0-9]+) remain.*", "\\1", x))
      out[[length(out) + 1L]] <- data.table(
        archive = cur,
        snapshot = sub("^data_([0-9]{8}).*$", "\\1", cur),
        edition = ifelse(grepl("TNDSV2[.]5", cur), "2.5", "2.1"),
        region = sub("^.*/([A-Za-z]+)[.]zip$", "\\1", cur),
        removed = n, kept = k)
      cur <- NULL
    }
  }
  if (!length(out)) return(NULL)
  rbindlist(out)
}

before <- scan_log(before_log)
after <- rbindlist(lapply(list.files(after_dir, "^tnds_.*[.]out[.]log$",
                                     full.names = TRUE), scan_log),
                   fill = TRUE)

if (is.null(before)) message("no 'before' log at ", before_log)
if (!length(after)) message("no 'after' logs in ", after_dir)
if (is.null(before) || !length(after)) quit(save = "no")

# How many files the archive holds at all, so that a change in `kept` can be
# split between "fewer went in" and "fewer were thrown away".
cfg <- load_cfg()
n_in <- function(snapshot, edition, region) {
  src <- file.path(cfg$data_root, "TransXChange", paste0("data_", snapshot))
  z <- if (edition == "2.5") file.path(src, "TNDSV2.5", paste0(region, ".zip"))
       else file.path(src, paste0(region, ".zip"))
  if (!file.exists(z)) return(NA_integer_)
  nm <- tryCatch(unzip(z, list = TRUE)$Name, error = function(e) character(0))
  sum(grepl("[.]xml$", nm, ignore.case = TRUE))
}

b <- before[, list(snapshot, region, in_b = NA_integer_,
                   removed_b = removed, kept_b = kept)]
a <- after[, list(snapshot, region, edition_a = edition,
                  removed_a = removed, kept_a = kept)]
m <- merge(b, a, by = c("snapshot", "region"))
if (!nrow(m)) { message("no region matched between the two logs"); quit(save = "no") }

message("sizing ", nrow(m), " archive pairs (reads zip indexes, slow on OneDrive)")
m[, in_b := mapply(n_in, snapshot, "2.1", region)]
m[, in_a := mapply(n_in, snapshot, edition_a, region)]
m[, `:=`(d_in = in_a - in_b, d_removed = removed_a - removed_b,
         d_kept = kept_a - kept_b)]
# Files the patch gave back: the input shrank by d_in and removals changed by
# d_removed, so anything kept beyond the input change is the patch.
m[, patch_gain := d_kept - d_in]
setorderv(m, c("snapshot", "region"))

cat("\n=== files kept per regional archive, before and after ===\n")
cat("in = .xml files in the archive; removed = dropped by txc_filter_files()\n")
cat("patch_gain = files kept beyond what the edition change alone explains\n\n")
print(m[, list(snapshot, region, edition_a, in_b, in_a, d_in,
               removed_b, removed_a, kept_b, kept_a, patch_gain)],
      nrows = 200)

cat("\n=== per snapshot ===\n")
print(m[, list(regions = .N, in_b = sum(in_b), in_a = sum(in_a),
               kept_b = sum(kept_b), kept_a = sum(kept_a),
               patch_gain = sum(patch_gain)), by = snapshot])

dir.create("data", showWarnings = FALSE)
saveRDS(m, "data/filter_effect_check.Rds")
message("\nwrote data/filter_effect_check.Rds")
