# Every action UK2GTFS::txc_filter_files() takes on one TNDS snapshot.
#
# Runs the installed filter exactly as the pipeline does (the snapshot date as
# the reference date, overlap resolution on) region by region, and records for
# each raw file whether it was kept, dropped, or kept with a rewritten
# operating period - and the period before and after. The journeys those
# actions remove are then measured by lost_journeys.py.
#
# usage: Rscript filter_actions.R <snapshot dir> <out csv> [work dir]
args <- commandArgs(trailingOnly = TRUE)
# UK2GTFS_SRC=<checkout> measures an edited source tree instead of the
# installed package (devtools::load_all), so a fix can be measured before it
# is installed.
txc_filter_files <- UK2GTFS::txc_filter_files
if (nzchar(Sys.getenv("UK2GTFS_SRC"))) {
  options(UK2GTFS_opt_updateCachedDataOnLibaryLoad = FALSE)
  suppressMessages(devtools::load_all(Sys.getenv("UK2GTFS_SRC"), quiet = TRUE))
  txc_filter_files <- get("txc_filter_files", envir = asNamespace("UK2GTFS"))
}
src <- args[1]; out_csv <- args[2]
work <- if (length(args) > 2) args[3] else tempfile("filter_actions")
snap <- as.Date(sub(".*data_(\\d{8}).*", "\\1", src), "%Y%m%d")
dir.create(work, showWarnings = FALSE, recursive = TRUE)

period_of <- function(f) {
  x <- paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = " ")
  op <- regmatches(x, regexpr("<OperatingPeriod>.*?</OperatingPeriod>", x, perl = TRUE))
  if (!length(op)) return(c(NA_character_, NA_character_))
  s <- regmatches(op, regexpr("(?<=<StartDate>)[^<]+", op, perl = TRUE))
  e <- regmatches(op, regexpr("(?<=<EndDate>)[^<]+", op, perl = TRUE))
  c(if (length(s)) s else NA_character_, if (length(e)) e else NA_character_)
}

zips <- list.files(file.path(src, "TNDSV2.5"), pattern = "[.]zip$", full.names = TRUE)
res <- list()
for (z in zips) {
  region <- sub("[.]zip$", "", basename(z))
  dir <- file.path(work, region)
  unzip(z, exdir = dir)
  f <- list.files(dir, pattern = "[.]xml$", full.names = TRUE)
  keep <- txc_filter_files(f, date = snap, ncores = 10,
                                    out_dir = file.path(work, paste0(region, "_rw")))
  # A rewritten copy is named <original>_<8 hex>.xml in out_dir. Strip that
  # suffix from rewritten copies only: Welsh and Yorkshire files end in an
  # export date such as "_20260714", which is eight hex digits too.
  rw <- keep[grepl("_rw", keep, fixed = TRUE)]
  rw_orig <- sub("_[0-9a-f]{8}[.]xml$", ".xml", basename(rw))
  kept_orig <- c(basename(setdiff(keep, rw)), rw_orig)
  before <- t(vapply(f, period_of, character(2)))
  after <- matrix(NA_character_, length(f), 2)
  i <- match(rw_orig, basename(f))
  if (length(rw)) after[i, ] <- t(vapply(rw, period_of, character(2)))
  st <- ifelse(!basename(f) %in% kept_orig, "dropped",
               ifelse(basename(f) %in% rw_orig, "truncated", "kept"))
  res[[region]] <- data.frame(region = region, file = basename(f), status = st,
                              start = before[, 1], end = before[, 2],
                              new_start = after[, 1], new_end = after[, 2])
  message(region, ": ", sum(st == "dropped"), " dropped, ",
          sum(st == "truncated"), " truncated of ", length(f))
}
out <- do.call(rbind, res)
write.csv(out, out_csv, row.names = FALSE)
