# Two cities, one day, three timetables and a referee
#
# The stop report (R/stop_gap.R) compares TNDS with the DfT's BODS GTFS
# nationally. When they disagree it cannot say which is right. This takes two
# cities and adds a third rendering of the same timetables, bustimes.org, as a
# referee:
#
#  * London, where the DfT builds BODS GTFS from TNDS, so BODS GTFS and the
#    TNDS feed UK2GTFS converts share their TransXChange; and
#  * the West Midlands county, where BODS GTFS is built from operators' own
#    BODS TransXChange, which is compared both with the BODS TransXChange
#    UK2GTFS converts (same data, other converter) and with TNDS.
#
# One day, Thursday 19 November 2026, from snapshots all taken on 18 November.
# bustimes.org only shows dates from today on, so the day had to be one that
# could still be scraped; it is the day after the snapshot, before a TNDS
# registration has time to run out. See scripts/bustimes/README.md.

#' The 18 November 2026 snapshots
#'
#' All three downloaded on the morning of 18 November. `ref` floors to Monday
#' 16 November, so the compact timetables cover 16-29 November and contain
#' the comparison day.
stop_city_snapshot <- function() {
  list(ref = "2026-11-19", snapshot_date = "2026-11-18",
       tnds = "gtfs/tnds_20261118_merged.zip",
       bods_gtfs = "OpenBusData/GTFS/20261118/itm_all_gtfs.zip",
       bods_txc = "gtfs/bods_txc_20261118.zip")
}

#' The comparison day
stop_city_day <- function() as.Date("2026-11-19")

#' The second run: Friday 20 November, bus and coach, three TNDS editions
#'
#' The same 18 November downloads, converted again with UK2GTFS 0.4.1 and
#' `stop_locations = "naptan_fill"`, so stops missing from the pipeline's
#' NaPTAN copy keep their calls. TNDS is converted three ways (2.5, 2.1 and
#' the blend, see tnds_edition()), and the BODS Coach feed of the same day
#' supplies coach to the TransXChange side. bustimes.org was scraped for bus
#' and coach (scripts/bustimes, --modes bus,coach).
stop_city_snapshot_1120 <- function() {
  list(ref = "2026-11-20", snapshot_date = "2026-11-18",
       tnds25 = "gtfs/tnds_20261118_v25_naptan_fill_merged.zip",
       tnds21 = "gtfs/tnds_20261118_v21_naptan_fill_merged.zip",
       tndsblend = "gtfs/tnds_20261118_blend_naptan_fill_merged.zip",
       bods_txc = "gtfs/bods_txc_20261118_naptan_fill.zip",
       bods_coach = "gtfs/bods_coach_20261118_naptan_fill.zip",
       bods_gtfs = "OpenBusData/GTFS/20261118/itm_all_gtfs.zip")
}

#' The second run's day
stop_city_day_1120 <- function() as.Date("2026-11-20")

#' The second run's comparisons: each TNDS edition in both cities, and BODS
#' TransXChange in the West Midlands
stop_city_comparisons_1120 <- function() {
  ed <- c(tnds25 = "TNDS 2.5", tnds21 = "TNDS 2.1", tndsblend = "TNDS blend")
  data.table::data.table(
    map = c(paste0("london_", names(ed)), "wm_bods_txc",
            paste0("wm_", names(ed))),
    city = c(rep("London", 3), rep("West Midlands", 4)),
    txc = c(names(ed), "bods_txc", names(ed)),
    label = c(paste("London:", ed), "West Midlands: BODS TransXChange",
              paste("West Midlands:", ed)))
}

#' The two study areas, by the stop's ATCO administrative area
#'
#' Greater London (490) and the West Midlands county (430), as named by
#' UK2GTFS's ATCO area table (coverage_atco_areas()). The prefix is the
#' NaPTAN authority that issued the stop code, which is the county boundary
#' for practical purposes and needs no polygon.
stop_city_areas <- function() c(London = "490", "West Midlands" = "430")

