"""Compare the two editions of a TNDS snapshot, and build a blend of them.

    python -I scripts/tnds_editions/tnds_editions.py <snapshot folder> <out dir> <date> [--blend <zip dir>]

TNDS publishes each snapshot as TransXChange 2.1 regional zips at the top
level and as a 2.5 rendering in TNDSV2.5/. The 2.5 edition is the one TNDS
has applied its cross-boundary deduplication to, so it drops a service
published in two regions - and, it turns out, a few services published in
one. This reads every file of both editions and writes:

  files.csv    one row per (edition, region, file): service code, lines,
               operator, operating period, journeys, and fingerprints of the
               stops called at, the journeys' departure times and the
               operating profiles, so the editions can be compared on content
               rather than bytes (the schemas differ, so bytes always do)
  pairs.csv    one row per file name: in which editions it is, and for a
               file in both which fingerprints differ
  only21.csv   each 2.1-only file with the share of its stops served, in the
               2.5 edition, by a file with the same line (anywhere in
               Britain) that operates on <date>, and whether it is itself
               active on <date>

  cross_region_25.csv  pairs of 2.5 files from different regions, both
               operating on <date>, sharing a line and at least half of the
               smaller file's stops, whatever their operator or ServiceCode:
               candidate copies of one service that no filter can see,
               because txc_filter_files() runs one region zip at a time
               (--dups-only writes just this, from the 2.5 edition)

With --blend it also writes one zip per region into <zip dir>: every 2.5
file, plus each 2.1-only file whose stops the 2.5 edition serves under the
same line at fewer than half (`covered < 0.5`) - a service 2.5 lost rather
than a duplicate it removed. The files added are listed in blend_added.csv.
"""
import csv
import hashlib
import io
import os
import re
import sys
import zipfile
from collections import defaultdict

REGIONS = ["EA", "EM", "L", "NE", "NW", "S", "SE", "SW", "W", "WM", "Y"]


def h(items):
    return hashlib.md5("\n".join(items).encode("utf-8")).hexdigest()[:12]


def first(pat, text, default=""):
    m = re.search(pat, text, re.S)
    return m.group(1).strip() if m else default


def meta(text):
    svc = text[text.find("<Services>"):text.find("</Services>")]
    vjs = text[text.find("<VehicleJourneys>"):text.find("</VehicleJourneys>")]
    lines = sorted(set(re.findall(r"<LineName>([^<]+)</LineName>", svc)))
    used = sorted(set(re.findall(r"<StopPointRef>([^<]+)</StopPointRef>",
                                 text[text.find("</StopPoints>"):])))
    deps = sorted(re.findall(r"<DepartureTime>([^<]+)</DepartureTime>", vjs))
    profiles = sorted(re.findall(r"<OperatingProfile>(.*?)</OperatingProfile>", text, re.S))
    profiles = [re.sub(r"\s+", "", p) for p in profiles]
    return {
        "service_code": first(r"<ServiceCode>([^<]+)</ServiceCode>", svc),
        "lines": ",".join(lines),
        "noc": first(r"<NationalOperatorCode>([^<]+)<", text),
        "mode": first(r"<Mode>([^<]+)</Mode>", svc),
        "start": first(r"<OperatingPeriod>\s*<StartDate>([^<]+)</StartDate>", svc),
        "end": first(r"<OperatingPeriod>\s*<StartDate>[^<]+</StartDate>\s*<EndDate>([^<]+)</EndDate>", svc),
        "modified": first(r'ModificationDateTime="([^"]+)"', text[:3000])[:19],
        "schema": first(r'SchemaVersion="([^"]+)"', text[:3000]),
        "journeys": len(deps),
        "n_stops": len(used),
        "stops_fp": h(used),
        "times_fp": h(deps),
        "profiles_fp": h(profiles),
        "_stops": used,
        "_lines": lines,
    }


def read_edition(path):
    """{(region, file): meta} for one edition folder."""
    out = {}
    for r in REGIONS:
        zp = os.path.join(path, r + ".zip")
        if not os.path.exists(zp):
            continue
        z = zipfile.ZipFile(zp)
        for n in z.namelist():
            if not n.lower().endswith(".xml"):
                continue
            out[(r, n)] = meta(z.read(n).decode("utf-8", "replace"))
        print(f"  {path} {r}: {sum(1 for k in out if k[0] == r)} files", flush=True)
    return out


def cross_region_duplicates(ed, date, path):
    """Pairs of files from different region zips that look like one service.

    Same line name, at least half of the smaller file's stops in common, and
    both operating on `date`. Operator and ServiceCode are ignored on purpose:
    that is what lets a TfL file and an operator's own export of the same
    route (439: METR in London, GAHL in the South East) escape every rule of
    txc_filter_files(), which keys on them and runs one zip at a time.
    """
    by_line = defaultdict(list)
    for (r, n), m in ed.items():
        active = m["start"] <= date and (m["end"] == "" or m["end"] >= date)
        if not active or not m["_stops"]:
            continue
        for ln in m["_lines"]:
            by_line[ln].append((r, n, m))
    rows = []
    for ln, fs in by_line.items():
        for i in range(len(fs)):
            for j in range(i + 1, len(fs)):
                (ra, na, a), (rb, nb, b) = fs[i], fs[j]
                if ra == rb:
                    continue
                sa, sb = set(a["_stops"]), set(b["_stops"])
                shared = len(sa & sb)
                ov = shared / min(len(sa), len(sb))
                if ov < 0.5:
                    continue
                rows.append([ln, ra, na, a["noc"], a["service_code"], a["journeys"],
                             rb, nb, b["noc"], b["service_code"], b["journeys"],
                             shared, len(sa), len(sb), round(ov, 3),
                             a["times_fp"] == b["times_fp"]])
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["line", "region_a", "file_a", "noc_a", "code_a", "journeys_a",
                    "region_b", "file_b", "noc_b", "code_b", "journeys_b",
                    "shared_stops", "stops_a", "stops_b", "overlap",
                    "same_times"])
        w.writerows(sorted(rows))
    print(f"{len(rows)} cross-region pairs in the 2.5 edition")


