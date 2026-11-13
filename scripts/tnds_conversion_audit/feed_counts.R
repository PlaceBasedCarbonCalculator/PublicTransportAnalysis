# Converted TNDS trips per operator, route and audit date, from the compact
# timetable saved by the stop_gap pipeline (data/stop_gap/stopfreq_tnds.Rds).
# The counterpart of raw_counts.py: the same journeys counted after
# conversion, so that the two can be set side by side.
#
# usage: Rscript feed_counts.R NOC:route,route NOC:route ...
suppressMessages(library(data.table))
args <- commandArgs(trailingOnly = TRUE)
tt <- readRDS("data/stop_gap/stopfreq_tnds.Rds")$tt
dates <- as.Date(c("2026-07-28", "2026-08-01", "2026-08-02", "2026-08-04",
                   "2026-08-08", "2026-08-09"))
if (nzchar(Sys.getenv("AUDIT_ALL_DATES"))) {   # every date of the window
  dates <- seq(as.Date("2026-07-27"), as.Date("2026-08-09"), by = 1)
}
mult <- if (!is.null(tt$freq) && nrow(tt$freq)) {
  tt$freq[, list(mult = sum(pmax(ceiling((end - start) / headway), 1))), by = trip]
} else data.table(trip = integer(0), mult = numeric(0))
for (a in args) {
  noc <- sub(":.*", "", a); rts <- strsplit(sub(".*:", "", a), ",")[[1]]
  r <- tt$routes[agency_id == noc & route_short_name %in% rts]
  tr <- tt$trips[route_id %in% r$route_id]
  tr <- merge(tr, r[, .(route_id, route_short_name)], by = "route_id")
  tr <- merge(tr, mult, by = "trip", all.x = TRUE)[is.na(mult), mult := 1]
  sd <- merge(tr, tt$sdates[date %in% dates], by = "service_id", allow.cartesian = TRUE)
  w <- dcast(sd[, .(n = sum(mult)), by = .(route_short_name, date)],
             route_short_name ~ date, value.var = "n", fill = 0)
  cat("==", noc, "\n"); print(w)
}
