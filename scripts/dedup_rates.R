# Harvest the deduplication rate of each source from the run logs.
#
# read_feed() passes every feed through UK2GTFS::gtfs_deduplicate(), which
# prints "gtfs_deduplicate: removed N duplicate trips of M (x%)". The
# comparison report quotes those rates, and they are the one figure in it that
# no target produces: measuring them means reading a national feed twice,
# which costs more than the sentence is worth. They were typed in by hand and
# went stale the first time a feed was reconverted.
#
# This reads them out of the logs instead. The counting targets log one line
# per feed they read, so the rate for the current build is already on disk and
# only needs attributing to a source. Attribution comes from the "<source>
# <year>: window ..." line comparison_source_result() prints just before, or
# from the "lsoa_gap: reading <source>" line.
#
# Writes data/dedup_rates.Rds, which dedup_rate_text() turns into the
# report's sentence. Run it after a rebuild and before knitting the
# comparison report.
#
# Usage: Rscript scripts/dedup_rates.R [log-dir] [year]

suppressMessages(library(data.table))
source("R/config.R")
source("R/comparison.R")

args <- commandArgs(TRUE)
log_dir <- if (length(args) >= 1) args[1] else "logs/targets"
# `want_year`, not `year`: `year` is also a column of the harvested table,
# and a data.table filter on `i` resolves the name to the column.
want_year <- if (length(args) >= 2) args[2] else
  as.character(max(comparison_years()))

read_log_lines <- function(path) {
  n <- file.size(path)
  if (is.na(n) || n == 0) return(character(0))
  raw <- readBin(path, "raw", n)
  enc <- if (sum(raw[seq_len(min(2000, length(raw)))] == as.raw(0)) > 100) {
    "UTF-16LE"
  } else "UTF-8"
  txt <- iconv(list(raw), from = enc, to = "UTF-8")
  if (is.na(txt)) return(character(0))
  strsplit(txt, "\r?\n")[[1]]
}

# Walk the log in order. A source is named, then the feed is read, then the
# rate is printed; so the most recently named source owns the next rate.
scan_rates <- function(path, year) {
  l <- read_log_lines(path)
  pat <- "^(tnds|bods_txc|bods_gtfs) ([0-9]{4}): window|lsoa_gap: reading |gtfs_deduplicate: removed"
  l <- l[grepl(pat, l)]
  out <- list()
  cur <- NA_character_
  cur_year <- NA_character_
  for (x in l) {
    if (grepl("^(tnds|bods_txc|bods_gtfs) [0-9]{4}: window", x)) {
      cur <- sub("^([a-z_]+) .*$", "\\1", x)
      cur_year <- sub("^[a-z_]+ ([0-9]{4}):.*$", "\\1", x)
    } else if (grepl("^lsoa_gap: reading ", x)) {
      cur <- sub("^lsoa_gap: reading ([a-z_]+).*$", "\\1", x)
      cur_year <- year
    } else if (!is.na(cur)) {
      m <- regmatches(x, regexec(
        "removed ([0-9]+) duplicate trips of ([0-9]+) \\(([0-9.]+)%\\)", x))[[1]]
      if (length(m) == 4) {
        out[[length(out) + 1L]] <- data.table(
          source = cur, year = cur_year,
          removed = as.numeric(m[2]), trips = as.numeric(m[3]),
          pct = as.numeric(m[4]), file = basename(path))
      }
      cur <- NA_character_
    }
  }
  if (!length(out)) NULL else rbindlist(out)
}

logs <- list.files(log_dir, "[.]out[.]log$", full.names = TRUE)
if (!length(logs)) stop("no logs in ", log_dir)
all <- rbindlist(lapply(logs, function(f)
  tryCatch(scan_rates(f, want_year), error = function(e) NULL)), fill = TRUE)

if (!nrow(all)) {
  stop("no gtfs_deduplicate lines attributable to a source in ", log_dir,
       " - the counting targets may not have run yet")
}

cat("\n=== every deduplication rate found ===\n")
print(all[order(source, year, -trips)], nrows = 60)

# One rate per source for the reported year: the largest feed read for it,
# which is the national one rather than a windowed subset.
sel <- all[year == want_year]
if (!nrow(sel)) {
  message("no rates for ", want_year, "; using the most recent year present")
  sel <- all[year == max(year, na.rm = TRUE)]
}
res <- sel[, .SD[which.max(trips)], by = source]
res <- res[, list(source, year, removed, trips, pct)]
setorder(res, -pct)

cat("\n=== one rate per source, year ", want_year, " ===\n", sep = "")
print(res)

dir.create(load_cfg()$out_dir, showWarnings = FALSE, recursive = TRUE)
out <- file.path(load_cfg()$out_dir, "dedup_rates.Rds")
saveRDS(as.data.frame(res), out)
message("wrote ", out)
cat("\nreport sentence: ", dedup_rate_text(out), "\n", sep = "")
