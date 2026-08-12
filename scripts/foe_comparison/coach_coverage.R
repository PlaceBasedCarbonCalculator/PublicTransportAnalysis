# Which years actually contain coach services, and where would they come from?
#
# Coach is GTFS extended route type 200. It reaches the pipeline three ways:
#   - NPTDR: ATCO-CIF records with a COACH vehicle type (2004-2011)
#   - TNDS:  the NCSD national coach archive inside the snapshot (2018-)
#   - BODS:  the national GTFS feed, and a separate Coach dataset
#
# The NCSD archive disappears from the TNDS snapshots after February 2025, so
# the later years may have no coach at all. This reports what each converted
# feed contains, so the gap can be seen rather than assumed.
#
#   Rscript scripts/foe_comparison/coach_coverage.R

suppressPackageStartupMessages(library(data.table))

feed_routes <- function(path) {
  if (!file.exists(path)) return(NULL)
  fls <- utils::unzip(path, list = TRUE)$Name
  want <- fls[basename(fls) %in% c("routes.txt", "trips.txt")]
  tmp <- tempfile(); dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  utils::unzip(path, files = want, exdir = tmp, junkpaths = TRUE)
  routes <- fread(file.path(tmp, "routes.txt"), showProgress = FALSE,
                  colClasses = list(character = "route_id"))
  trips <- fread(file.path(tmp, "trips.txt"), showProgress = FALSE,
                 select = c("trip_id", "route_id"), colClasses = "character")
  routes[, route_type := as.integer(route_type)]
  n_trips <- trips[, .N, by = route_id]
  routes <- merge(routes, n_trips, by = "route_id", all.x = TRUE)
  routes[is.na(N), N := 0L]
  routes[, .(routes = .N, trips = sum(N)), by = route_type][order(route_type)]
}

FEEDS <- list.files("gtfs", pattern = "^(nptdr|busarchive|tnds)_.*\\.zip$",
                    full.names = TRUE)

out <- lapply(FEEDS, function(f) {
  r <- feed_routes(f)
  if (is.null(r)) return(NULL)
  coach <- r[route_type == 200]
  bus <- r[route_type == 3]
  data.frame(feed = basename(f),
             bus_routes = if (nrow(bus)) bus$routes else 0L,
             bus_trips = if (nrow(bus)) bus$trips else 0L,
             coach_routes = if (nrow(coach)) coach$routes else 0L,
             coach_trips = if (nrow(coach)) coach$trips else 0L,
             route_types = paste(r$route_type, collapse = ","))
})

result <- do.call(rbind, out)
result$coach_share_trips <- with(result, coach_trips / (bus_trips + coach_trips))
print(result, row.names = FALSE)
saveRDS(result, "data/coach_coverage.Rds")
message("Wrote data/coach_coverage.Rds")
