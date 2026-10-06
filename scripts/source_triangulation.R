# Which bus services each of the three sources actually has, and what a
# combined TNDS + BODS TransXChange feed would be worth.
#
# reports/bus_source_comparison.md compares the sources in pairs. That answers
# "how far do two sources differ" but not "which services does only one source
# have", which needs all three at once, and it cannot test the proposal this
# script exists for: that converting TNDS and the BODS TransXChange change
# archive together would beat using the DfT's own BODS GTFS rendering.
#
# Two things are measured per matched service and source, and they are not the
# same thing:
#
#   * routes  - whether the source carries the service at all
#   * runs    - whether it has it OPERATING in the counting window
#
# The comparison's services table only holds runs, so a service a source
# carries but does not run that fortnight (an expired registration, a seasonal
# variant, a school service in the holidays) is indistinguishable there from a
# service the source has never heard of. Both appear as a zero. That matters
# here, because the headline question is coverage: several services that look
# exclusive to the DfT's GTFS on a runs test turn out to be present in TNDS
# and simply not running - Arriva's Rhyl 35 among them.
#
# Matching is match_route_services(), exactly as the comparison report uses,
# so the service groups are the same ones. It is re-run rather than read back
# because combine_year_comparison() keeps only the cast runs table and
# discards the per-route membership this needs.
#
# Regions come from the ATCO prefix of the stops each service calls at, not
# from operator names: "Arriva" operates in nine traveline regions and the
# question is geographic.
#
# Usage: Rscript scripts/source_triangulation.R [year]

suppressMessages({
  library(data.table); library(targets)
})
source("R/config.R")
source("R/comparison.R")
source("R/route_match.R")
source("R/coverage.R")

cfg <- load_cfg()
args <- commandArgs(TRUE)
YEAR <- if (length(args)) as.integer(args[1]) else 2026L

srcs <- comparison_sources()
message("reading the three ", YEAR, " comparison targets")
res <- lapply(srcs, function(s) tar_read_raw(sprintf("cmp_%d_%s", YEAR, s)))
names(res) <- srcs
win <- res[[1]]$window
message("window ", win$startdate, " to ", win$enddate)
for (s in srcs) {
  stopifnot(identical(res[[s]]$window, win))
}

summaries <- lapply(res, `[[`, "routes")
message("matching routes across sources")
matched <- match_route_services(summaries)
members <- matched$members

# --- per service and source: runs AND number of routes carried ------------
by_src <- members[, list(runs = sum(runs), routes = .N),
                  by = list(service, source)]
runs_w <- dcast(by_src, service ~ source, value.var = "runs", fill = 0)
rts_w  <- dcast(by_src, service ~ source, value.var = "routes", fill = 0)
setnames(runs_w, srcs, paste0("runs_", srcs))
setnames(rts_w,  srcs, paste0("routes_", srcs))
svc <- merge(runs_w, rts_w, by = "service")

# --- region of each service, from the ATCO prefix of the stops it calls ---
areas <- coverage_atco_areas()
reg_of <- if (is.null(areas)) NULL else
  setNames(as.character(areas$region), as.character(areas$atco_code))

stop_region <- function() {
  all_stops <- rbindlist(lapply(srcs, function(s) {
    st <- summaries[[s]]$stops
    if (!nrow(st)) return(NULL)
    data.table(node = paste(s, st$route_id, sep = "::"),
               stop_id = st$stop_id)
  }), fill = TRUE)
  all_stops <- merge(all_stops, members[, list(node, service)], by = "node")
  all_stops[, atco := substr(stop_id, 1L, 3L)]
  all_stops[, region := if (is.null(reg_of)) NA_character_ else
    reg_of[atco]]
  # The modal region of the stops a service calls at. A cross-boundary
  # service is assigned to where most of it runs, which is what the
  # country/region totals below want.
  all_stops[!is.na(region), list(n = .N), by = list(service, region)][
    order(service, -n)][, list(region = region[1]), by = service]
}
message("assigning regions from stop ATCO prefixes")
svc <- merge(svc, stop_region(), by = "service", all.x = TRUE)

