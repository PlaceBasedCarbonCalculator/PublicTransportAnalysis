# Seed list for the route-subset audit.
#
# One row per route (operator + line) with its trips on the check day in the
# three November feeds (TNDS, BODS TransXChange converted by UK2GTFS, DfT's
# BODS GTFS), the filter-independent "raw potential" from the TransXChange
# index (journeys in the files in force that day), departures at a reference
# stop, a cause class, an ease-of-validation score and a priority.
#
# usage (repo root): Rscript scripts/route_subset_audit/seed_routes.R [out csv]
suppressMessages({ library(data.table); library(UK2GTFS) })
out_path <- commandArgs(TRUE)[1]
if (is.na(out_path)) out_path <- "data/route_subset/seed_routes.csv"
dir.create(dirname(out_path), showWarnings = FALSE, recursive = TRUE)

noc <- targets::tar_read(noc)
feeds <- c(tnds = "data/stop_gap/stopfreq_tnds_nov.Rds",
           bods_txc = "data/stop_gap/stopfreq_bods_txc_nov.Rds",
           bods_gtfs = "data/stop_gap/stopfreq_bods_gtfs_nov.Rds")
bods_gtfs_zip <- "D:/OneDrive - University of Leeds/Data/UK2GTFS/OpenBusData/GTFS/20261111/itm_all_gtfs.zip"
norm_line <- function(x) toupper(gsub("\\s+", "", x))

# ---- per-feed route summaries on the day ---------------------------------
feed_routes <- function(src, path) {
  x <- readRDS(path); tt <- x$tt; day <- x$day
  on <- tt$sdates[date == day, unique(service_id)]
  tr <- tt$trips[service_id %in% on, list(trip, route_id)]
  mult <- if (is.null(tt$freq) || nrow(tt$freq) == 0) NULL else {
    f <- copy(tt$freq); f[, n := pmax(ceiling((end - start) / headway), 1)]
    f[, list(mult = sum(n)), by = trip] }
  if (!is.null(mult)) tr <- merge(tr, mult, by = "trip", all.x = TRUE) else tr[, mult := NA_real_]
  tr[is.na(mult), mult := 1]
  rt <- copy(tt$routes)
  if (src == "bods_gtfs") {
    ag <- as.data.table(read.csv(unz(bods_gtfs_zip, "agency.txt"), colClasses = "character",
                                 encoding = "UTF-8"))
    rt[, agency_code := ag$agency_noc[match(agency_id, ag$agency_id)]]
  } else rt[, agency_code := agency_id]
  rt[, opkey := noc_operator_key(agency_code, agency_name, noc)]
  rt[, line := norm_line(route_short_name)]
  tr <- merge(tr, rt[, list(route_id, opkey, agency_name, agency_code, line)], by = "route_id")
  st <- tt$st[trip %in% tr$trip, list(trip, stop)]
  st <- merge(st, tr[, list(trip, opkey, line, mult)], by = "trip")
  # departures per stop per route node, frequency multiplier applied
  ds <- st[, list(n = sum(mult)), by = list(opkey, line, stop)]
  ds[, stop_id := tt$stops$stop_id[stop]][, stop := NULL]
  node <- tr[, list(trips = sum(mult), n_routes = uniqueN(route_id),
                    agency = paste(sort(unique(agency_name)), collapse = " / "),
                    code = paste(sort(unique(agency_code)), collapse = "|")),
             by = list(opkey, line)]
  node[, src := src]
  ds[, src := src]
  stops <- unique(tt$stops[, list(stop_id, stop_name)])
  rm(x, tt); gc()
  list(node = node, ds = ds, stops = stops)
}
parts <- Map(feed_routes, names(feeds), feeds)
node <- rbindlist(lapply(parts, `[[`, "node"))
ds <- rbindlist(lapply(parts, `[[`, "ds"))
stop_names <- unique(rbindlist(lapply(parts, `[[`, "stops")), by = "stop_id")
rm(parts); gc()
node[, id := .I]
cat("nodes", nrow(node), "\n"); print(node[, .N, by = src])

# ---- link the same route across feeds -----------------------------------
# 1. same operator (NOC register identity) and line; 2. same line and >= 0.3
# Jaccard of the stops served (operator unresolved or named differently).
uf <- seq_len(nrow(node))
find <- function(i) { while (uf[i] != i) { uf[i] <<- uf[uf[i]]; i <- uf[i] }; i }
link <- function(i, j) { a <- find(i); b <- find(j); if (a != b) uf[max(a, b)] <<- min(a, b) }
resolved <- !grepl("^\ragency_id\r", node$opkey)
same <- node[resolved, list(ids = list(id)), by = list(opkey, line)][lengths(ids) > 1]
for (v in same$ids) for (k in v[-1]) link(v[1], k)
ds <- merge(ds, node[, list(src, opkey, line, id)], by = c("src", "opkey", "line"))
stopsets <- ds[, list(stops = list(unique(stop_id))), by = list(id, line)]
by_line <- split(stopsets, stopsets$line)
for (L in by_line) {
  if (nrow(L) < 2) next
  srcs <- node$src[L$id]
  for (i in seq_len(nrow(L) - 1)) for (j in (i + 1):nrow(L)) {
    if (srcs[i] == srcs[j] || find(L$id[i]) == find(L$id[j])) next
    # two operators the register identifies, and they differ: not one route
    # (Phil Anslow's route 1 and Stagecoach's route 1 share Cwmbran's streets)
    if (resolved[L$id[i]] && resolved[L$id[j]] && node$opkey[L$id[i]] != node$opkey[L$id[j]]) next
    a <- L$stops[[i]]; b <- L$stops[[j]]
    jac <- length(intersect(a, b)) / length(union(a, b))
    if (jac >= 0.3) link(L$id[i], L$id[j])
  }
}
node[, grp := vapply(id, find, 1L)]

