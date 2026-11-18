"""List every current bustimes.org service, and the London and West Midlands bus ones.

    python -I scripts/bustimes/list_services.py data/bustimes/20261119

Writes services_all.json (the whole API listing, as fetched) and services.csv
(bus services whose region is L or WM: the ones fetch_timetables.py reads
first). Services registered in another region but calling in either city are
added later from stop pages (fetch_timetables.py --from-stops).
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


def main(out_dir):
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
    keep = [r for r in rows if r["region_id"] in ("L", "WM") and r["mode"] == "bus"]
    with open(os.path.join(out_dir, "services.csv"), "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["id", "slug", "line_name", "operator", "region", "description",
                    "source"])
        for r in keep:
            w.writerow([r["id"], r["slug"], r["line_name"], ";".join(r["operator"] or []),
                        r["region_id"], r["description"], "region"])
    print(f"{len(rows)} services, {len(keep)} bus services in L or WM")


if __name__ == "__main__":
    main(sys.argv[1])
