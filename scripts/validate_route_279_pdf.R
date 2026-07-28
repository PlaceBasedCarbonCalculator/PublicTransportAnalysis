# Validate the 2026 GTFS renderings of bus route 279 against the operator's
# published running schedules.
#
# reports/bus_source_comparison.md flags the 279 (Waltham Cross - Manor House,
# Arriva London North) as the largest TNDS / BODS GTFS journey-count
# disagreement in the 2026 snapshot. This script settles which source is right
# by comparing all three feeds against the four TfL running schedules in
# data/example_timetables/, and prints every table in
# reports/route_279_pdf_validation.md.
#
# Run from the repo root:  Rscript scripts/validate_route_279_pdf.R

suppressPackageStartupMessages({
  library(data.table)
})
source("R/config.R")
cfg <- load_cfg()

WIN_START <- as.Date("2026-02-02")
WIN_END   <- as.Date("2026-03-01")
DATES     <- seq(WIN_START, WIN_END, by = "day")
DOW_COLS  <- c("monday", "tuesday", "wednesday", "thursday", "friday",
               "saturday", "sunday")

# Manor House Station: the one timing point every 279 journey passes, in both
# directions. AD803 in the running schedules, these NaPTAN codes in the feeds.
MANOR <- c("490000142F", "490000142G")

# The 279 as each 2026 feed holds it. BODS GTFS splits it across two routes
# under two agency records for the same operator; both are kept separate here
# because that split is the finding.
FEEDS <- list(
  tnds = list(
    zip = "gtfs/tnds_20260204_merged.zip",
    routes = c(`TNDS` = "2166")),
  bods_txc = list(
    zip = "gtfs/bods_txc_20260204.zip",
    routes = c(`BODS TXC` = "693")),
  bods_gtfs = list(
    zip = file.path(cfg$data_root, "OpenBusData/GTFS/20260204/itm_all_gtfs.zip"),
    routes = c(`BODS GTFS OP839` = "138482", `BODS GTFS OP401` = "10003"))
)

PDFS <- c(MT = "data/example_timetables/Schedule_279-MT.pdf",
          Fr = "data/example_timetables/Schedule_279-Fr.pdf",
          Sa = "data/example_timetables/Schedule_279-Sa.pdf",
          Su = "data/example_timetables/Schedule_279-Su.pdf")

# ---------------------------------------------------------------------------
# Published schedules
# ---------------------------------------------------------------------------

#' Extract one running-schedule page into a long table of timing-point times
#'
#' The trip tables are read from the PDF word coordinates rather than from
#' rendered text, so each time is attached to the timing point whose column it
#' falls in. Blank cells (a journey that misses a timing point, or starts from
#' the garage) would silently shift a position-based parse.
pdf_page_times <- function(page, page_no) {
  p <- as.data.table(page)
  if (!nrow(p)) return(NULL)

  # The "Dep." header row marks the x centre of every time column
  dep <- p[text == "Dep."]
  if (nrow(dep) < 5) return(NULL)          # not a trip-table page
  dep <- dep[y == max(y)][order(x)]
  colx <- dep$x

  # The transit-node row above it names those columns
  above <- p[y < min(dep$y) - 5]
  n_codes <- above[, .(n = sum(grepl("^[A-Z][A-Z0-9]{4}$", text))), by = y]
  ynode <- n_codes[n >= length(colx) - 2][which.max(y)]$y
  nodes <- above[y == ynode][order(x)]
  nearest <- function(xx) which.min(abs(colx - xx))
  colnodes <- rep(NA_character_, length(colx))
  colnodes[vapply(nodes$x, nearest, integer(1))] <- nodes$text
  # the garage node appears at both ends of the row; keep the two distinct
  colnodes <- make.unique(fifelse(is.na(colnodes), "?", colnodes), sep = "#")

  rows <- p[y > max(dep$y)]
  rbindlist(lapply(sort(unique(rows$y)), function(yy) {
    r <- rows[y == yy][order(x)]
    # a trip row starts with the trip number in the leftmost column
    if (!grepl("^\\d{1,3}$", r$text[1]) || r$x[1] > 110) return(NULL)
    tm <- r[grepl("^\\d{4}$", text) & x > 205]
    if (!nrow(tm)) return(NULL)
    ci <- vapply(tm$x, nearest, integer(1))
    data.table(page = page_no, trip = as.integer(r$text[1]),
               node = colnodes[ci], time = tm$text)
  }))
}

