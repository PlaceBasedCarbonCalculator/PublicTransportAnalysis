# Re-measure the 60-zone published-timetable checks on the current pipeline.
#
# reports/pdf_validation.md carries a section, "The zones where TNDS and BODS
# GTFS disagree most", written by the Python scripts in
# scripts/zone_pdf_validation/ in October 2026. Its 201 checks are the only
# place in the repository where a published timetable is compared with a
# source AT A ZONE rather than along a whole route, and they are what the TNDS
# conversion investigation was built on. They were measured BEFORE the UK2GTFS
# overlap patch, before the move to the TransXChange 2.5 edition, and over a
# 28-day window.
#
# This re-measures the pipeline side of all 201 and says what changed. It does
# not re-read a single PDF: data/zone_pdf_validation.csv already carries each
# document's journeys per operating day, which is the part the PDFs were
# needed for, and that reading does not depend on the pipeline. What is
# recomputed is
#
#   * the document's window total, from journeys per day times the number of
#     each day type in the CURRENT window (14 days, not 28), and
#   * the TNDS and BODS GTFS run counts at the zone, from the current feeds.
#
# Both sides therefore move onto the 14-day window together, so the ratios
# stay comparable with the published ones even though the counts halve.
#
# It counts the zones itself rather than reading
# data/lsoa_disagreement_2026.Rds. That file holds per-route counts only for
# the zones its own ranking picked out, and the whole point of the fixes is
# that the ranking changes - some of these 60 zones will have dropped out of
# it. Counting the 60 named zones directly is the only way to keep all 201
# checks.
#
# It counts THREE feeds, not two. `PREFIX_TNDS` optionally names a copy of the
# TNDS feed as it was before the fixes - TransXChange 2.1, unpatched UK2GTFS -
# and it is counted over the same 14-day window, by this same code, as the
# fixed feed. Without it the only available "before" is the `tnds` column of
# the CSV, which was measured over 28 days by a different code path, so a
# change in it could be the window, the conversion or the method. With it the
# three effects separate: `tnds_prefix` against `tnds` is the conversion fixes
# alone, and either against the CSV is the window as well.
#
# Usage: Rscript scripts/zone_check_refresh.R
#        PREFIX_TNDS=/path/to/old/tnds_20260726_merged.zip Rscript scripts/...
# Writes data/zone_pdf_validation_refreshed.{csv,Rds}

for (f in list.files("R", full.names = TRUE)) source(f)
suppressMessages({
  library(data.table)
  library(sf)
  library(dplyr)
})
suppressMessages(sf::sf_use_s2(FALSE))

TOL <- 0.15 # as scripts/zone_pdf_validation/assemble.py

old <- as.data.table(read.csv("data/zone_pdf_validation.csv",
                              stringsAsFactors = FALSE))
message("checks in the published section: ", nrow(old), " over ",
        uniqueN(old$zone), " zones")

spec <- validation_snapshot()
win <- study_window(validation_windows()[["main"]])
message("window: ", win$startdate, " to ", win$enddate)

# --- the document side, rescaled to the current window --------------------
#
# day_counts() is the number of each day type in the window. MT is Monday to
# Thursday, MF Monday to Friday, MS Monday to Saturday.
day_counts <- function(win) {
  n <- tabulate(lubridate::wday(seq(win$startdate, win$enddate, by = 1),
                                week_start = 1), 7L)
  c(MT = sum(n[1:4]), Fr = n[5], MF = sum(n[1:5]), Sa = n[6], Su = n[7],
    MS = sum(n[1:6]))
}
DC <- day_counts(win)
message("day counts: ", paste(names(DC), DC, sep = "=", collapse = " "))

# Scale one document's journeys-per-day up to the window.
#
# This is NOT a sum of journeys times day count over every day type present.
# The day types a reader finds in a document are partly alternative labels for
# the same weekdays, not additive blocks: a document whose weekday table is
# headed "Mondays to Saturdays" can also yield an "MF" label from a sub-block,
# and adding both counts its weekday service twice. Reading's route 500 is the
# case in this set - `{'Sa': 43, 'MF': 36, 'MS': 12}` - and an additive
# reading gives 1,180 against the published 892.
#
# So weekday service comes from exactly ONE source, in order of specificity:
# MT/Fr if either is present, else MF, else MS; and MS, when it is what
# supplies the weekdays, also supplies Saturday unless Saturday was read
# separately. Saturday and Sunday are then added. This is a port of the
# cascade in `run()` in scripts/zone_pdf_validation/compute.py, and it
# reproduces all 201 published `document_window` values exactly when given
# that section's 28-day counts - which is the test in
# scripts/zone_check_doc_scaling_test.R.
doc_window <- function(s, dc) {
  vapply(s, function(x) {
    m <- regmatches(x, gregexpr("'[A-Za-z]+':[ ]*-?[0-9]+", x))[[1]]
    if (!length(m)) return(NA_real_)
    k <- sub("^'([A-Za-z]+)'.*$", "\\1", m)
    v <- as.numeric(sub("^.*:[ ]*", "", m))
    d <- stats::setNames(as.list(v), k)
    g <- function(nm, alt = NULL) if (!is.null(d[[nm]])) d[[nm]] else alt

    if (!is.null(d[["MT"]]) || !is.null(d[["Fr"]])) {
      mt <- g("MT", g("MF", 0))
      fr <- g("Fr", g("MF", mt))
      wk <- dc[["MT"]] * mt + dc[["Fr"]] * fr
    } else if (!is.null(d[["MF"]])) {
      wk <- dc[["MF"]] * d[["MF"]]
    } else if (!is.null(d[["MS"]])) {
      # MS covers Monday to Saturday, so its weekday part is the MF count and
      # its Saturday part is added below - not the MS count, which would
      # count Saturday twice.
      wk <- dc[["MF"]] * d[["MS"]]
      if (is.null(d[["Sa"]])) d[["Sa"]] <- d[["MS"]]
    } else {
      wk <- 0
    }
    wk + dc[["Sa"]] * g("Sa", 0) + dc[["Su"]] * g("Su", 0)
  }, 0, USE.NAMES = FALSE)
}