#' The three comparisons: which feed plays the TransXChange-GTFS part
#'
#' London has only TNDS (BODS TransXChange carries a few London operators,
#' and BODS GTFS is built from TNDS there). The West Midlands is compared
#' twice: with the BODS TransXChange UK2GTFS converts (the same data the DfT
#' builds BODS GTFS from, through another converter) and with TNDS.
stop_city_comparisons <- function() {
  data.table::data.table(
    map = c("london_tnds", "wm_bods_txc", "wm_tnds"),
    city = c("London", "West Midlands", "West Midlands"),
    txc = c("tnds", "bods_txc", "tnds"),
    label = c("London: TNDS", "West Midlands: BODS TransXChange",
              "West Midlands: TNDS"))
}

#' The seven agreement categories, in the order and colours asked for
stop_city_categories <- function() {
  data.table::data.table(
    cat = 1:7,
    label = c("All agree",
              "bustimes + TXC agree, BODS GTFS differs",
              "bustimes + BODS GTFS agree, TXC differs",
              "None agree, TXC closer to bustimes",
              "None agree, BODS GTFS closer to bustimes",
              "TXC + BODS GTFS agree, bustimes differs",
              "All significantly disagree"),
    short = c("all agree", "BODS GTFS odd one out", "TXC odd one out",
              "TXC closer", "BODS GTFS closer", "bustimes odd one out",
              "all disagree"),
    colour = c("#9E9E9E", "#1B5E20", "#8B0000", "#81C784", "#EF9A9A",
               "#FBC02D", "#000000"))
}

#' Do two departure counts agree?
#'
#' Within `tol_abs` departures or `tol_rel` of the larger, whichever is more
#' generous: two buses at a stop with ten is not agreement, two at a stop
#' with three hundred is.
counts_agree <- function(x, y, tol_abs = 2, tol_rel = 0.10) {
  abs(x - y) <= pmax(tol_abs, tol_rel * pmax(x, y))
}

#' Classify a stop by which of the three counts agree
#'
#' @param b bustimes.org departures
#' @param g BODS GTFS departures
#' @param t the TransXChange-converted feed's departures
#' @param closer when no pair agrees, the nearer feed is "closer" only if its
#'   distance from bustimes is at most this fraction of the other's;
#'   otherwise everything disagrees
#' @return integer category, 1-7 (stop_city_categories())
classify_agreement <- function(b, g, t, tol_abs = 2, tol_rel = 0.10,
                               closer = 0.5) {
  bt <- counts_agree(b, t, tol_abs, tol_rel)
  bg <- counts_agree(b, g, tol_abs, tol_rel)
  gt <- counts_agree(g, t, tol_abs, tol_rel)
  et <- abs(b - t)
  eg <- abs(b - g)
  data.table::fcase(
    bt & bg & gt, 1L,
    # bustimes agrees with both feeds but they are just far enough apart not
    # to agree with each other: the nearer one is the one that agrees
    bt & bg, data.table::fifelse(et <= eg, 2L, 3L),
    bt, 2L,
    bg, 3L,
    gt, 6L,
    et <= closer * eg, 4L,
    eg <= closer * et, 5L,
    default = 7L)
}

#' Normalise a line name for matching across sources
line_key <- function(x) toupper(gsub("[^A-Za-z0-9]", "", ifelse(is.na(x), "", x)))