read_pdf_schedules <- function(paths = PDFS) {
  rbindlist(lapply(names(paths), function(dt) {
    pages <- pdftools::pdf_data(paths[[dt]])
    x <- rbindlist(lapply(seq_along(pages), function(i) {
      pdf_page_times(pages[[i]], i)
    }))
    x[, daytype := dt][]
  }))
}

#' Header facts (service change, implementation date, vehicles) for reporting
pdf_headers <- function(paths = PDFS) {
  rbindlist(lapply(names(paths), function(dt) {
    txt <- pdftools::pdf_text(paths[[dt]])[1]
    grab <- function(re) {
      m <- regmatches(txt, regexpr(re, txt, perl = TRUE))
      if (length(m)) trimws(sub(re, "\\1", m, perl = TRUE)) else NA_character_
    }
    data.table(daytype = dt,
               schedule = grab("Schedule:\\s+(\\S+)"),
               change = grab("Service change:\\s+(\\d+ - [^\\n]*?)\\s{2,}"),
               implementation = grab("Implementation date:\\s+([0-9-]+)"),
               vehicles = grab("No\\. of vehicles used on schedule:\\s+(\\d+)"))
  }))
}

# ---------------------------------------------------------------------------
# GTFS feeds
# ---------------------------------------------------------------------------

read_member <- function(zip, name) {
  con <- unz(zip, name)
  on.exit(try(close(con), silent = TRUE), add = TRUE)
  txt <- tryCatch(readLines(con, warn = FALSE), error = function(e) NULL)
  if (is.null(txt) || !length(txt)) return(NULL)
  fread(text = txt, colClasses = "character", showProgress = FALSE)
}

#' stop_times rows for a set of trips
#'
#' stop_times.txt holds ~90 million rows (5.5 GB) in the DfT national feed, of
#' which a few tens of thousands are wanted. unz() connections cannot be read
#' incrementally with readLines() ("seek not enabled"), but they can be read
#' as raw bytes, so the member is streamed in fixed-size blocks, split into
#' lines, and filtered on the way past. Peak memory stays at one block rather
#' than the whole table, and it needs no external unzip and no temporary file.
read_stop_times_for <- function(zip, trip_ids, block = 64e6) {
  con <- unz(zip, "stop_times.txt", open = "rb")
  on.exit(close(con), add = TRUE)
  want <- as.character(trip_ids)
  keep <- list()
  header <- NULL
  tail_txt <- ""
  repeat {
    raw <- readBin(con, "raw", n = block)
    if (!length(raw)) break
    txt <- paste0(tail_txt, rawToChar(raw))
    Encoding(txt) <- "bytes"
    ln <- strsplit(txt, "\r?\n")[[1]]
    # the last element may be a partial line; hold it over for the next block
    tail_txt <- ln[length(ln)]
    ln <- ln[-length(ln)]
    if (is.null(header) && length(ln)) {
      header <- strsplit(gsub('"', "", ln[1]), ",", fixed = TRUE)[[1]]
      ln <- ln[-1]
    }
    if (!length(ln)) next
    id <- sub("^\"?([^\",]+)\"?,.*$", "\\1", ln)
    keep[[length(keep) + 1L]] <- ln[id %chin% want]
  }
  if (nzchar(tail_txt)) {
    id <- sub("^\"?([^\",]+)\"?,.*$", "\\1", tail_txt)
    if (id %chin% want) keep[[length(keep) + 1L]] <- tail_txt
  }
  d <- fread(text = unlist(keep, use.names = FALSE), header = FALSE,
             colClasses = "character", showProgress = FALSE)
  setnames(d, header[seq_len(ncol(d))])
  d[]
}

