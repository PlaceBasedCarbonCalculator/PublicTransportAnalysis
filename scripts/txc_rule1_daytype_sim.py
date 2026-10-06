"""Which rule of txc_filter_files() drops Brighton & Hove's day-type files?

Rule 1 deduplicates on (operator + ServiceCode, StartDate, Line), keeping the
file with the highest RevisionNumber. If an operator publishes one file per
day type for the same service, line and operating period, all of them collide
on that key and only one survives - and the day type is nowhere in the key,
nor in the metadata the function reads at all.

This extracts the fields rule 1 keys on, plus the operating day set, from
Brighton & Hove's BODS files, applies rule 1's grouping, and reports what it
would remove and whether the removed files differ from the survivor only in
their day set.
"""
import collections
import csv
import glob
import io
import os
import sys
import xml.etree.ElementTree as ET

DIR = sys.argv[1]
WIN = ("2026-10-05", "2026-10-18")


def local(t):
    return t.rsplit("}", 1)[-1] if "}" in t else t


DAYNAMES = {"Monday", "Tuesday", "Wednesday", "Thursday", "Friday",
            "Saturday", "Sunday", "MondayToFriday", "MondayToSaturday",
            "MondayToSunday", "Weekend", "NotMonday", "NotSaturday",
            "NotSunday", "HolidaysOnly", "MondayToThursday"}


def scan(path):
    try:
        root = ET.parse(path).getroot()
    except Exception:
        return None
    svc = sd = ed = rev = mod = None
    lines, days = set(), set()
    for el in root.iter():
        t = local(el.tag)
        if t == "ServiceCode" and svc is None:
            svc = (el.text or "").strip()
        elif t == "StartDate" and sd is None:
            sd = (el.text or "").strip()
        elif t == "EndDate" and ed is None:
            ed = (el.text or "").strip()
        elif t == "LineName":
            if el.text:
                lines.add(el.text.strip())
        elif t == "DaysOfWeek":
            for ch in el:
                n = local(ch.tag)
                if n in DAYNAMES:
                    days.add(n)
    rev = root.get("RevisionNumber")
    mod = root.get("ModificationDateTime") or root.get("CreationDateTime")
    return dict(file=os.path.basename(path), svc=svc or "", start=sd or "",
                end=ed or "", rev=rev or "-1", mod=mod or "",
                lines="|".join(sorted(lines)),
                days=",".join(sorted(days)))


rows = []
files = sorted(glob.glob(os.path.join(DIR, "*.xml")))
for i, f in enumerate(files):
    r = scan(f)
    if r:
        rows.append(r)
    if (i + 1) % 200 == 0:
        print("  %d/%d" % (i + 1, len(files)), flush=True)
print("scanned", len(rows), "files", flush=True)

# Keep only files whose operating period overlaps the counting window; the
# earlier weekly blocks are legitimately superseded by the filter date.
win = [r for r in rows if r["start"] and r["start"] <= WIN[1]
       and (not r["end"] or r["end"] >= WIN[0])]
print("overlapping the window:", len(win), flush=True)


def revnum(r):
    try:
        return float(r["rev"])
    except ValueError:
        return -1.0


# Rule 1 as implemented: sort by svc_key, StartDate, then RevisionNumber and
# ModificationDateTime descending; explode to one row per line; keep the first
# row for each (svc_key, StartDate, Line); a file survives if it is first for
# at least one of its lines.
win.sort(key=lambda r: (r["svc"], r["start"], -revnum(r), r["mod"]),
         reverse=False)
win.sort(key=lambda r: (r["svc"], r["start"]))
ordered = sorted(win, key=lambda r: (r["svc"], r["start"], -revnum(r),
                                     r["mod"]))

seen = set()
survives = set()
for r in ordered:
    for ln in (r["lines"].split("|") if r["lines"] else [""]):
        k = (r["svc"], r["start"], ln)
        if k not in seen:
            seen.add(k)
            survives.add(r["file"])

kept = [r for r in ordered if r["file"] in survives]
dropped = [r for r in ordered if r["file"] not in survives]
print("\nrule 1 alone: keeps %d, drops %d of %d"
      % (len(kept), len(dropped), len(ordered)))

# Of the files rule 1 drops, how many collide with a survivor that has the
# same service, start and lines but a DIFFERENT day set?
by_key = collections.defaultdict(list)
for r in kept:
    by_key[(r["svc"], r["start"], r["lines"])].append(r)

same_all, diff_days, other = 0, 0, 0
examples = []
for r in dropped:
    k = (r["svc"], r["start"], r["lines"])
    survivors = by_key.get(k, [])
    if not survivors:
        other += 1
        continue
    if any(s["days"] == r["days"] for s in survivors):
        same_all += 1
    else:
        diff_days += 1
        if len(examples) < 12:
            examples.append((r, survivors[0]))

print("\nof the files rule 1 drops, those colliding with a survivor on")
print("  service + start + lines:")
print("    identical day set (a true duplicate):      %d" % same_all)
print("    DIFFERENT day set (complementary, lost):   %d" % diff_days)
print("    no survivor with those lines:              %d" % other)

print("\nexamples of a complementary file dropped:")
for r, s in examples:
    print("  svc=%s line=%s period=%s..%s" % (r["svc"], r["lines"],
                                              r["start"], r["end"]))
print("    dropped days=%-45s rev=%s" % (r["days"], r["rev"]))
print("    kept    days=%-45s rev=%s" % (s["days"], s["rev"]))

dest = os.path.join(DIR, "..", "bhbc_rule1_sim.csv")
with open(dest, "w", newline="", encoding="utf8") as fh:
    w = csv.DictWriter(fh, list(ordered[0].keys()) + ["kept_by_rule1"])
    w.writeheader()
    for r in ordered:
        r2 = dict(r)
        r2["kept_by_rule1"] = int(r["file"] in survives)
        w.writerow(r2)
print("\nwrote", os.path.normpath(dest))