#' One feed's departures on the day, per stop and per stop and line
#'
#' The same rules as stop_date_departures() (GTFS service days, frequency
#' trips expanded), restricted to the day and the study areas.
#'
#' @param path a stop_frequency_source() file
#' @param prefixes ATCO area prefixes to keep
#' @return list(stop = stop_id, n; line = stop_id, line, agency, n) with stop
#'   ids upper-cased (BODS writes some letter suffixes in lower case)
feed_day_counts <- function(path, day, prefixes) {
  x <- readRDS(path)
  tt <- x$tt
  stopifnot(day >= x$window$startdate, day <= x$window$enddate)
  sid <- toupper(tt$stops$stop_id)
  keep <- which(substr(sid, 1, 3) %in% prefixes)
  st <- tt$st[stop %in% keep]
  mult <- trip_departure_multiplier(tt)
  runs <- tt$sdates[date == day, list(service_id)]
  tr <- tt$trips[service_id %in% runs$service_id, list(trip, route_id)]
  ss <- st[trip %in% tr$trip, list(n = .N), by = list(stop, trip)]
  ss <- merge(ss, mult, by = "trip", all.x = TRUE)
  ss[is.na(mult), mult := 1]
  ss[, n := n * mult][, mult := NULL]
  ss <- merge(ss, tr, by = "trip")
  routes <- tt$routes
  # Bus-only files written before route types were kept (stop_frequency_source)
  if (!"route_type" %in% names(routes)) routes <- routes[, route_type := 3L]
  ss <- merge(ss, routes[, list(route_id, route_short_name, agency_name,
                                route_type)],
              by = "route_id", all.x = TRUE)
  ss[, stop_id := sid[stop]]
  line <- ss[, list(n = sum(n)),
             by = list(stop_id, line = line_key(route_short_name),
                       agency = agency_name,
                       mode = data.table::fifelse(route_type == 200L, "coach",
                                                  "bus"))]
  list(stop = ss[, list(n = sum(n)), by = stop_id], line = line)
}

#' bustimes.org departures per stop and per stop and line
bustimes_day_counts <- function(csv_path, prefixes) {
  b <- data.table::fread(csv_path, colClasses = list(
    character = c("stop", "line_name", "operator")))
  if (!"mode" %in% names(b)) b[, mode := "bus"]
  b[, stop_id := toupper(stop)]
  b <- b[substr(stop_id, 1, 3) %in% prefixes & departures > 0]
  list(stop = b[, list(n = sum(departures)), by = stop_id],
       line = b[, list(n = sum(departures)),
                by = list(stop_id, line = line_key(line_name),
                          agency = operator, mode)])
}

#' One feed's bus and coach timetable, compacted, for the city comparison
#'
#' stop_frequency_source() without its national stop counts, keeping the
#' route types in `modes` and recording each route's type, which the mode
#' check needs. It is a separate function so that the stop_gap and stop_pdf
#' targets built on stop_frequency_source() are not invalidated.
#'
#' @param modes route types after map_route_type_simple(): 3 bus, 200 coach
#' @return path to data/stop_gap/stopfreq_<src><tag>.Rds, readable by
#'   feed_day_counts()
stop_city_source <- function(src, spec, day, ..., modes = c(3L, 200L),
                             tag = "", cfg = load_cfg()) {
  win <- study_window(spec$ref)
  stopifnot(day >= win$startdate, day <= win$enddate)
  message("stop_city: reading ", src, " (", spec[[src]], ")")
  gtfs <- read_feed(spec[[src]], cfg)
  gtfs$routes$route_type <- map_route_type_simple(gtfs$routes$route_type)
  keep <- as.character(gtfs$routes$route_id[gtfs$routes$route_type %in% modes])
  gtfs$trips <- gtfs$trips[as.character(gtfs$trips$route_id) %in% keep, ]
  tt <- compact_timetable(gtfs, win)
  rt <- data.table::data.table(route_id = as.character(gtfs$routes$route_id),
                               route_type = as.integer(gtfs$routes$route_type))
  tt$routes <- merge(tt$routes, unique(rt, by = "route_id"), by = "route_id",
                     all.x = TRUE)
  dir <- file.path(cfg$out_dir, "stop_gap")
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  out <- file.path(dir, sprintf("stopfreq_%s%s.Rds", src, tag))
  saveRDS(list(source = src, feed = spec[[src]], window = win, day = day,
               modes = modes, tt = tt), out)
  out
}