def main(argv):
    src, out_dir, date = argv[1], argv[2], argv[3]
    if "--dups-only" in argv:
        os.makedirs(out_dir, exist_ok=True)
        ed = read_edition(os.path.join(src, "TNDSV2.5"))
        cross_region_duplicates(ed, date, os.path.join(out_dir, "cross_region_25.csv"))
        return
    blend_dir = argv[argv.index("--blend") + 1] if "--blend" in argv else None
    os.makedirs(out_dir, exist_ok=True)
    eds = {"2.1": read_edition(src), "2.5": read_edition(os.path.join(src, "TNDSV2.5"))}

    cols = ["edition", "region", "file", "service_code", "lines", "noc", "mode",
            "start", "end", "modified", "schema", "journeys", "n_stops",
            "stops_fp", "times_fp", "profiles_fp"]
    with open(os.path.join(out_dir, "files.csv"), "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(cols)
        for ed, d in eds.items():
            for (r, n), m in sorted(d.items()):
                w.writerow([ed, r, n] + [m[c] for c in cols[3:]])

    # Pairing by region + file name
    keys = sorted(set(eds["2.1"]) | set(eds["2.5"]))
    fps = ["service_code", "lines", "noc", "start", "end", "journeys", "stops_fp",
           "times_fp", "profiles_fp"]
    with open(os.path.join(out_dir, "pairs.csv"), "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["region", "file", "in_21", "in_25", "differs"])
        for k in keys:
            a, b = eds["2.1"].get(k), eds["2.5"].get(k)
            diff = ""
            if a and b:
                diff = ";".join(c for c in fps if a[c] != b[c])
            w.writerow([k[0], k[1], a is not None, b is not None, diff])

    # 2.1-only files: is their service in 2.5 under another file?
    # line -> stops of the 2.5 files with that line operating on the date. A
    # 2.5 file that has not started yet, or has ended, does not carry the
    # service on the day: Stagecoach South Wales 130 and 150 have a 2.5 file
    # each, and neither runs on 20 November 2026.
    served = defaultdict(set)
    for m in eds["2.5"].values():
        if not (m["start"] <= date and (m["end"] == "" or m["end"] >= date)):
            continue
        for ln in m["_lines"]:
            served[ln].update(m["_stops"])
    only = []
    for k, m in sorted(eds["2.1"].items()):
        if k in eds["2.5"]:
            continue
        stops = m["_stops"]
        s = set()
        for ln in m["_lines"]:
            s |= served.get(ln, set())
        cov = sum(1 for x in stops if x in s) / len(stops) if stops else 0.0
        active = m["start"] <= date and (m["end"] == "" or m["end"] >= date)
        only.append([k[0], k[1], m["lines"], m["noc"], m["mode"], m["start"], m["end"],
                     m["journeys"], m["n_stops"], round(cov, 3), active])
    ocols = ["region", "file", "lines", "noc", "mode", "start", "end", "journeys",
             "n_stops", "covered", "active"]
    with open(os.path.join(out_dir, "only21.csv"), "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(ocols)
        w.writerows(only)
    print(f"{len(only)} files in 2.1 only; {sum(1 for o in only if o[9] < 0.5)} not "
          f"served by 2.5 under the same line")
    cross_region_duplicates(eds["2.5"], date, os.path.join(out_dir, "cross_region_25.csv"))

    if blend_dir:
        os.makedirs(blend_dir, exist_ok=True)
        add = defaultdict(list)
        for o in only:
            if o[9] < 0.5:
                add[o[0]].append(o[1])
        with open(os.path.join(out_dir, "blend_added.csv"), "w", newline="",
                  encoding="utf-8") as f:
            w = csv.writer(f)
            w.writerow(ocols)
            w.writerows([o for o in only if o[9] < 0.5])
        for r in REGIONS:
            z25 = os.path.join(src, "TNDSV2.5", r + ".zip")
            if not os.path.exists(z25):
                continue
            dest = os.path.join(blend_dir, r + ".zip")
            tmp = dest + ".part"
            with zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as zo:
                with zipfile.ZipFile(z25) as zi:
                    for n in zi.namelist():
                        zo.writestr(n, zi.read(n))
                if add[r]:
                    with zipfile.ZipFile(os.path.join(src, r + ".zip")) as zi:
                        for n in add[r]:
                            zo.writestr(n, zi.read(n))
            os.replace(tmp, dest)
            print(f"  blend {r}: 2.5 + {len(add[r])} files", flush=True)


if __name__ == "__main__":
    main(sys.argv)
