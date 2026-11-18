# Raw TransXChange journeys against converted GTFS trips, nationally.
#
# Joins faithful.py's per-file counts (what the filtered files publish on each
# window date) to the compact converted timetable the stop_gap pipeline saves
# (data/stop_gap/stopfreq_*.Rds, $tt), on operator (NOC = agency_id), line
# (route_short_name, case-folded) and date. Every operator-line-date is put in
# one class:
#   equal      converted == raw
#   near       within 5% or 2 trips
#   under      converted < raw        - the converter lost journeys
#   over       converted > raw        - it ran journeys the files do not
#   raw only   the line is in the files but not the feed
#   feed only  the line is in the feed but not the files
# and the summary gives journeys in each class, the lines behind the
# largest losses and gains, and the result per region. The raw reading
# (txcday.py) is independent of UK2GTFS, so a disagreement is a converter
# fault unless txcday is wrong - the lines listed are what to check by hand.
#
# usage: Rscript faithful_compare.R <faithful.csv> <stopfreq rds> <out prefix>
suppressMessages(library(data.table))
a <- commandArgs(TRUE)
raw <- fread(a[1], encoding = "UTF-8")
raw <- raw[noc != "ERROR"]
raw[, date := as.IDate(date)]
# a file naming several operators is credited to each (rare; depot files)
raw <- raw[, .(noc = unlist(strsplit(noc, ";", fixed = TRUE))),
           by = .(region, file, line, date, n)]
rawl <- raw[, .(raw = sum(n), files = uniqueN(file)),
            by = .(region, noc, line = toupper(trimws(line)), date)]

tt <- readRDS(a[2])$tt
mult <- if (!is.null(tt$freq) && nrow(tt$freq)) {
  tt$freq[, list(mult = sum(pmax(ceiling((end - start) / headway), 1))), by = trip]
} else data.table(trip = integer(0), mult = numeric(0))
tr <- merge(tt$trips, tt$routes[, .(route_id, agency_id, route_short_name)], by = "route_id")
tr <- merge(tr, mult, by = "trip", all.x = TRUE)[is.na(mult), mult := 1]
dates <- sort(unique(rawl$date))
sd <- merge(tr, tt$sdates[date %in% dates], by = "service_id", allow.cartesian = TRUE)
feed <- sd[, .(feed = sum(mult)),
           by = .(noc = agency_id, line = toupper(trimws(route_short_name)), date = as.IDate(date))]

m <- merge(rawl, feed, by = c("noc", "line", "date"), all = TRUE)
m[is.na(raw), raw := 0][is.na(feed), feed := 0]
m[, class := fifelse(raw == feed, "equal",
             fifelse(raw == 0, "feed only",
             fifelse(feed == 0, "raw only",
             fifelse(abs(raw - feed) <= pmax(2, 0.05 * raw), "near",
             fifelse(feed < raw, "under", "over")))))]
fwrite(m[order(noc, line, date)], paste0(a[3], "_lines.csv"))

cat("\n== operator-line-dates by class\n")
s <- m[, .(cells = .N, raw = sum(raw), feed = sum(feed)), by = class][order(-raw)]
s[, share_raw := round(100 * raw / sum(raw), 2)]
print(s)
cat("\nraw journeys", sum(m$raw), " converted trips", sum(m$feed),
    " ratio", round(sum(m$feed) / sum(m$raw), 4), "\n")

cat("\n== by region (raw-side files only)\n")
print(m[!is.na(region), .(raw = sum(raw), feed = sum(feed),
                           ratio = round(sum(feed) / sum(raw), 4),
                           under = sum(raw[class == "under"] - feed[class == "under"]),
                           raw_only = sum(raw[class == "raw only"])), by = region][order(ratio)])

byline <- m[, .(raw = sum(raw), feed = sum(feed), days = .N,
                classes = paste(sort(unique(class)), collapse = "/")),
            by = .(region, noc, line)][, diff := feed - raw]
cat("\n== largest losses (converted < raw), over the window\n")
print(head(byline[diff < 0][order(diff)], 30))
cat("\n== largest gains (converted > raw), over the window\n")
print(head(byline[diff > 0][order(-diff)], 30))
cat("\n== lines in the feed but not the filtered files (largest)\n")
print(head(byline[raw == 0][order(-feed)], 15))
fwrite(byline[order(diff)], paste0(a[3], "_bylines.csv"))