#' Add a supplementary feed's lines to a feed, where the feed lacks them
#'
#' The series takes coach from the BODS Coach feed (convert_bods_coach()) and
#' bus from TNDS or BODS TransXChange. For the city comparison the coach feed
#' is added to each TransXChange-built feed at every stop and line that feed
#' does not already serve, so a coach the TNDS conversion also carries (Green
#' Line, for instance) is not counted twice.
supplement_counts <- function(fc, sup) {
  have <- fc$line[, paste(stop_id, line)]
  add <- sup$line[!paste(stop_id, line) %in% have]
  line <- data.table::rbindlist(list(fc$line, add), use.names = TRUE)
  list(stop = line[, list(n = sum(n)), by = stop_id], line = line)
}

#' Stop agreement maps for London and the West Midlands
#'
#' @param feeds named vector of stop_frequency_source() paths (tnds,
#'   bods_txc, bods_gtfs) for the main snapshot
#' @param feeds_prev the same for the earlier snapshot, or NULL; used only for
#'   the table of how far the snapshot date moves the categories
#' @param bustimes_csv scripts/bustimes/parse_timetables.py output
#' @param naptan NaPTAN stops (the naptan target), for positions
#' @param cmp the comparisons (stop_city_comparisons()); every `txc` source
#'   must be in `feeds`, as must bods_gtfs
#' @param supplement NULL, or a named path (bods_coach) whose lines are added
#'   to each TransXChange-built feed where it lacks them (supplement_counts())
#' @param out_name file name stem; the default keeps the 19 November output
#' @return path to data/<out_name>_<day>.Rds
stop_city_analysis <- function(feeds, feeds_prev = NULL, bustimes_csv, naptan,
                               day = stop_city_day(), tol_abs = 2,
                               tol_rel = 0.10, closer = 0.5,
                               cmp = stop_city_comparisons(),
                               supplement = NULL, out_name = "stop_city",
                               cfg = load_cfg()) {
  areas <- stop_city_areas()
  cats <- stop_city_categories()
  fsrc <- names(feeds)
  srcs <- c("bustimes", fsrc)
  stopifnot("bods_gtfs" %in% fsrc, all(cmp$txc %in% fsrc))

  bt <- bustimes_day_counts(bustimes_csv, areas)
  sup <- if (!is.null(supplement)) {
    feed_day_counts(supplement[[1]], day = day, prefixes = areas)
  }
  count_set <- function(paths) {
    fc <- lapply(paths, feed_day_counts, day = day, prefixes = areas)
    if (!is.null(sup)) {
      for (v in intersect(unique(cmp$txc), names(fc))) {
        fc[[v]] <- supplement_counts(fc[[v]], sup)
      }
    }
    fc
  }
  fc <- count_set(feeds)

  # --- the stop table: one row per stop, every source's count --------------
  wide <- function(fc) {
    s <- data.table::rbindlist(c(
      lapply(names(fc), function(src) fc[[src]]$stop[, list(stop_id, n, source = src)]),
      list(bt$stop[, list(stop_id, n, source = "bustimes")])))
    s <- data.table::dcast(s, stop_id ~ source, value.var = "n", fill = 0)
    for (v in srcs) if (!v %in% names(s)) s[, (v) := 0]
    s[, city := names(areas)[match(substr(stop_id, 1, 3), areas)]]
    s[]
  }
  s <- wide(fc)

  nap <- data.table::as.data.table(naptan)[, list(stop_id = toupper(stop_id),
                                                  stop_name, stop_lon, stop_lat)]
  nap <- unique(nap, by = "stop_id")
  s <- merge(s, nap, by = "stop_id", all.x = TRUE)
  # NaPTAN can lack a stop a feed still uses; take the feed's position then
  if (s[is.na(stop_lon), .N]) {
    fpos <- data.table::rbindlist(lapply(feeds, function(p) {
      tt <- readRDS(p)$tt
      tt$stops[, list(stop_id = toupper(stop_id), fname = stop_name,
                      flon = stop_lon, flat = stop_lat)]
    }))
    fpos <- unique(fpos[!is.na(flon)], by = "stop_id")
    s <- merge(s, fpos, by = "stop_id", all.x = TRUE)
    s[is.na(stop_lon), `:=`(stop_name = fname, stop_lon = flon, stop_lat = flat)]
    s[, c("fname", "flon", "flat") := NULL]
  }
  no_pos <- s[is.na(stop_lon)]
  s <- s[!is.na(stop_lon)]
  pts <- sf::st_transform(sf::st_as_sf(s[, list(stop_lon, stop_lat)],
                                       coords = c("stop_lon", "stop_lat"),
                                       crs = 4326), 27700)
  xy <- sf::st_coordinates(pts)
  s[, `:=`(x = xy[, 1], y = xy[, 2])]

  classify_set <- function(s, ta = tol_abs, tr = tol_rel, cl = closer) {
    data.table::rbindlist(lapply(seq_len(nrow(cmp)), function(i) {
      d <- s[city == cmp$city[i]]
      d <- d[, list(map = cmp$map[i], stop_id, b = bustimes, g = bods_gtfs,
                    t = get(cmp$txc[i]))]
      d <- d[b + g + t > 0]
      d[, cat := classify_agreement(b, g, t, ta, tr, cl)][]
    }))
  }
  cl <- classify_set(s)
  cl <- merge(cl, s[, list(stop_id, stop_name, x, y)], by = "stop_id")

  summ <- function(cl) {
    out <- cl[, list(stops = .N, b = sum(b), g = sum(g), t = sum(t)),
              by = list(map, cat)]
    out[, share := stops / sum(stops), by = map][]
  }
  summary <- summ(cl)

  # Sensitivity of the shares to the agreement rule
  sens <- data.table::rbindlist(lapply(list(c(1, 0.05), c(2, 0.10), c(3, 0.20)),
                                       function(p) {
    x <- classify_set(s, p[1], p[2])
    x <- x[, list(stops = .N), by = list(map, cat)]
    x[, share := stops / sum(stops), by = map]
    x[, rule := sprintf("%d departures or %d%%", p[1], round(100 * p[2]))][]
  }))

  # --- per stop and line, to say which routes make each colour ------------
  lines <- data.table::rbindlist(c(
    lapply(names(fc), function(src) fc[[src]]$line[, list(stop_id, line, agency,
                                                          mode, n, source = src)]),
    list(bt$line[, list(stop_id, line, agency, mode, n, source = "bustimes")])))
  lines[, city := names(areas)[match(substr(stop_id, 1, 3), areas)]]
  # The operator each source names a line with, for the tables
  line_agency <- lines[, list(n = sum(n)), by = list(city, line, source, agency)]
  line_agency <- line_agency[order(-n), list(agency = agency[1]),
                             by = list(city, line, source)]
  line_agency <- data.table::dcast(line_agency, city + line ~ source,
                                   value.var = "agency")
  lw <- data.table::dcast(lines[, list(n = sum(n)),
                                by = list(stop_id, city, line, source)],
                          stop_id + city + line ~ source, value.var = "n",
                          fill = 0)
  for (v in srcs) if (!v %in% names(lw)) lw[, (v) := 0]
  # Each comparison's stop-line rows with the stop's colour, so that a
  # colour's routes are the lines whose differences make it
  route_rows <- data.table::rbindlist(lapply(seq_len(nrow(cmp)), function(i) {
    d <- lw[city == cmp$city[i], list(map = cmp$map[i], stop_id, line,
                                       b = bustimes, g = bods_gtfs,
                                       t = get(cmp$txc[i]))]
    merge(d, cl[map == cmp$map[i], list(stop_id, cat)], by = "stop_id")
  }))
  routes <- route_rows[, list(stops = data.table::uniqueN(stop_id),
                              b = sum(b), g = sum(g), t = sum(t)),
                       by = list(map, cat, line)]
  route_tot <- route_rows[, list(stops = data.table::uniqueN(stop_id),
                                 b = sum(b), g = sum(g), t = sum(t)),
                          by = list(map, line)]

  # --- the earlier snapshot, for the snapshot-effect table -----------------
  prev <- NULL
  if (!is.null(feeds_prev)) {
    sp <- wide(count_set(feeds_prev))
    sp <- merge(sp, s[, list(stop_id, stop_name, x, y)], by = "stop_id")
    cp <- classify_set(sp)
    prev <- list(summary = summ(cp),
                 moved = merge(cl[, list(map, stop_id, cat_now = cat)],
                               cp[, list(map, stop_id, cat_prev = cat)],
                               by = c("map", "stop_id"), all = TRUE),
                 totals = sp[, lapply(.SD, sum), by = city,
                             .SDcols = intersect(srcs, names(sp))])
  }

  totals <- s[, c(list(stops = .N), lapply(.SD, sum)), by = city,
              .SDcols = srcs]
  fmax <- do.call(pmax, unname(as.list(s[, fsrc, with = FALSE])))
  ftot <- rowSums(s[, fsrc, with = FALSE])
  totals <- merge(totals, s[, list(city, fmax = fmax, ftot = ftot, bustimes)][
    , list(b_zero = sum(bustimes == 0 & fmax > 0),
           b_only = sum(bustimes > 0 & ftot == 0)), by = city], by = "city")

  out <- list(day = day, feeds = feeds, feeds_prev = feeds_prev,
              supplement = supplement, sources = srcs,
              rule = list(tol_abs = tol_abs, tol_rel = tol_rel, closer = closer),
              categories = cats, comparisons = cmp, stops = s[], class = cl[],
              summary = summary[], sensitivity = sens[], routes = routes[],
              route_totals = route_tot[], line_agency = line_agency[],
              lines = lines[], totals = totals[], no_position = no_pos[],
              prev = prev,
              bustimes_pages = bustimes_pages_summary(bustimes_csv))
  out$mode_check <- stop_city_mode_check(out)
  dest <- file.path(cfg$out_dir, sprintf("%s_%s.Rds", out_name,
                                         format(day, "%Y%m%d")))
  saveRDS(out, dest)
  dest
}

