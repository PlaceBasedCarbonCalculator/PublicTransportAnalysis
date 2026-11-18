# bustimes.org departures for one day

The referee for [reports/stop_disagreement_cities.md](../../reports/stop_disagreement_cities.md):
bustimes.org's timetable for Thursday 19 November 2026, counted per stop, for
every bus service calling in Greater London (ATCO 490) or the West Midlands
county (ATCO 430).

bustimes.org only offers dates from today onwards, so this cannot be re-run
for 19 November after that day. The output in `data/bustimes/20261119/` is a
fixed input to the pipeline (target `bustimes_counts_1119`), like the PDF
readings.

## Steps

```sh
python -I scripts/bustimes/list_services.py   data/bustimes/20261119
python -I scripts/bustimes/fetch_timetables.py data/bustimes/20261119 2026-11-19
python -I scripts/bustimes/parse_timetables.py data/bustimes/20261119 2026-11-19
# completion pass: stops where a feed has buses and bustimes has none
#   (R: bustimes_missing_stops(<stop_city Rds>, "data/bustimes/20261119/missing_stops.txt"))
python -I scripts/bustimes/fetch_timetables.py data/bustimes/20261119 2026-11-19 \
    --from-stops data/bustimes/20261119/missing_stops.txt
python -I scripts/bustimes/parse_timetables.py data/bustimes/20261119 2026-11-19
```

1. **`list_services.py`** pages `https://bustimes.org/api/services/` (about
   15,700 services) and keeps the bus services whose region is `L` or `WM`
   (`services.csv`, source `region`). The API listing is saved as
   `services_all.json`.
2. **`fetch_timetables.py`** gets `/services/<slug>?date=2026-11-19`. It waits
   one second between requests, uses a generic User-Agent and backs off on
   429 and 5xx. Raw pages go to `html/<id>.html`. A page is kept only if its
   `<noscript>` date is the requested one, or if it has no date selector at
   all. Every request is logged in `fetch_log.csv`.
3. **`parse_timetables.py`** counts the time cells in each stop row of each
   timetable grid (`stop_service_counts.csv`), with one row per page in
   `pages.csv`:
   - Every stop is in the HTML. The "Timing points / All stops" switch only
     hides `tr.minor` rows with CSS, so non-timing points are counted, as
     UK2GTFS counts its interpolated times.
   - A time with a letter suffix (`17:13s`, set down only) counts as a call.
   - A stop listed twice in one grid (a loop) counts twice.
   - A call after midnight (`00:15⁺¹`) counts if its journey started before
     midnight. A journey whose first call is already `⁺¹` is left out
     (`pages.csv`: `shifted_journeys`, `shifted_cells`). The page for a date
     shows the previous night's night buses (unmarked) and that night's
     (`⁺¹`, TransXChange `DepartureDayShift`). A GTFS service day holds one
     set, so counting both doubled every London N route. 3,621 journeys
     (182,145 calls) were left out for 19 Nov.
   - Cells that are not times are tallied in `pages.csv` (`other_cells`), so a
     layout the counter does not understand is visible rather than silently
     dropped. None of the pages checked had a "then every N minutes" column.
4. **Completion pass.** A service registered in another bustimes region but
   calling in either city is missing from the region listing. Its stops show
   up as stops with feed departures and no bustimes departures. Their stop
   pages (`stops/<atco>.html`) are fetched, and every bus service they link to
   that is not yet listed is added (source `stop:<atco>`) and fetched.

## Limitations

- bustimes.org is updated continuously, so the pages reflect its data at
  fetch time (`fetch_log.csv`, 18 November 2026), which is a few hours after
  the 18 November feed downloads.
- Pages with no grid on the day (`tables == 0`) are services that do not run
  on 19 November. A handful of pages (Wrexham-Whitchurch) have no date
  selector and no grid; they are outside both study areas.
