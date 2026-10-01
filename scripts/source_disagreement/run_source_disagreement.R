# Reproduces every table in reports/source_disagreement_investigation.md.
#
#   Rscript scripts/source_disagreement/run_source_disagreement.R
#
# Reads the raw TransXChange archives and the converted feeds; writes
# data/source_disagreement.Rds and prints the tables. Expect an hour or so:
# the national collision measurement parses about 17,000 XML files, and the
# signature sensitivity groups 56 million stop-times three ways.
#
# Nothing in _targets.R depends on this and nothing it writes is read by the
# pipeline.

library(data.table)
source("scripts/source_disagreement/source_disagreement.R")
source("R/config.R")

cfg <- load_cfg()
SNAP <- "20260726"
REF <- as.Date("2026-07-26")
WIN <- c("2026-07-27", "2026-08-23")
TNDS <- file.path(cfg$gtfs_dir, "tnds_20260726_merged.zip")
BODS <- file.path(cfg$data_root, "OpenBusData/GTFS/20260726/itm_all_gtfs.zip")
TXC_DIR <- file.path(cfg$data_root, "TransXChange", paste0("data_", SNAP))
REGIONS <- c("EA", "EM", "L", "NE", "NW", "S", "SE", "SW", "W", "WM", "Y")
out <- list(generated = Sys.time(), snapshot = SNAP, window = WIN)

# --- 1. would a looser journey signature remove more? ----------------------
message("1/4  signature sensitivity")
out$signature <- rbindlist(list(
  cbind(feed = "BODS GTFS", signature_sensitivity(BODS)),
  cbind(feed = "TNDS", signature_sensitivity(TNDS))), fill = TRUE)
print(out$signature)

# --- 2. does each year's feed hold up across its own window? ---------------
message("2/4  within-window decay, every published year")
years <- list(
  c("gtfs/tnds_20180515_merged.zip", "2018-05-15"),
  c("gtfs/tnds_20191008_merged.zip", "2019-10-08"),
  c("gtfs/tnds_20200701_merged.zip", "2020-07-01"),
  c("gtfs/tnds_20211012_merged.zip", "2021-10-12"),
  c("gtfs/tnds_20221102_merged.zip", "2022-11-02"),
  c("gtfs/tnds_20231101_merged.zip", "2023-11-01"),
  c("gtfs/tnds_20241004_merged.zip", "2024-10-04"),
  c("gtfs/tnds_20251003_merged.zip", "2025-10-03"),
  c("gtfs/tnds_20260726_merged.zip", "2026-07-27"))
out$decay <- rbindlist(lapply(years, function(y) {
  if (!file.exists(y[1])) return(NULL)
  w <- study_window(y[2])
  p <- wednesday_profile(y[1], w$startdate, w$enddate)
  if (is.null(p)) return(NULL)
  p[, feed := basename(y[1])][, wk := seq_len(.N)][]
}))
d <- dcast(out$decay, feed ~ wk, value.var = "trips")
d[, change_pct := round(100 * (get(names(d)[ncol(d)]) / get(names(d)[2]) - 1), 1)]
print(d)

# --- 3. what does the ServiceCode collision cost? --------------------------
message("3/5  ServiceCode collision, every TNDS region (slow)")
out$collision <- rbindlist(lapply(REGIONS, function(rg) {
  z <- file.path(TXC_DIR, paste0(rg, ".zip"))
  if (!file.exists(z)) return(NULL)
  m <- txc_region_headers(z, workers = 10)
  if (!nrow(m)) return(NULL)
  cbind(region = rg, collision_cost(m, REF))
}))
print(out$collision)
cat("\nNational journeys recovered by keying on the operator too:",
    sum(out$collision$lost), "=",
    round(100 * sum(out$collision$lost) / sum(out$collision$journeys), 2),
    "% of TNDS\n")

# --- 4. Birmingham route 74, day by day ------------------------------------
message("4/5  Birmingham route 74")
days <- seq(as.Date("2026-08-03"), as.Date("2026-08-09"), by = 1)
b <- merge(
  route_stop_profile(TNDS, "74", "43000955906", days)[, .(date, dow, TNDS = calls)],
  route_stop_profile(BODS, "74", "43000955906", days)[, .(date, BODS = calls)],
  by = "date")
b[, ratio := round(BODS / pmax(TNDS, 1), 2)]
out$route74 <- b
print(b)

# --- 5. the fix, A/B'd against the committed version -----------------------
# Only runs where the working tree actually differs from HEAD, so the script
# still works once the fix is committed.
PKG <- Sys.getenv("UK2GTFS_PKG", "F:/GitHub/ITSleeds/UK2GTFS")
patched <- nzchar(system2("git", c("-C", shQuote(PKG), "diff", "--name-only",
                                  "HEAD", "--", "R/txc_filter_files.R"),
                          stdout = TRUE)[1])
if (isTRUE(patched)) {
  message("5/5  A/B of txc_filter_files() before and after the operator key")
  out$filter_ab <- rbindlist(lapply(REGIONS, function(rg) {
    z <- file.path(TXC_DIR, paste0(rg, ".zip"))
    if (!file.exists(z)) return(NULL)
    filter_ab(z, PKG, REF, workers = 10)
  }))
  print(out$filter_ab)
  stopifnot(sum(out$filter_ab$newly_dropped) == 0)
  cat("
Journeys recovered:", sum(out$filter_ab$vj_gained),
      " files recovered:", sum(out$filter_ab$newly_kept),
      " newly dropped:", sum(out$filter_ab$newly_dropped), "
")
} else {
  message("5/5  skipped - R/txc_filter_files.R matches HEAD, nothing to A/B")
}

dir.create(cfg$out_dir, showWarnings = FALSE, recursive = TRUE)
saveRDS(out, file.path(cfg$out_dir, "source_disagreement.Rds"))
message("wrote ", file.path(cfg$out_dir, "source_disagreement.Rds"))