# ---- reference stop: busiest stop of the route in its fullest feed --------
ds[, grp := node$grp[id]]
top <- ds[, list(n = sum(n)), by = list(grp, stop_id)][order(grp, -n)][, .SD[1], by = grp]
at_ref <- merge(ds, top[, list(grp, stop_id)], by = c("grp", "stop_id"))
at_ref <- dcast(at_ref[, list(n = sum(n)), by = list(grp, src)], grp ~ src, value.var = "n", fill = 0)
setnames(at_ref, names(at_ref)[-1], paste0("ref_", names(at_ref)[-1]))
top <- merge(top[, list(grp, ref_stop = stop_id)], stop_names, by.x = "ref_stop", by.y = "stop_id", all.x = TRUE)

# ---- one row per route group --------------------------------------------
# every link is within one line, so a group has one line
wide <- dcast(node, grp + line ~ src, value.var = "trips", fun.aggregate = sum, fill = 0)
for (s in names(feeds)) if (!s %in% names(wide)) wide[, (s) := 0]
nm <- node[, list(operators = paste(unique(agency), collapse = " ; "),
                  nocs = paste(unique(unlist(strsplit(code, "|", fixed = TRUE))), collapse = "|"),
                  opkeys = paste(unique(opkey[resolved[id]]), collapse = "|")), by = grp]
wide <- merge(wide, nm, by = "grp")
wide <- merge(wide, at_ref, by = "grp", all.x = TRUE)
wide <- merge(wide, top, by = "grp", all.x = TRUE)
for (c in grep("^ref_(tnds|bods)", names(wide), value = TRUE)) wide[is.na(get(c)), (c) := 0]

# ---- raw potential from the TransXChange index ----------------------------
# Joined by operator name (UK2GTFS writes OperatorShortName as agency_name;
# the index carries it as opname) and line, with the NOC-register key as a
# second route in. Journeys counted once per service code and line: the
# largest file in force.
day <- readRDS(feeds[["tnds"]])$day
norm_op <- function(x) UK2GTFS:::noc_normalise_name(x)
raw_potential <- function(path) {
  ix <- fread(path, colClasses = "character")
  ix <- ix[start <= as.character(day) & (end == "" | end >= as.character(day)) & holidays_only != "1"]
  ix[, n_vj := as.integer(n_vj)]
  ix <- ix[, list(line = norm_line(unlist(strsplit(lines, ";", fixed = TRUE)))),
           by = list(file, noc, opname, service_code, n_vj)]
  ix[, opkey := noc_operator_key(noc, opname, noc = noc_tbl)]
  ix[, opn := norm_op(sub(";.*", "", opname))]
  ix <- unique(ix, by = c("noc", "service_code", "line", "n_vj"))
  ix
}
noc_tbl <- noc
rt <- raw_potential("data/txc_index/tnds_20261111.csv")
rb <- raw_potential("data/txc_index/bods_20261111.csv")
node[, opn := norm_op(sub(" / .*", "", agency))]
join_raw <- function(r, pref) {
  by_name <- merge(node[, list(grp, opn, line)], r[, list(opn, line, service_code, n_vj)],
                   by = c("opn", "line"), allow.cartesian = TRUE)
  by_key <- merge(node[resolved, list(grp, opkey, line)], r[, list(opkey, line, service_code, n_vj)],
                  by = c("opkey", "line"), allow.cartesian = TRUE)
  m <- unique(rbindlist(list(by_name[, list(grp, service_code, n_vj)], by_key[, list(grp, service_code, n_vj)])))
  m <- m[, list(n_files = .N, raw = sum(n_vj), raw_max = sum(tapply(n_vj, service_code, max))), by = grp]
  setnames(m, c("n_files", "raw", "raw_max"), paste0(pref, c("_files", "_raw", "_raw_max")))
  m
}
wide <- merge(wide, join_raw(rt, "tnds"), by = "grp", all.x = TRUE)
wide <- merge(wide, join_raw(rb, "bods"), by = "grp", all.x = TRUE)
for (c in grep("_(files|raw|raw_max)$", names(wide), value = TRUE)) wide[is.na(get(c)), (c) := 0]

