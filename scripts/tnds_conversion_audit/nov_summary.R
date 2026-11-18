# Summarise the November stop PDF check (in-force readings) for one or more
# saved copies of data/stop_pdf_validation_nov.Rds.
# usage: Rscript nov_summary.R label=path [label=path ...]
suppressMessages(library(data.table))
ok <- function(r) !is.na(r) & is.finite(r) & abs(r - 1) <= 0.15
s <- function(f, lab) {
  x <- readRDS(f)$checks
  ch <- unique(x[chosen == TRUE & reliable == TRUE & edition_status == "in force"],
               by = c("route", "document"))
  med <- function(r) round(100 * median(abs(r[is.finite(r)] - 1)), 1)
  data.table(build = lab, readings = nrow(ch),
             tnds = sum(ok(ch$tnds_ratio)), bods_txc = sum(ok(ch$bods_txc_ratio)),
             bods_gtfs = sum(ok(ch$bods_ratio)),
             tnds_med = med(ch$tnds_ratio), txc_med = med(ch$bods_txc_ratio),
             gtfs_med = med(ch$bods_ratio),
             tnds_else_txc = sum(ok(ifelse(ch$tnds_ratio > 0, ch$tnds_ratio, ch$bods_txc_ratio))),
             none_ok = sum(!ok(ch$tnds_ratio) & !ok(ch$bods_txc_ratio) & !ok(ch$bods_ratio)))
}
a <- commandArgs(trailingOnly = TRUE)
kv <- strsplit(a, "=", fixed = TRUE)
print(rbindlist(lapply(kv, function(p) s(p[2], p[1]))))
if (length(kv) >= 2) {
  k <- c("route", "document")
  f1 <- readRDS(kv[[1]][2])$checks; f2 <- readRDS(kv[[length(kv)]][2])$checks
  g <- function(x) unique(x[chosen == TRUE & reliable == TRUE & edition_status == "in force"], by = k)[
    , .(route, document, doc_week, tnds_ratio, bods_txc_ratio, bods_ratio)]
  m <- merge(g(f1), g(f2), by = k, suffixes = c("_a", "_b"))
  m <- m[abs(tnds_ratio_a - tnds_ratio_b) > 0.02 | abs(bods_txc_ratio_a - bods_txc_ratio_b) > 0.02 |
           abs(doc_week_a - doc_week_b) > 0.5]
  print(m[, .(route, doc = substr(document, 1, 32), doc_a = doc_week_a, doc_b = doc_week_b,
              tnds_a = round(tnds_ratio_a, 2), tnds_b = round(tnds_ratio_b, 2),
              txc_a = round(bods_txc_ratio_a, 2), txc_b = round(bods_txc_ratio_b, 2),
              gtfs_b = round(bods_ratio_b, 2))])
}