#' Dates in the window on which each service operates
service_dates <- function(cal, cal_dates) {
  cal <- copy(cal)
  cal[, `:=`(sd = as.Date(start_date, "%Y%m%d"),
             ed = as.Date(end_date, "%Y%m%d"))]
  dow <- tolower(weekdays(DATES))
  rbindlist(lapply(seq_len(nrow(cal)), function(i) {
    flags <- as.integer(unlist(cal[i, ..DOW_COLS]))
    names(flags) <- DOW_COLS
    d <- DATES[DATES >= cal$sd[i] & DATES <= cal$ed[i] & flags[dow] == 1L]
    if (!is.null(cal_dates) && nrow(cal_dates)) {
      e <- copy(cal_dates[service_id == cal$service_id[i]])
      if (nrow(e)) {
        e[, dt := as.Date(date, "%Y%m%d")]
        d <- as.Date(sort(unique(c(
          setdiff(d, e[exception_type == "2"]$dt),
          intersect(e[exception_type == "1"]$dt, DATES)))),
          origin = "1970-01-01")
      }
    }
    data.table(service_id = cal$service_id[i], date = d)
  }), fill = TRUE)
}

#' Label a calendar row with the running-schedule day type it corresponds to
calendar_daytype <- function(cal) {
  m <- as.matrix(cal[, ..DOW_COLS]) == "1"
  lab <- apply(m, 1, function(r) {
    d <- DOW_COLS[r]
    if (identical(d, "saturday")) return("Sa")
    if (identical(d, "sunday")) return("Su")
    if (identical(d, "friday")) return("Fr")
    if (all(c("monday", "tuesday", "wednesday", "thursday") %in% d) &&
        !"friday" %in% d) return("MT")
    paste(substr(d, 1, 2), collapse = "+")
  })
  data.table(service_id = cal$service_id, daytype = lab)
}

load_feed_279 <- function(spec) {
  trips <- read_member(spec$zip, "trips.txt")
  trips <- trips[route_id %in% spec$routes]
  cal <- read_member(spec$zip, "calendar.txt")[service_id %in% trips$service_id]
  cd <- read_member(spec$zip, "calendar_dates.txt")
  if (!is.null(cd)) cd <- cd[service_id %in% trips$service_id]
  st <- read_stop_times_for(spec$zip, trips$trip_id)
  list(trips = trips, cal = cal, cal_dates = cd, stop_times = st,
       routes = spec$routes)
}

# ---------------------------------------------------------------------------
# Comparison
# ---------------------------------------------------------------------------

# Minutes since midnight; journeys running past midnight are written 24:06 in
# the schedules and sometimes 00:06 in GTFS, so anything before 04:00 is
# shifted onto the previous service day before the two are compared.
mins_hhmm <- function(x) as.integer(substr(x, 1, 2)) * 60L +
  as.integer(substr(x, 3, 4))
mins_gtfs <- function(x) {
  p <- tstrsplit(x, ":", fixed = TRUE)
  as.integer(p[[1]]) * 60L + as.integer(p[[2]])
}
past_midnight <- function(t) fifelse(t < 4 * 60, t + 24 * 60, t)
fmt_min <- function(m) sprintf("%02d:%02d", m %/% 60, m %% 60)

#' Manor House departure time of every 279 journey in a feed
manor_times <- function(feed) {
  dt <- calendar_daytype(feed$cal)
  tr <- merge(feed$trips, dt, by = "service_id", all.x = TRUE)
  label <- setNames(names(feed$routes), feed$routes)
  tr[, label := label[route_id]]
  st <- feed$stop_times[stop_id %in% MANOR & trip_id %in% tr$trip_id]
  st <- st[, .(t = mins_gtfs(departure_time[1])), by = trip_id]
  m <- merge(tr[, .(trip_id, label, daytype)], st, by = "trip_id")
  m[, tn := past_midnight(t)][]
}

