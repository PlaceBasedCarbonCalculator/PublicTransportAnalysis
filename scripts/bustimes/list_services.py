"""List every current bustimes.org service, and the London and West Midlands bus ones.

    python -I scripts/bustimes/list_services.py data/bustimes/20261119
    python -I scripts/bustimes/list_services.py data/bustimes/20261120 --modes bus,coach

Writes services_all.json (the whole API listing, as fetched) and services.csv
(the services fetch_timetables.py reads first):

  bus    services whose region is L or WM. Services registered in another
         region but calling in either city are added later from stop pages
         (fetch_timetables.py --from-stops).
  coach  every coach service, whatever its region: bustimes files almost all
         of them under "GB", so the region says nothing about where they
         call. The study-area filter is applied to the counted stops instead.

--modes defaults to bus, which is what the 19 November scrape used.
"""
import csv
import json
import os
import sys
import time
import urllib.request

UA = "Mozilla/5.0 (compatible; timetable-research)"
API = "https://bustimes.org/api/services/?format=json&limit=1000&offset={}"


def get_json(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)


def main(out_dir, modes=("bus",)):
    os.makedirs(out_dir, exist_ok=True)
    rows, offset = [], 0
    while True:
        d = get_json(API.format(offset))
        rows.extend(d["results"])
        print(f"offset {offset}: {len(rows)} of {d['count']}", flush=True)
        if not d.get("next"):
            break
        offset += 1000
        time.sleep(1)
    with open(os.path.join(out_dir, "services_all.json"), "w", encoding="utf-8") as f:
        json.dump(rows, f)
    keep = [r for r in rows
            if (r["mode"] == "bus" and "bus" in modes and r["region_id"] in ("L", "WM"))
            or (r["mode"] == "coach" and "coach" in modes)]
    with open(os.path.join(out_dir, "services.csv"), "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["id", "slug", "line_name", "operator", "region", "description",
                    "source", "mode"])
        for r in keep:
            w.writerow([r["id"], r["slug"], r["line_name"], ";".join(r["operator"] or []),
                        r["region_id"], r["description"], "region", r["mode"]])
    print(f"{len(rows)} services; kept {len(keep)} ({', '.join(modes)})")


if __name__ == "__main__":
    modes = ("bus",)
    if "--modes" in sys.argv:
        modes = tuple(sys.argv[sys.argv.index("--modes") + 1].split(","))
    main(sys.argv[1], modes)