#' What the scrape covered, from the files beside the counts
bustimes_pages_summary <- function(csv_path) {
  dir <- dirname(csv_path)
  pg <- file.path(dir, "pages.csv")
  sv <- file.path(dir, "services.csv")
  list(pages = if (file.exists(pg)) data.table::fread(pg) else NULL,
       services = if (file.exists(sv)) data.table::fread(sv) else NULL)
}

#' Stops in a study area where bustimes has nothing but a feed has departures
#'
#' The input to the scrape's completion pass (fetch_timetables.py
#' --from-stops): a service registered in another region but calling here is
#' missing from the region listing, and its stops show up as bustimes zeros.
#' Ordered by the larger feed count, so the busiest are checked first.
bustimes_missing_stops <- function(city_path, out_file, min_dep = 1) {
  x <- readRDS(city_path)
  st <- data.table::copy(x$stops)
  fsrc <- intersect(names(x$feeds), names(st))
  st[, fmax := do.call(pmax, unname(.SD)), .SDcols = fsrc]
  s <- st[bustimes == 0 & fmax >= min_dep][order(-fmax)]
  writeLines(s$stop_id, out_file)
  nrow(s)
}

#' Route-level check of timetable and mode, pair by pair
#'
#' Bus and coach are not always told apart the same way: Green Line 757 is a
#' coach in TNDS and in one of BODS GTFS's two copies, a bus in BODS
#' TransXChange and on bustimes.org. For each city, line and pair of sources
#' (bustimes against every feed; BODS GTFS against each TransXChange-built
#' feed) the line's departures over the city's stops are counted separately
#' as bus and as coach, and compared with the agreement rule:
#'
#' * pass: bus and coach departures each agree
#' * soft pass: departures move between the modes (one source's bus surplus
#'   is, within a factor of two, the other's coach surplus) and the line's
#'   total agrees - a labelling
#'   difference, the service is the same
#' * fail: departures move between the modes and the total does not agree -
#'   investigate
#' * timetable differs: no movement between the modes; the ordinary
#'   disagreement the maps already show
#'
#' Lines are matched by normalised name within the city (line_key()), so two
#' operators' lines of the same number are counted together, as in the route
#' tables. Comparing a label ("bus+coach" against "coach") would call TfL's
#' bus 200 and National Express's coach 200 a mode conflict whenever one
#' source lacks the TfL bus; asking whether departures change mode does not.
#' A line only one source has is not in this table.
#'
#' @param x the stop_city_analysis() result (needs lines, sources,
#'   comparisons and rule)
stop_city_mode_check <- function(x, tol_abs = x$rule$tol_abs,
                                 tol_rel = x$rule$tol_rel) {
  r <- x$lines[, list(n = sum(n),
                      bus = sum(n[mode != "coach"]),
                      coach = sum(n[mode == "coach"]),
                      mode = paste(sort(unique(mode)), collapse = "+"),
                      agency = agency[which.max(n)]),
               by = list(city, line, source)]
  pairs <- unique(rbind(
    data.table::data.table(a = "bustimes", b = setdiff(x$sources, "bustimes")),
    data.table::data.table(a = "bods_gtfs",
                           b = setdiff(unique(x$comparisons$txc), "bods_gtfs"))))
  out <- data.table::rbindlist(lapply(seq_len(nrow(pairs)), function(i) {
    a <- r[source == pairs$a[i], list(city, line, n_a = n, bus_a = bus,
                                      coach_a = coach, mode_a = mode,
                                      agency_a = agency)]
    b <- r[source == pairs$b[i], list(city, line, n_b = n, bus_b = bus,
                                      coach_b = coach, mode_b = mode,
                                      agency_b = agency)]
    m <- merge(a, b, by = c("city", "line"))
    m[, `:=`(a = pairs$a[i], b = pairs$b[i])]
  }))
  out[, tt_agree := counts_agree(n_a, n_b, tol_abs, tol_rel)]
  out[, bus_agree := counts_agree(bus_a, bus_b, tol_abs, tol_rel)]
  out[, coach_agree := counts_agree(coach_a, coach_b, tol_abs, tol_rel)]
  # departures change mode: each mode disagrees, in opposite directions, by
  # amounts of the same size (within a factor of two). Without the size test
  # London 210 - 7,740 TfL buses that BODS TransXChange does not carry, and
  # National Express's coach 210 at 73 against 100 - reads as a mode conflict.
  out[, mode_shift := !bus_agree & !coach_agree &
        sign(bus_a - bus_b) != sign(coach_a - coach_b) &
        pmin(abs(bus_a - bus_b), abs(coach_a - coach_b)) >=
        0.5 * pmax(abs(bus_a - bus_b), abs(coach_a - coach_b))]
  out[, mode_agree := !mode_shift]
  out[, result := data.table::fcase(
    bus_agree & coach_agree, "pass",
    mode_shift & tt_agree, "soft pass",
    mode_shift & !tt_agree, "fail",
    default = "timetable differs")]
  data.table::setcolorder(out, c("city", "a", "b", "line", "result"))
  out[]
}

#' Knit a city report to markdown
render_stop_city_report <- function(city_path, rmd, zones_path = NULL,
                                    output = "stop_disagreement_cities.md",
                                    cfg = load_cfg()) {
  dir.create(cfg$report_dir, showWarnings = FALSE, recursive = TRUE)
  env <- new.env(parent = globalenv())
  env$city_path <- normalizePath(city_path)
  env$map_zones_path <- if (!is.null(zones_path)) map_zones_file(zones_path)
  old_wd <- setwd(cfg$report_dir)
  on.exit(setwd(old_wd), add = TRUE)
  knitr::knit(input = basename(rmd), output = output, envir = env, quiet = TRUE)
  file.path(cfg$report_dir, output)
}
