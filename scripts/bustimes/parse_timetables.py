"""Departures per stop and service from cached bustimes.org timetable pages.

    python -I scripts/bustimes/parse_timetables.py data/bustimes/20261119 2026-11-19

Reads html/<id>.html (fetch_timetables.py) and writes:

  stop_service_counts.csv  service_id, line_name, operator, region, grouping
                           (direction table), stop (ATCO code, as linked),
                           row (position in the table), departures
  pages.csv                one row per page: date it is for, tables, rows,
                           cells, and any layout the count could not handle

A departure is a cell holding a time (HH:MM) in a stop's row. Every stop of
the service is in the HTML - the "All stops" switch only shows rows hidden by
CSS - so non-timing points are counted too, as UK2GTFS counts its
interpolated ones. A stop that appears twice in a table (a loop) is two rows
and counts twice, as gtfs_stop_frequency() counts a trip calling twice.

A journey run wholly after midnight - a night bus whose first call is
already marked "+1" - is not counted. bustimes.org's page for a date shows
both the previous night's journeys (00:23, unmarked) and that night's (00:23+1,
TransXChange DepartureDayShift); a GTFS service day holds one set, so counting
both doubles every night route. A "+1" call on a journey that starts before
midnight is counted, as GTFS counts its 24:xx times on the service day.

Where a stop has separate arrival and departure rows its <th> spans both;
only the first row is counted, so the stop counts once per journey either
way. Cells that are not times are tallied in pages.csv by their text, so a
"then every N minutes" column, if bustimes ever draws one, is visible rather
than silently missing departures.
"""
import csv
import html as htmllib
import os
import re
import sys
from collections import Counter
from html.parser import HTMLParser

# A trailing letter is a note on the call - "17:13s" is set down only - and
# the call is still a stop_time in GTFS, so it counts. A superscript "+1"
# ("00:15⁺¹") is a call after midnight by a journey of the day's service: GTFS
# writes it as 24:15 on the same trip and counts it on the day, so it counts.
TIME = re.compile(r"^\d{1,2}:\d{2}(⁺[¹²³⁰-⁹]+)? ?[a-z]?$")


