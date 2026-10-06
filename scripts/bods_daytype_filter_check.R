# Are the files txc_filter_files() discards for Brighton & Hove duplicates of
# the ones it keeps, or do they carry different operating days?
#
# If the discarded files cover the same dates as the kept ones, the filter is
# right and the operator's BODS publication is simply thin. If they cover
# DIFFERENT dates - the other days of the week, the other weeks - then the
# filter is treating complementary siblings as superseding revisions and
# deleting six days in seven.

suppressMessages({library(data.table); library(xml2)})
source("R/config.R")
cfg <- load_cfg()

# Where scripts/txc_extract_operator.py put the per-operator files. Pass the
# directory as the first argument; it defaults to a sibling of the repository
# so nothing is written inside it.
ops_dir <- function() {
  a <- commandArgs(TRUE)
  if (length(a) && nzchar(a[1])) a[1] else
    file.path(tempdir(), "bods_ops")
}


DIR <- file.path(ops_dir(), "BHBC")
FILTER_DATE <- as.Date("2026-10-05")

files <- list.files(DIR, pattern = "[.]xml$", full.names = TRUE)
message(length(files), " files")

describe <- function(f) {
  x <- tryCatch(read_xml(f), error = function(e) NULL)
  if (is.null(x)) return(NULL)
  xml_ns_strip(x)
  svc <- xml_text(xml_find_all(x, "//Service/ServiceCode"))
  op <- xml_find_first(x, "//Service/OperatingPeriod")
  sd <- xml_text(xml_find_first(op, "./StartDate"))
  ed <- xml_text(xml_find_first(op, "./EndDate"))
  rev <- xml_attr(xml_find_first(x, "/TransXChange"), "RevisionNumber")
  # which days of the week the service's regular pattern runs
  days <- xml_name(xml_children(
    xml_find_first(x, "//RegularDayType/DaysOfWeek")))
  njy <- length(xml_find_all(x, "//VehicleJourney"))
  data.table(file = basename(f),
             service_code = if (length(svc)) svc[1] else NA_character_,
             revision = rev %||% NA_character_,
             start = sd %||% NA_character_, end = ed %||% NA_character_,
             days = paste(days, collapse = ","),
             journeys = njy)
}
`%||%` <- function(a, b) if (is.null(a) || !length(a) || is.na(a)) b else a

meta <- rbindlist(lapply(files, describe), fill = TRUE)
message("described ", nrow(meta))

kept <- UK2GTFS::txc_filter_files(files, date = FILTER_DATE,
                                  ncores = min(8L, cfg$ncores))
meta[, kept := file %in% basename(kept)]
cat("\nkept", sum(meta$kept), "of", nrow(meta), "files\n")
cat("journeys kept", meta[kept == TRUE, sum(journeys)],
    " discarded", meta[kept == FALSE, sum(journeys)], "\n")

cat("\n=== operating periods: kept vs discarded ===\n")
print(meta[, list(files = .N, journeys = sum(journeys)),
           by = list(kept, start, end)][order(start, -files)][1:24])

cat("\n=== days of week covered ===\n")
print(meta[, list(files = .N, journeys = sum(journeys)),
           by = list(kept, days)][order(-files)][1:16])

cat("\n=== do discarded files duplicate a kept file's (service, period, days)? ===\n")
key <- function(d) paste(d$service_code, d$start, d$end, d$days)
kk <- unique(key(meta[kept == TRUE]))
dd <- meta[kept == FALSE]
dd[, dup_of_kept := key(dd) %in% kk]
cat("discarded files whose (service, period, days) matches a kept file:",
    dd[dup_of_kept == TRUE, .N], "of", nrow(dd), "\n")
cat("  their journeys:", dd[dup_of_kept == TRUE, sum(journeys)], "\n")
cat("discarded files with a combination NO kept file has:",
    dd[dup_of_kept == FALSE, .N], "\n")
cat("  their journeys:", dd[dup_of_kept == FALSE, sum(journeys)], "\n")
saveRDS(meta, file.path(cfg$out_dir, "bhbc_filter_detail.Rds"))
cat("\nwrote data/bhbc_filter_detail.Rds\n")