#' Multiset comparison of two sets of clock minutes
compare_minutes <- function(a, b) {
  ta <- table(a); tb <- table(b)
  k <- as.character(sort(unique(c(as.integer(names(ta)), as.integer(names(tb))))))
  ca <- as.integer(ta[k]); ca[is.na(ca)] <- 0L
  cb <- as.integer(tb[k]); cb[is.na(cb)] <- 0L
  list(matched = sum(pmin(ca, cb)),
       only_a = length(a) - sum(pmin(ca, cb)),
       only_b = length(b) - sum(pmin(ca, cb)))
}

main <- function() {
  message("Reading the published schedules ...")
  pdf_t <- read_pdf_schedules()
  pdf_manor <- pdf_t[node == "AD803", .(daytype, trip, tn = past_midnight(mins_hhmm(time)))]

  cat("\n== Published schedules ==\n")
  print(pdf_headers())
  pdf_daily <- pdf_t[, .(journeys = uniqueN(trip)), by = daytype]
  print(pdf_daily)
  wk <- pdf_daily[daytype == "MT"]$journeys * 4 + pdf_daily[daytype == "Fr"]$journeys +
    pdf_daily[daytype == "Sa"]$journeys + pdf_daily[daytype == "Su"]$journeys
  cat("journeys per week:", wk, "  per 28-day window:", wk * 4, "\n")
  cat("Mon-Thu direction split (odd trip nos towards Manor House):",
      pdf_manor[daytype == "MT", sum(trip %% 2 == 1)], "/",
      pdf_manor[daytype == "MT", sum(trip %% 2 == 0)], "\n")

  message("Reading the 2026 feeds ...")
  feeds <- lapply(FEEDS, load_feed_279)
  manor <- rbindlist(lapply(feeds, manor_times))

  cat("\n== Result 1: journeys per day type ==\n")
  tab <- dcast(manor[, .N, by = .(label, daytype)], label ~ daytype,
               value.var = "N", fill = 0)
  print(rbind(dcast(pdf_daily[, .(label = "PDF (published)", daytype,
                                  N = journeys)],
                    label ~ daytype, value.var = "N", fill = 0), tab))

  cat("\n== Result 2a: Manor House departures, minute by minute ==\n")
  print(rbindlist(lapply(unique(manor$label), function(f) {
    rbindlist(lapply(c("MT", "Fr", "Sa", "Su"), function(dt) {
      r <- compare_minutes(pdf_manor[daytype == dt]$tn,
                           manor[label == f & daytype == dt]$tn)
      data.table(source = f, daytype = dt,
                 pdf = nrow(pdf_manor[daytype == dt]),
                 feed = nrow(manor[label == f & daytype == dt]),
                 matched = r$matched, in_pdf_only = r$only_a,
                 in_feed_only = r$only_b)
    }))
  })))

  cat("\n== Result 2b: hourly departures at Manor House, Mon-Thu ==\n")
  hp <- rbind(pdf_manor[daytype == "MT", .(src = "PDF", hr = tn %/% 60)],
              manor[daytype == "MT", .(src = label, hr = tn %/% 60)])
  print(dcast(hp[, .N, by = .(src, hr)], hr ~ src, value.var = "N", fill = 0))

  cat("\n== Result 2c: are the stop_times identical? ==\n")
  st_key <- function(feed, route_id_) {
    ids <- feed$trips[route_id == route_id_]$trip_id
    x <- copy(feed$stop_times[trip_id %in% ids])
    x[, ss := as.integer(stop_sequence)]
    x[, ss := ss - min(ss), by = trip_id]      # TNDS numbers from 1, DfT from 0
    sort(paste(x$stop_id, x$arrival_time, x$departure_time, x$ss))
  }
  a <- st_key(feeds$tnds, "2166")
  b <- st_key(feeds$bods_txc, "693")
  d <- st_key(feeds$bods_gtfs, "138482")
  cat("rows:", length(a), length(b), length(d), "\n")
  cat("TNDS == BODS GTFS route 138482 :", identical(a, d), "\n")
  cat("TNDS == BODS TXC               :", identical(a, b),
      " differing rows:", sum(a != b), "\n")
  if (!identical(a, b)) {
    i <- which(a != b)[1]
    cat("  first difference: '", a[i], "' vs '", b[i], "'\n", sep = "")
  }

  cat("\n== Result 3: journeys per date across the window ==\n")
  daily <- rbindlist(lapply(names(feeds), function(nm) {
    f <- feeds[[nm]]
    label <- setNames(names(f$routes), f$routes)
    sd <- service_dates(f$cal, f$cal_dates)
    m <- merge(f$trips[, .(trip_id, service_id, route_id)], sd,
               by = "service_id", allow.cartesian = TRUE)
    m[, .(N = .N), by = .(label = label[route_id], date)]
  }))
  pdf_by_dow <- setNames(pdf_daily$journeys, pdf_daily$daytype)
  ref <- data.table(date = DATES)
  ref[, dw := weekdays(date)]
  ref[, N := fifelse(dw == "Friday", pdf_by_dow[["Fr"]],
              fifelse(dw == "Saturday", pdf_by_dow[["Sa"]],
              fifelse(dw == "Sunday", pdf_by_dow[["Su"]], pdf_by_dow[["MT"]])))]
  w <- dcast(rbind(daily, ref[, .(label = "PDF (published)", date, N)]),
             date ~ label, value.var = "N", fill = 0)
  w[, dw := substr(weekdays(date), 1, 3)]
  print(w)
  cat("\nwindow totals:\n")
  print(w[, lapply(.SD, sum), .SDcols = is.numeric])

  cat("\n== Why BODS GTFS disagrees: source TransXChange versions ==\n")
  g <- copy(feeds$bods_gtfs$trips)
  g[, version := sub("^VJ_8-279-_-y05-([0-9]+)-.*$", "\\1", vehicle_journey_code)]
  print(dcast(g[, .N, by = .(route_id, version)], version ~ route_id,
              value.var = "N", fill = 0))
  a1 <- g[route_id == "10003" & version == "62015"]$vehicle_journey_code
  b1 <- g[route_id == "138482"]$vehicle_journey_code
  cat("journey codes shared between the two BODS GTFS routes:",
      length(intersect(a1, b1)), "of", length(b1),
      " -- overlapping trip_ids:",
      length(intersect(g[route_id == "10003"]$trip_id,
                       g[route_id == "138482"]$trip_id)), "\n")

  cat("\n== Cause 3: the feed carries no history ==\n")
  for (nm in names(FEEDS)) {
    cal <- read_member(FEEDS[[nm]]$zip, "calendar.txt")
    cat(sprintf("%-10s calendars: %5d   active on %s: %5d   earliest start: %s\n",
                nm, nrow(cal), WIN_START,
                sum(as.integer(cal$start_date) <= as.integer(format(WIN_START, "%Y%m%d")) &
                    as.integer(cal$end_date) >= as.integer(format(WIN_START, "%Y%m%d"))),
                min(cal$start_date)))
  }

  cat("\n== Consequence: the 2026 shared-service ratio distribution ==\n")
  # A service losing the Monday and Tuesday of the window gives a TNDS / BODS
  # GTFS ratio fixed by its operating pattern alone.
  sig <- c(`Mon-Fri 20/18` = 20 / 18, `Mon-Sat 24/22` = 24 / 22,
           `every day 28/26` = 28 / 26)
  for (y in c(2024, 2025, 2026)) {
    p <- sprintf("%s/bus_source_comparison_%s.Rds", cfg$out_dir, y)
    if (!file.exists(p)) next
    s <- as.data.table(readRDS(p)$services)[tnds > 0 & bods_gtfs > 0]
    s[, ratio := tnds / bods_gtfs]
    cat(sprintf("%d: n = %5d  median ratio = %.4f  on a signature ratio = %4.1f%%  in (1.07,1.12] = %4.1f%%\n",
                y, nrow(s), median(s$ratio),
                100 * mean(vapply(s$ratio, function(r) any(abs(r - sig) < 0.002),
                                  logical(1))),
                100 * mean(s$ratio > 1.07 & s$ratio <= 1.12)))
  }
  invisible(NULL)
}

if (sys.nframe() == 0L) main()