# ---- classes, ease, priority --------------------------------------------
wide[, hi := pmax(tnds, bods_txc, bods_gtfs)]
wide[, lo := pmin(tnds, bods_txc, bods_gtfs)]
wide[, diff := hi - lo][, rel := ifelse(hi > 0, diff / hi, 0)]
# The two UK2GTFS conversions are compared first (same converter, same
# filter, different source). BODS GTFS only says whether the DfT pipeline
# had the journeys; it carries TNDS for London, Scotland and Wales and
# duplicates versions elsewhere, so it is never the reference on its own.
near <- function(a, b, tol = 0.15) abs(a - b) <= tol * pmax(a, b, 1)
wide[, class := fcase(
  bods_txc == 0 & tnds > 0 & bods_raw_max == 0 & near(bods_gtfs, tnds), "not in BODS TXC; BODS GTFS carries TNDS (L/S/W)",
  bods_txc == 0 & tnds > 0 & bods_raw_max == 0, "bods absent: no file in force",
  tnds == 0 & bods_txc > 0 & tnds_raw_max == 0, "tnds absent: no file in force",
  near(tnds, bods_txc) & bods_gtfs > 1.2 * tnds, "agree; bods gtfs high (dft duplicates)",
  near(tnds, bods_txc) & bods_gtfs < 0.8 * tnds, "agree; bods gtfs low",
  near(tnds, bods_txc), "agree",
  tnds < bods_txc & tnds_raw_max >= 0.8 * bods_raw_max, "tnds low: filter candidate",
  tnds < bods_txc, "tnds low: raw smaller",
  bods_txc < tnds & bods_raw_max >= 0.8 * tnds_raw_max, "bods txc low: filter candidate",
  bods_txc < tnds & bods_gtfs >= 0.85 * tnds, "bods txc low: raw smaller but BODS GTFS has it",
  bods_txc < tnds, "bods txc low: raw smaller",
  default = "other")]
wide[, filter_candidate := grepl("filter candidate|BODS GTFS has it", class)]
ease_of <- function(op) fcase(
  grepl("first|stagecoach|brighton|go north east|metrobus|oxford bus|go south coast|bluestar|plymouth citybus|konect|hedingham|chambers|thames travel|carousel|salisbury reds|southern vectis|morebus|go east anglia|go-ahead|go ahead", op, ignore.case = TRUE), 3L,
  grepl("arriva|transdev|harrogate|blackpool|lothian|nottingham city|reading buses|trentbarton|trent barton|diamond|rotala|yorkshire tiger|keighley|burnley|lancashire united|preston bus|cardiff bus|newport|translink|mcgill|xplore|ensign|warrington|halton|tfl|london", op, ignore.case = TRUE), 2L,
  default = 1L)
wide[, ease := ease_of(operators)]
docs <- fread("data/stop_pdf_documents.csv", colClasses = "character")
docs[, line := norm_line(route)]
docs[, doc_op := tolower(sub("[_ -].*", "", document))]
wide[, pdf := vapply(seq_len(.N), function(i) {
  d <- docs[line == wide$line[i]]
  if (!nrow(d)) return("")
  ops <- tolower(wide$operators[i])
  hit <- d[vapply(doc_op, function(o) grepl(substr(o, 1, 4), ops, fixed = TRUE), TRUE)]
  if (nrow(hit)) paste(unique(hit$document), collapse = "; ") else ""
}, "")]
# priority: the two-conversion gap (what the filter can change), weighted by
# how easy the operator is to validate; disagreements with BODS GTFS alone
# are the DfT's problem and get a quarter weight
wide[, gap := abs(tnds - bods_txc)]
wide[, priority := round((gap + 0.25 * abs(bods_gtfs - pmax(tnds, bods_txc)) * (gap < 10)) * ease *
                           (rel >= 0.15) * (diff >= 10), 0)]
setorder(wide, -filter_candidate, -priority)
setcolorder(wide, c("grp", "line", "operators", "nocs", "class", "filter_candidate", "priority", "tnds", "bods_txc",
                    "bods_gtfs", "tnds_raw_max", "bods_raw_max", "tnds_files", "bods_files",
                    "ref_stop", "stop_name", "ref_tnds", "ref_bods_txc", "ref_bods_gtfs",
                    "diff", "rel", "ease", "pdf"))
fwrite(wide, out_path)
cat("routes", nrow(wide), "written", out_path, "\n")
print(wide[, .N, by = class][order(-N)])
print(wide[priority > 0, list(n = .N, gap = sum(gap), trips_diff = sum(diff)), by = list(class, ease)][order(-gap)])
print(wide[filter_candidate == TRUE, list(n = .N, gap = sum(gap)), by = list(op = sub(" ; .*| / .*", "", operators))][order(-gap)][1:40])
print(head(wide[, list(line, operators = substr(operators, 1, 40), class, tnds, bods_txc, bods_gtfs,
                       tnds_raw_max, bods_raw_max, ease, pdf = nzchar(pdf))], 40))