lab <- matched$services[, list(service, short_key, route_short_name,
                               agency_name, from, to)]
svc <- merge(svc, lab, by = "service", all.x = TRUE)

# --- the two presence patterns -------------------------------------------
pat <- function(a, b, c) paste0(ifelse(a, "T", "-"), ifelse(b, "X", "-"),
                                ifelse(c, "G", "-"))
svc[, pat_runs := pat(runs_tnds > 0, runs_bods_txc > 0, runs_bods_gtfs > 0)]
svc[, pat_carried := pat(routes_tnds > 0, routes_bods_txc > 0,
                         routes_bods_gtfs > 0)]

cat("\n=== ", YEAR, ": services CARRIED by each combination of sources ===\n",
    sep = "")
cat("(a service is carried if the source has a route for it whose calendar\n",
    " reaches the window at all, running or not)\n\n", sep = "")
t1 <- svc[, list(services = .N,
                 runs_tnds = sum(runs_tnds),
                 runs_bods_txc = sum(runs_bods_txc),
                 runs_bods_gtfs = sum(runs_bods_gtfs)), by = pat_carried]
print(t1[order(-services)])

cat("\n=== the same services by whether they RUN in the window ===\n\n")
t2 <- svc[, list(services = .N,
                 runs_tnds = sum(runs_tnds),
                 runs_bods_txc = sum(runs_bods_txc),
                 runs_bods_gtfs = sum(runs_bods_gtfs)), by = pat_runs]
print(t2[order(-services)])

cat("\n=== carried but not running: the gap between the two tables ===\n")
cat("services a source carries but does not run in the window:\n")
for (s in srcs) {
  cat(sprintf("  %-10s carried %6d   running %6d   idle %5d\n", s,
              svc[get(paste0("routes_", s)) > 0, .N],
              svc[get(paste0("runs_", s)) > 0, .N],
              svc[get(paste0("routes_", s)) > 0 &
                    get(paste0("runs_", s)) == 0, .N]))
}

cat("\n=== exclusive services, on the CARRIED test ===\n")
excl <- svc[pat_carried %in% c("T--", "-X-", "--G")]
print(excl[, list(services = .N,
                  runs = sum(runs_tnds + runs_bods_txc + runs_bods_gtfs)),
           by = pat_carried])
cat("\nby region:\n")
print(dcast(excl[, list(.N), by = list(pat_carried, region)],
            region ~ pat_carried, value.var = "N", fill = 0))

cat("\n=== where BODS TransXChange is missing service the other two have ===\n")
tg <- svc[pat_carried == "T-G"]
cat("services:", nrow(tg), " TNDS runs:", sum(tg$runs_tnds), "\n\n")
r <- tg[, list(services = .N, tnds_runs = sum(runs_tnds)), by = region][
  order(-tnds_runs)]
r[, share_of_gap := round(tnds_runs / sum(tnds_runs), 3)]
print(r)

cat("\n=== region totals: how much of TNDS does each source have? ===\n")
reg <- svc[, list(tnds = sum(runs_tnds), bods_txc = sum(runs_bods_txc),
                  bods_gtfs = sum(runs_bods_gtfs)), by = region][order(-tnds)]
reg[, `:=`(txc_pct_of_tnds = round(100 * bods_txc / tnds, 1),
           gtfs_pct_of_tnds = round(100 * bods_gtfs / tnds, 1))]
print(reg)

# --- the union hypothesis ------------------------------------------------
cat("\n=== a combined TNDS + BODS TransXChange feed ===\n")
svc[, union_bestof := pmax(runs_tnds, runs_bods_txc)]
u <- svc[, list(
  tnds            = sum(runs_tnds),
  bods_txc        = sum(runs_bods_txc),
  bods_gtfs       = sum(runs_bods_gtfs),
  union_bestof    = sum(union_bestof),
  union_naive_sum = sum(runs_tnds + runs_bods_txc)
)]
print(t(round(u)))
cat("\nunion / bods_gtfs        =", round(u$union_bestof / u$bods_gtfs, 4), "\n")
cat("union / tnds alone       =", round(u$union_bestof / u$tnds, 4), "\n")
cat("naive sum / bods_gtfs    =", round(u$union_naive_sum / u$bods_gtfs, 4),
    " (what double counting would give)\n")