old[, doc_old := as.numeric(document_window)]
old[, doc_new := doc_window(document_journeys_per_day, DC)]

# --- the pipeline side, counted now ---------------------------------------
zones_all <- readRDS(ensure_plain_zones(load_cfg()))
names(zones_all)[1] <- "zone_id"
zones_all <- sf::st_transform(zones_all, 4326)
zones <- zones_all[zones_all$zone_id %in% unique(old$zone), ]
message("counting ", nrow(zones), " of ", uniqueN(old$zone), " named zones")
zones_all <- NULL
gc()

feeds <- list(tnds = spec$tnds, bods_gtfs = spec$bods_gtfs)
prefix <- Sys.getenv("PREFIX_TNDS")
staged <- NULL
if (nzchar(prefix)) {
  if (!file.exists(prefix)) stop("PREFIX_TNDS does not exist: ", prefix)
  # Staged into gtfs/ rather than read where it lies. Every feed in this repo
  # is read through read_feed(), which is also where deduplication happens, so
  # reading the pre-fix feed any other way would compare two feeds counted by
  # different code and make the whole before/after meaningless. read_feed()
  # resolves its argument with resolve_feed_path(), which prepends the data
  # root to anything not beginning "gtfs/" - an absolute path outside the repo
  # comes back as <data_root>/C:/Users/... and is not found. Widening
  # resolve_feed_path() would be the tidier fix but it is reached by every
  # target in the pipeline, so changing it would invalidate the entire
  # rebuild to save one copy.
  staged <- file.path(load_cfg()$gtfs_dir, "tnds_prefix_staged.zip")
  if (!file.exists(staged) ||
      file.size(staged) != file.size(prefix)) {
    message("staging the pre-fix feed into ", staged)
    ok <- file.copy(prefix, staged, overwrite = TRUE)
    if (!ok) stop("could not stage the pre-fix feed into ", staged)
  }
  feeds$tnds_prefix <- staged
  message("pre-fix TNDS feed: ", prefix, " (staged as ", staged, ")")
} else {
  message("no PREFIX_TNDS set; the conversion fixes cannot be separated ",
          "from the window change")
}
# (removed at the end of the script - on.exit() registers against a function
# frame and does nothing at top level under Rscript)

cnt <- list()
for (src in names(feeds)) {
  message("reading ", src, " (", feeds[[src]], ")")
  gtfs <- read_feed(feeds[[src]], load_cfg())
  gtfs <- prepare_feed_window(gtfs, win)
  rr <- zone_route_runs(gtfs, zones, win, route_types = 3L)
  br <- rr$by_route[!is.na(route_short_name)]
  br[, name := toupper(trimws(route_short_name))]
  cnt[[src]] <- br[, list(runs = sum(runs)), by = list(zone_id, name)]
  gtfs <- NULL
  rr <- NULL
  gc()
}
if (!is.null(staged) && file.exists(staged)) {
  unlink(staged)
  message("removed the staged copy")
}

old[, name := toupper(trimws(route))]
j <- merge(old, setnames(cnt$tnds, "runs", "tnds_new"),
           by.x = c("zone", "name"), by.y = c("zone_id", "name"), all.x = TRUE)
j <- merge(j, setnames(cnt$bods_gtfs, "runs", "bods_new"),
           by.x = c("zone", "name"), by.y = c("zone_id", "name"), all.x = TRUE)
if (!is.null(cnt$tnds_prefix)) {
  j <- merge(j, setnames(cnt$tnds_prefix, "runs", "tnds_prefix"),
             by.x = c("zone", "name"), by.y = c("zone_id", "name"),
             all.x = TRUE)
} else {
  j[, tnds_prefix := NA_real_]
}
j[is.na(tnds_new), tnds_new := 0]
j[is.na(bods_new), bods_new := 0]
j[!is.na(tnds_prefix) | nzchar(prefix), tnds_prefix :=
    ifelse(is.na(tnds_prefix), 0, tnds_prefix)]

