"""Extract worked-example routes from a merged GTFS for the filter rules report.

    python -I extract_examples.py <merged zip> <YYYYMMDD> <out dir> <spec csv>

<spec csv> has columns example, route_short_name, route_type and an optional
agency_ids (space separated) or service_code (substring of route_desc). Writes
<out dir>/routes.csv, stops.csv and stop_times.csv: every trip of the matched
routes running on the day, with its calls.
"""
import csv, io, sys, zipfile, datetime

zp, day, out, spec = sys.argv[1:5]
z = zipfile.ZipFile(zp)
dt = datetime.datetime.strptime(day, "%Y%m%d").date()
wd = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"][dt.weekday()]


def rows(n):
    with z.open(n) as f:
        yield from csv.DictReader(io.TextIOWrapper(f, encoding="utf-8-sig"))


d8 = lambda s: s.replace("-", "")
specs = list(csv.DictReader(open(spec, encoding="utf-8")))
ag = {a["agency_id"]: a["agency_name"] for a in rows("agency.txt")}
routes = {}
for r in rows("routes.txt"):
    for s in specs:
        if r["route_short_name"] != s["route_short_name"] or r["route_type"] != s["route_type"]:
            continue
        if s.get("agency_ids") and r["agency_id"] not in s["agency_ids"].split():
            continue
        if s.get("service_code") and s["service_code"] not in (r.get("route_desc") or ""):
            continue
        routes[r["route_id"]] = dict(r, example=s["example"], agency_name=ag.get(r["agency_id"], ""))
runs = set()
for c in rows("calendar.txt"):
    if d8(c["start_date"]) <= day <= d8(c["end_date"]) and c[wd] in ("1", "TRUE", "True"):
        runs.add(c["service_id"])
for c in rows("calendar_dates.txt"):
    if d8(c["date"]) == day:
        (runs.add if c["exception_type"] == "1" else runs.discard)(c["service_id"])
trips = {t["trip_id"]: t["route_id"] for t in rows("trips.txt")
         if t["route_id"] in routes and t["service_id"] in runs}
calls, used = [], set()
for s in rows("stop_times.txt"):
    if s["trip_id"] in trips:
        calls.append([trips[s["trip_id"]], s["trip_id"], s["stop_sequence"], s["stop_id"],
                      s["arrival_time"], s["departure_time"]])
        used.add(s["stop_id"])
stops = [[s["stop_id"], s["stop_name"], s["stop_lat"], s["stop_lon"]]
         for s in rows("stops.txt") if s["stop_id"] in used]
with open(f"{out}/routes.csv", "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow(["example", "route_id", "agency_id", "agency_name", "route_short_name",
                "route_type", "route_long_name", "route_desc"])
    for rid, r in routes.items():
        w.writerow([r["example"], rid, r["agency_id"], r["agency_name"], r["route_short_name"],
                    r["route_type"], r.get("route_long_name", ""), r.get("route_desc", "")])
with open(f"{out}/stop_times.csv", "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow(["route_id", "trip_id", "stop_sequence", "stop_id", "arrival_time", "departure_time"])
    w.writerows(calls)
with open(f"{out}/stops.csv", "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow(["stop_id", "stop_name", "stop_lat", "stop_lon"])
    w.writerows(stops)
print(len(routes), "routes,", len(trips), "trips,", len(calls), "calls,", len(stops), "stops")
