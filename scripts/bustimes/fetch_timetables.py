"""Fetch bustimes.org timetable pages for one date, politely, with a resumable cache.

    python -I scripts/bustimes/fetch_timetables.py data/bustimes/20261119 2026-11-19
    python -I scripts/bustimes/fetch_timetables.py data/bustimes/20261119 2026-11-19 \
        --from-stops stops_to_check.txt

The first form fetches /services/<slug>?date=<date> for every row of
services.csv into html/<id>.html, skipping pages already cached. A page is
only cached when it says it is for the requested date (bustimes writes the
date into a <noscript> element), so a page served for another date - a
service with no timetable on the day falls back to its first date - is
recorded in fetch_log.csv and not cached as if it were the day's.

The second form reads ATCO codes, one per line, fetches /stops/<code> into
stops/<code>.html, adds every service linked from those pages that is not yet
in services.csv (source "stop:<code>"), and then fetches the new services'
timetables. That is how services registered in another region but calling in
London or the West Midlands get in.

--modes bus,coach (anywhere after the date) sets which modes the stop pass
adds; the default is bus.

bustimes.org only offers dates from today on, so this must run on or before
the date it fetches.
"""
import csv
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request

UA = "Mozilla/5.0 (compatible; timetable-research)"
BASE = "https://bustimes.org"
PAUSE = 1.0


def get(url, tries=4):
    for k in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=90) as r:
                return r.status, r.read().decode("utf-8", errors="replace")
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return 404, ""
            if e.code == 429 or e.code >= 500:
                time.sleep(30 * (k + 1))
                continue
            return e.code, ""
        except Exception as e:  # network hiccup
            print(f"  retry {url}: {e}", flush=True)
            time.sleep(15 * (k + 1))
    return -1, ""


def read_services(out_dir):
    with open(os.path.join(out_dir, "services.csv"), encoding="utf-8") as f:
        return list(csv.DictReader(f))


def log_row(out_dir, row):
    path = os.path.join(out_dir, "fetch_log.csv")
    new = not os.path.exists(path)
    with open(path, "a", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        if new:
            w.writerow(["id", "slug", "status", "page_date", "fetched_at"])
        w.writerow(row)


def fetch_services(out_dir, date, services):
    html_dir = os.path.join(out_dir, "html")
    os.makedirs(html_dir, exist_ok=True)
    todo = [s for s in services
            if not os.path.exists(os.path.join(html_dir, f"{s['id']}.html"))]
    print(f"{len(services)} services, {len(todo)} to fetch", flush=True)
    for i, s in enumerate(todo, 1):
        status, html = get(f"{BASE}/services/{s['slug']}?date={date}")
        m = re.search(r"<noscript>(\d{4}-\d{2}-\d{2})</noscript>", html)
        page_date = m.group(1) if m else ""
        stamp = time.strftime("%Y-%m-%dT%H:%M:%S")
        if status == 200 and (page_date == date or not page_date):
            # No date element means a page with no date selector: a service
            # whose only timetable is a single date range. Keep it; the parser
            # records the missing date.
            with open(os.path.join(html_dir, f"{s['id']}.html"), "w",
                      encoding="utf-8") as f:
                f.write(html)
        log_row(out_dir, [s["id"], s["slug"], status, page_date, stamp])
        if i % 50 == 0:
            print(f"  {i}/{len(todo)}", flush=True)
        time.sleep(PAUSE)


def services_from_stops(out_dir, codes, modes=("bus",)):
    stop_dir = os.path.join(out_dir, "stops")
    os.makedirs(stop_dir, exist_ok=True)
    with open(os.path.join(out_dir, "services_all.json"), encoding="utf-8") as f:
        by_slug = {r["slug"]: r for r in json.load(f)}
    services = read_services(out_dir)
    have = {s["slug"] for s in services}
    added = []
    for code in codes:
        path = os.path.join(stop_dir, f"{code}.html")
        if os.path.exists(path):
            with open(path, encoding="utf-8") as f:
                html = f.read()
        else:
            status, html = get(f"{BASE}/stops/{code}")
            with open(path, "w", encoding="utf-8") as f:
                f.write(html)
            time.sleep(PAUSE)
        for slug in sorted(set(re.findall(r'href="/services/([^"/?#]+)"', html))):
            if slug in have:
                continue
            r = by_slug.get(slug)
            if r is None or r["mode"] not in modes:
                continue
            have.add(slug)
            added.append({"id": r["id"], "slug": slug, "line_name": r["line_name"],
                          "operator": ";".join(r["operator"] or []),
                          "region": r["region_id"], "description": r["description"],
                          "source": f"stop:{code}", "mode": r["mode"]})
    if added:
        with open(os.path.join(out_dir, "services.csv"), encoding="utf-8") as f:
            header = next(csv.reader(f))
        with open(os.path.join(out_dir, "services.csv"), "a", newline="",
                  encoding="utf-8") as f:
            # Write in the file's own column order; an older services.csv
            # without the mode column just doesn't get it.
            w = csv.DictWriter(f, fieldnames=header, extrasaction="ignore")
            w.writerows(added)
    print(f"{len(codes)} stops checked, {len(added)} services added", flush=True)
    return added


def main(argv):
    out_dir, date = argv[1], argv[2]
    modes = ("bus",)
    if "--modes" in argv:
        modes = tuple(argv[argv.index("--modes") + 1].split(","))
    if "--from-stops" in argv:
        with open(argv[argv.index("--from-stops") + 1], encoding="utf-8") as f:
            codes = [ln.strip() for ln in f if ln.strip()]
        added = services_from_stops(out_dir, codes, modes)
        fetch_services(out_dir, date, added)
    else:
        fetch_services(out_dir, date, read_services(out_dir))


if __name__ == "__main__":
    main(sys.argv)