j[, t_ratio_new := ifelse(doc_new > 0, round(tnds_new / doc_new, 2), NA_real_)]
j[, b_ratio_new := ifelse(doc_new > 0, round(bods_new / doc_new, 2), NA_real_)]
j[, t_ratio_prefix := ifelse(doc_new > 0 & !is.na(tnds_prefix),
                             round(tnds_prefix / doc_new, 2), NA_real_)]

# --- the verdict rule, ported from assemble.py ----------------------------
verdict_one <- function(t, b) {
  ok <- function(x) !is.na(x) && abs(x - 1) <= TOL
  miss <- function(x) !is.na(x) && x == 0
  if (miss(t) && miss(b)) return("both absent")
  if (ok(t) && ok(b)) return("both agree")
  if (ok(t)) return(if (miss(b)) "BODS GTFS absent" else "TNDS right")
  if (ok(b)) return(if (miss(t)) "TNDS absent" else "BODS GTFS right")
  if (miss(t)) return("TNDS absent; BODS GTFS off")
  if (miss(b)) return("BODS GTFS absent; TNDS off")
  lt <- if (is.na(t) || t == 0) 9 else abs(log(t))
  lb <- if (is.na(b) || b == 0) 9 else abs(log(b))
  if (lt < lb) "neither; TNDS closer" else "neither; BODS GTFS closer"
}
j[, verdict_new := mapply(verdict_one, t_ratio_new, b_ratio_new,
                          USE.NAMES = FALSE)]
j[, verdict_prefix := mapply(verdict_one, t_ratio_prefix, b_ratio_new,
                             USE.NAMES = FALSE)]

out <- j[, list(zone, locality, area, route, operator, document, edition,
                edition_status, basis, document_journeys_per_day,
                document_window_published = doc_old, document_window = doc_new,
                tnds_published = as.numeric(tnds), tnds_prefix, tnds = tnds_new,
                bods_published = as.numeric(bods), bods = bods_new,
                tnds_over_doc_published = as.numeric(tnds_over_doc),
                tnds_over_doc_prefix = t_ratio_prefix,
                tnds_over_doc = t_ratio_new,
                bods_over_doc_published = as.numeric(bods_over_doc),
                bods_over_doc = b_ratio_new,
                verdict_published = verdict, verdict_prefix, verdict = verdict_new,
                reliable, lsoa_verdict)]
setorderv(out, c("area", "zone", "route"))
write.csv(out, "data/zone_pdf_validation_refreshed.csv", row.names = FALSE)
message("wrote data/zone_pdf_validation_refreshed.csv")
saveRDS(list(window = win, day_counts = DC, snapshot = spec,
             prefix_feed = prefix, checks = out),
        "data/zone_pdf_validation_refreshed.Rds")
message("wrote data/zone_pdf_validation_refreshed.Rds")

# --- what changed ---------------------------------------------------------
cat("\n=== verdict counts ===\n")
print(out[, list(published = .N), by = verdict_published][order(-published)])
print(out[, list(prefix_14d = .N), by = verdict_prefix][order(-prefix_14d)])
print(out[, list(fixed_14d = .N), by = verdict][order(-fixed_14d)])

cat("\n=== TNDS ratio to the document, reliable checks only ===\n")
r <- out[reliable == "True" | reliable == TRUE]
cat("checks:", nrow(r), "\n")
cat(sprintf("published (28d, 2.1, unpatched): median %.2f, |log| mean %.3f\n",
            median(r$tnds_over_doc_published, na.rm = TRUE),
            mean(abs(log(pmax(r$tnds_over_doc_published, 1e-3))), na.rm = TRUE)))
if (any(!is.na(r$tnds_over_doc_prefix))) {
  cat(sprintf("pre-fix  (14d, 2.1, unpatched): median %.2f, |log| mean %.3f\n",
              median(r$tnds_over_doc_prefix, na.rm = TRUE),
              mean(abs(log(pmax(r$tnds_over_doc_prefix, 1e-3))), na.rm = TRUE)))
}
cat(sprintf("fixed    (14d, 2.5, patched)  : median %.2f, |log| mean %.3f\n",
            median(r$tnds_over_doc, na.rm = TRUE),
            mean(abs(log(pmax(r$tnds_over_doc, 1e-3))), na.rm = TRUE)))
cat(sprintf("BODS GTFS(14d)                : median %.2f, |log| mean %.3f\n",
            median(r$bods_over_doc, na.rm = TRUE),
            mean(abs(log(pmax(r$bods_over_doc, 1e-3))), na.rm = TRUE)))

cat("\n=== the checks the investigation named ===\n")
named <- out[(area %like% "Chelmsford" | area %like% "Preston" |
              zone == "E01004397" | area %like% "Reading" |
              area %like% "Weymouth" | area %like% "Crawley" |
              area %like% "Hull"),
             list(area, zone, route, document_window,
                  tnds_published, tnds_prefix, tnds, bods,
                  tnds_over_doc_published, tnds_over_doc_prefix,
                  tnds_over_doc, bods_over_doc)]
print(named, nrows = 120)