cat("\nservices the union would carry but BODS GTFS does not:",
    svc[(routes_tnds > 0 | routes_bods_txc > 0) & routes_bods_gtfs == 0, .N],
    "\nservices BODS GTFS carries but the union would not:    ",
    svc[routes_bods_gtfs > 0 & routes_tnds == 0 & routes_bods_txc == 0, .N],
    "\n  their runs:", svc[routes_bods_gtfs > 0 & routes_tnds == 0 &
                             routes_bods_txc == 0, sum(runs_bods_gtfs)], "\n")

cat("\n=== agreement between TNDS and BODS TXC where both run a service ===\n")
both <- svc[runs_tnds > 0 & runs_bods_txc > 0]
cat("services:", nrow(both), "\n")
cat("identical run counts:      ", round(mean(both$runs_bods_txc ==
                                                both$runs_tnds), 3), "\n")
cat("within 5%:                 ",
    round(mean(abs(both$runs_bods_txc / both$runs_tnds - 1) <= 0.05), 3), "\n")
cat("BODS TXC lower than TNDS:  ",
    round(mean(both$runs_bods_txc < both$runs_tnds), 3), "\n")
cat("BODS TXC higher than TNDS: ",
    round(mean(both$runs_bods_txc > both$runs_tnds), 3), "\n")

# --- do the two TransXChange sources describe a route the same way? --------
#
# This decides whether a merged feed could be de-duplicated at all.
# gtfs_deduplicate() matches on route number, stops and times, so it can only
# drop a duplicate journey where the two sources agree about the stops it
# calls at. Measured as the Jaccard of the two stop sets per service, which is
# strictly harsher than the overlap coefficient the matching itself uses.
cat("\n=== stop-set agreement, TNDS against BODS TransXChange ===\n")
stops_by <- rbindlist(lapply(c("tnds", "bods_txc"), function(q) {
  x <- as.data.table(summaries[[q]]$stops)
  if (!nrow(x)) return(NULL)
  x[, node := paste(q, route_id, sep = "::")][, list(node, stop_id)]
}), fill = TRUE)
stops_by <- merge(stops_by, members[, list(node, source, service)],
                  by = "node")
sets <- stops_by[, list(stops = list(unique(stop_id))),
                 by = list(service, source)]
sw <- dcast(sets, service ~ source, value.var = "stops")
sw <- sw[!vapply(tnds, is.null, TRUE) & !vapply(bods_txc, is.null, TRUE)]
if (nrow(sw)) {
  sw[, n_t := vapply(tnds, length, 0L)]
  sw[, n_x := vapply(bods_txc, length, 0L)]
  sw[, shared := mapply(function(a, b) length(intersect(a, b)),
                        tnds, bods_txc)]
  sw[, jaccard := shared / (n_t + n_x - shared)]
  cat("services with a stop set in both:", nrow(sw), "\n")
  cat("identical stop sets:   ", sw[jaccard == 1, .N],
      sprintf("(%.1f%%)", 100 * mean(sw$jaccard == 1)), "\n")
  cat("Jaccard >= 0.95:       ", sw[jaccard >= 0.95, .N],
      sprintf("(%.1f%%)", 100 * mean(sw$jaccard >= 0.95)), "\n")
  cat("Jaccard >= 0.80:       ", sw[jaccard >= 0.80, .N],
      sprintf("(%.1f%%)", 100 * mean(sw$jaccard >= 0.80)), "\n")
  stopsets <- sw[, list(service, n_t, n_x, shared,
                        jaccard = round(jaccard, 4))]
} else {
  stopsets <- data.table()
}

out <- list(year = YEAR, window = win, services = svc[],
            carried = t1, running = t2, regions = reg, union = u,
            stopsets = stopsets)
saveRDS(out, file.path(cfg$out_dir,
                       sprintf("source_triangulation_%d.Rds", YEAR)))
cat("\nwrote", file.path(cfg$out_dir,
                         sprintf("source_triangulation_%d.Rds", YEAR)), "\n")
