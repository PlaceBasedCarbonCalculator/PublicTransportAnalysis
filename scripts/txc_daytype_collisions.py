"""How much does keying rule 1 on the day type change, per archive?

Before the fix, rule 1 of txc_filter_files() deduplicated on operator +
ServiceCode + StartDate + line. Where a publisher files one document per day
type, those documents collide on that key and all but one is deleted. Adding
the day type to the key stops that - but only for publishers who actually file
that way, and whether a given archive contains any is a question about the
archive, not about the code.

This counts the collisions directly: groups of files sharing a ServiceCode, a
start date and a line, where the files differ in their operating day set. Each
such group loses all but one file to the old key and keeps all of them under
the new one, so the file and journey counts here are what the fix recovers,
before rules 2 to 4 have their say.

It reads the raw archives, so it costs one pass over the XML and no
conversion, and it can be run before deciding whether a reconversion is worth
the hours.

Usage: python scripts/txc_daytype_collisions.py tnds|bods [out_csv]
"""

import collections
import csv
import glob
import io
import os
import sys
import zipfile
import xml.etree.ElementTree as ET

DATA = "D:/OneDrive - University of Leeds/Data/UK2GTFS"
TNDS_GLOB = DATA + "/TransXChange/data_20261002/TNDSV2.5/*.zip"
BODS_ZIP = (DATA + "/OpenBusData/TransXchange/20261003/"
            "bodds_archive_20261003.zip")

WEEK = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
ALL7 = WEEK + ["Saturday", "Sunday"]
# the same expansion UK2GTFS::expand_days_of_week does, so the two agree
EXPAND = {
    "MondayToFriday": WEEK,
    "MondayToSaturday": WEEK + ["Saturday"],
    "MondayToSunday": ALL7,
    "MondayToThursday": WEEK[:4],
    "Weekend": ["Saturday", "Sunday"],
    "NotMonday": [d for d in ALL7 if d != "Monday"],
    "NotTuesday": [d for d in ALL7 if d != "Tuesday"],
    "NotWednesday": [d for d in ALL7 if d != "Wednesday"],
    "NotThursday": [d for d in ALL7 if d != "Thursday"],
    "NotFriday": [d for d in ALL7 if d != "Friday"],
    "NotSaturday": [d for d in ALL7 if d != "Saturday"],
    "NotSunday": [d for d in ALL7 if d != "Sunday"],
}


def local(t):
    return t.rsplit("}", 1)[-1] if "}" in t else t


def scan(data):
    try:
        root = ET.fromstring(data)
    except Exception:
        return None
    svc = sd = None
    lines, days = set(), set()
    njy = 0
    for el in root.iter():
        t = local(el.tag)
        if t == "ServiceCode" and svc is None:
            svc = (el.text or "").strip()
        elif t == "StartDate" and sd is None:
            sd = (el.text or "").strip()
        elif t == "LineName":
            if el.text:
                lines.add(el.text.strip())
        elif t == "DaysOfWeek":
            for ch in el:
                n = local(ch.tag)
                days.update(EXPAND.get(n, [n]))
        elif t == "VehicleJourney":
            njy += 1
    return dict(svc=svc or "", start=sd or "",
                lines="|".join(sorted(lines)),
                days=",".join(sorted(days)), journeys=njy)


def iter_files(which):
    if which == "tnds":
        for z in sorted(glob.glob(TNDS_GLOB)):
            region = os.path.splitext(os.path.basename(z))[0]
            if region == "iom":
                continue
            zf = zipfile.ZipFile(z)
            for n in zf.namelist():
                if n.lower().endswith(".xml"):
                    yield region, n, zf.read(n)
    else:
        bz = zipfile.ZipFile(BODS_ZIP)
        for n in bz.namelist():
            low = n.lower()
            if low.endswith(".xml"):
                yield n.split("/")[0], n, bz.read(n)
            elif low.endswith(".zip"):
                try:
                    iz = zipfile.ZipFile(io.BytesIO(bz.read(n)))
                except Exception:
                    continue
                for inner in iz.namelist():
                    if inner.lower().endswith(".xml"):
                        yield n.split("/")[0], n + "!" + inner, iz.read(inner)


def main():
    which = sys.argv[1]
    out_csv = sys.argv[2] if len(sys.argv) > 2 else None

    rows = []
    for i, (group, path, data) in enumerate(iter_files(which)):
        r = scan(data)
        if r is None:
            continue
        r.update(group=group, path=path)
        rows.append(r)
        if (i + 1) % 2000 == 0:
            print("  %d files" % (i + 1), flush=True)
    print("%s: scanned %d files" % (which, len(rows)), flush=True)

    # One row per (ServiceCode, StartDate, Line) - rule 1's old key - carrying
    # the distinct day sets found under it.
    key = collections.defaultdict(list)
    for r in rows:
        for ln in (r["lines"].split("|") if r["lines"] else [""]):
            key[(r["svc"], r["start"], ln)].append(r)

    collided = {k: v for k, v in key.items()
                if len({x["days"] for x in v}) > 1}
    print("\nrule 1 keys (ServiceCode + StartDate + line): %d" % len(key))
    print("of those with MORE THAN ONE distinct day set: %d" % len(collided))

    # What the old key threw away: everything but one file per distinct
    # (key, day set). Files sharing a key AND a day set are true duplicates
    # and are removed by both the old key and the new one.
    lost_files = lost_jny = 0
    per_group = collections.Counter()
    per_group_jny = collections.Counter()
    for k, v in collided.items():
        by_days = collections.defaultdict(list)
        for x in v:
            by_days[x["days"]].append(x)
        # the new key keeps one per day set; the old key kept one in total
        recovered = len(by_days) - 1
        lost_files += recovered
        # journeys in the day sets the old key would have dropped: all but the
        # largest, which is the conservative reading of which one survived
        sizes = sorted((max(x["journeys"] for x in g)
                        for g in by_days.values()), reverse=True)
        lost_jny += sum(sizes[1:])
        per_group[v[0]["group"]] += recovered
        per_group_jny[v[0]["group"]] += sum(sizes[1:])

    print("\nfiles the day-type key keeps that the old key dropped: %d"
          % lost_files)
    print("vehicle journeys in them (lower bound):               %d"
          % lost_jny)
    print("\nby %s:" % ("region" if which == "tnds" else "publisher"))
    for g, n in per_group.most_common(15):
        print("  %-34s %5d files  %7d journeys" % (g, n, per_group_jny[g]))

    if out_csv:
        with open(out_csv, "w", newline="", encoding="utf8") as fh:
            w = csv.writer(fh)
            w.writerow(["group", "service_code", "start", "line",
                        "n_files", "n_day_sets", "day_sets"])
            for k, v in sorted(collided.items()):
                w.writerow([v[0]["group"], k[0], k[1], k[2], len(v),
                            len({x["days"] for x in v}),
                            " / ".join(sorted({x["days"] for x in v}))])
        print("\nwrote", out_csv)


if __name__ == "__main__":
    main()