class Page(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.groupings = []      # list of [title, rows]
        self.in_h2 = False
        self.h2 = ""
        self.in_table = 0
        self.row = None          # dict for the current <tr>
        self.cell = None         # text of the current <td>/<th>
        self.cell_attrs = {}
        self.cell_tag = None
        self.skip_rows = 0       # rows covered by a <th rowspan>
        self.other_cells = Counter()
        self.noscript = False
        self.date = ""
        self.table_rows = []
        self.shifted_cols = 0    # journeys run wholly after midnight
        self.shifted_cells = 0

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag == "noscript":
            self.noscript = True
        elif tag == "h2":
            self.in_h2, self.h2 = True, ""
        elif tag == "table" and "timetable" in (a.get("class") or ""):
            self.in_table += 1
            self.groupings.append([self.h2.strip(), []])
            self.table_rows = []     # (stop or None, covered, cells)
        elif self.in_table and tag == "tr":
            self.row = {"stop": None, "cells": [], "covered": self.skip_rows > 0,
                        "rowspan": 1}
            if self.skip_rows > 0:
                self.skip_rows -= 1
        elif self.in_table and self.row is not None and tag in ("td", "th"):
            self.cell, self.cell_tag, self.cell_attrs = "", tag, a
            if tag == "th" and a.get("rowspan"):
                try:
                    self.row["rowspan"] = int(a["rowspan"])
                except ValueError:
                    pass
        elif self.in_table and self.row is not None and tag == "a" and self.cell is not None:
            m = re.match(r"^/stops/([^/?#]+)", a.get("href") or "")
            if m and self.cell_tag == "th":
                self.row["stop"] = m.group(1)

    def handle_endtag(self, tag):
        if tag == "noscript":
            self.noscript = False
        elif tag == "h2":
            self.in_h2 = False
        elif tag == "table" and self.in_table:
            self.in_table -= 1
            self.close_table()
        elif self.in_table and tag in ("td", "th") and self.cell is not None:
            txt = " ".join(self.cell.split())
            if tag == "td" and self.row is not None:
                m = TIME.match(txt)
                # 0 = no time, 1 = time, 2 = time after midnight ("+1")
                self.row["cells"].append(0 if not m else (2 if m.group(1) else 1))
                if not m and txt:
                    self.other_cells[re.sub(r"\d+", "#", txt)[:40]] += 1
            self.cell = None
        elif self.in_table and tag == "tr" and self.row is not None:
            r = self.row
            if r["rowspan"] > 1:
                self.skip_rows = r["rowspan"] - 1
            self.table_rows.append((r["stop"], r["covered"], r["cells"]))
            self.row = None

    def close_table(self):
        """Count each stop row, leaving out journeys run wholly after midnight."""
        rows = getattr(self, "table_rows", [])
        ncol = max((len(c) for _, _, c in rows), default=0)
        shifted = set()
        for j in range(ncol):
            first = next((c[j] for _, _, c in rows if j < len(c) and c[j]), 0)
            if first == 2:
                shifted.add(j)
        self.shifted_cols += len(shifted)
        for stop, covered, cells in rows:
            n = sum(1 for j, v in enumerate(cells) if v and j not in shifted)
            self.shifted_cells += sum(1 for j, v in enumerate(cells) if v and j in shifted)
            if stop and not covered and self.groupings:
                self.groupings[-1][1].append((stop, n))
        self.table_rows = []

    def handle_data(self, data):
        if self.noscript and re.match(r"^\d{4}-\d{2}-\d{2}$", data.strip()):
            self.date = data.strip()
        if self.in_h2:
            self.h2 += data
        if self.cell is not None:
            self.cell += data


def main(out_dir, date):
    with open(os.path.join(out_dir, "services.csv"), encoding="utf-8") as f:
        services = {s["id"]: s for s in csv.DictReader(f)}
    html_dir = os.path.join(out_dir, "html")
    counts, pages = [], []
    for fn in sorted(os.listdir(html_dir)):
        sid = fn[:-5]
        s = services.get(sid, {})
        with open(os.path.join(html_dir, fn), encoding="utf-8") as f:
            text = f.read()
        p = Page()
        p.feed(text)
        n_rows = n_cells = 0
        for g, (title, rows) in enumerate(p.groupings, 1):
            for k, (stop, n) in enumerate(rows, 1):
                n_rows += 1
                n_cells += n
                counts.append([sid, s.get("line_name", ""), s.get("operator", ""),
                               s.get("region", ""), g, title, k, stop.upper(), n])
        no_tt = "Sorry, no journeys found" in text or "no journeys" in text.lower()
        pages.append([sid, s.get("slug", ""), p.date, p.date == date,
                      len(p.groupings), n_rows, n_cells, no_tt,
                      p.shifted_cols, p.shifted_cells,
                      "; ".join(f"{k}={v}" for k, v in p.other_cells.most_common(5))])
    with open(os.path.join(out_dir, "stop_service_counts.csv"), "w", newline="",
              encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["service_id", "line_name", "operator", "region", "grouping",
                    "grouping_title", "row", "stop", "departures"])
        w.writerows(counts)
    with open(os.path.join(out_dir, "pages.csv"), "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["service_id", "slug", "page_date", "is_date", "tables", "rows",
                    "cells", "no_journeys_text", "shifted_journeys",
                    "shifted_cells", "other_cells"])
        w.writerows(pages)
    print(f"{len(pages)} pages, {len(counts)} stop rows, "
          f"{sum(r[-1] for r in counts)} departures; "
          f"{sum(1 for p in pages if not p[3])} pages not dated {date}; "
          f"{sum(p[8] for p in pages)} journeys run wholly after midnight left out "
          f"({sum(p[9] for p in pages)} calls)")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
