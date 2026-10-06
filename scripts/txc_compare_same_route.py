"""Compare the TransXChange for the same bus route in TNDS and in BODS.

scripts/txc_archive_index.py says which routes each archive holds. This asks
the next question: where both hold a route, do they describe the SAME
timetable? That is what decides whether the two archives can be merged into
one feed, because a merged feed has to recognise and drop the duplicate
journeys, and it can only do that if the journeys are recognisably the same.

The two archives cannot be joined on their service codes: TNDS carries
Traveline's own construction (cambs_A2BR_110_20110A) and BODS the traffic
commissioner's registration (PH0005994:151). They do agree on the national
operator code and the line name, so a route is identified here as
(NOC, LineName) - an operator and a route number. That key can collide where
one operator runs the same number in two places, so every comparison below
also reports the stop overlap, which makes a collision obvious.

For each sampled route it extracts, from every file in both archives that
carries it, the departure times of the service's vehicle journeys and the
stop points they call at, then reports

  * journeys in each archive, and how many are common to both
  * the stop sets and their overlap
  * the operating period each archive declares

Identical departure-time multisets mean a merge would see exact duplicates
and could drop them safely. Partial overlap is the difficult case: a merge
would keep both and double-count the shared journeys.

Usage: python scripts/txc_compare_same_route.py <index_dir> [n_routes]
"""

import collections
import csv
import io
import os
import random
import sys
import zipfile
import xml.etree.ElementTree as ET

DATA = "D:/OneDrive - University of Leeds/Data/UK2GTFS"
TNDS_DIR = DATA + "/TransXChange/data_20261002/TNDSV2.5"
BODS_ZIP = (DATA + "/OpenBusData/TransXchange/20261003/"
            "bodds_archive_20261003.zip")


def local(tag):
    return tag.rsplit("}", 1)[-1] if "}" in tag else tag


def journeys_for_line(data, want_lines):
    """Departure times and stops of the journeys on the wanted line(s).

    TransXChange links a VehicleJourney to a Line through its
    LineRef/ServiceRef, so the whole document is walked once, the Line
    elements are read to find which LineRef values correspond to the wanted
    route number, and only journeys referring to those are kept.
    """
    try:
        root = ET.parse(io.BytesIO(data)).getroot()
    except Exception:
        return None

    # LineRef -> LineName
    line_name = {}
    for el in root.iter():
        if local(el.tag) == "Line":
            lid = el.get("id")
            nm = None
            for ch in el:
                if local(ch.tag) == "LineName":
                    nm = (ch.text or "").strip()
            if lid is not None and nm is not None:
                line_name[lid] = nm

    wanted_refs = {lid for lid, nm in line_name.items() if nm in want_lines}

    deps, stops = [], set()
    period = [None, None]
    for el in root.iter():
        t = local(el.tag)
        if t == "OperatingPeriod":
            for ch in el:
                c = local(ch.tag)
                if c == "StartDate" and period[0] is None:
                    period[0] = (ch.text or "").strip()
                elif c == "EndDate" and period[1] is None:
                    period[1] = (ch.text or "").strip()
        elif t == "VehicleJourney":
            ref = None
            dep = None
            for ch in el:
                c = local(ch.tag)
                if c == "LineRef":
                    ref = (ch.text or "").strip()
                elif c == "DepartureTime":
                    dep = (ch.text or "").strip()
            # A document with no Line elements at all (or no LineRef on the
            # journey) is single-service, so every journey counts.
            take = (not wanted_refs) or (ref in wanted_refs) or ref is None
            if take and dep:
                deps.append(dep)
        elif t == "StopPointRef":
            if el.text:
                stops.add(el.text.strip())
    return {"deps": deps, "stops": stops, "period": tuple(period)}


def load_index(path):
    rows = []
    with open(path, encoding="utf8") as fh:
        for r in csv.DictReader(fh):
            rows.append(r)
    return rows


def route_keys(rows):
    """(noc, line) -> list of file paths, from an index."""
    out = collections.defaultdict(list)
    for r in rows:
        nocs = [x for x in r["noc"].split("|") if x]
        lines = [x for x in r["line_names"].split("|") if x]
        for n in nocs:
            for l in lines:
                out[(n, l)].append(r["path"])
    return out


def read_tnds(path):
    region = path.split("/")[0] if "/" in path else None
    # The index path is the name inside the regional zip; the region is the
    # index's group column, so try each archive until the name is found.
    for z in sorted(os.listdir(TNDS_DIR)):
        if not z.endswith(".zip"):
            continue
        zf = zipfile.ZipFile(os.path.join(TNDS_DIR, z))
        try:
            return zf.read(path)
        except KeyError:
            continue
    return None


_bods = None


def read_bods(path):
    global _bods
    if _bods is None:
        _bods = zipfile.ZipFile(BODS_ZIP)
    if "!" in path:
        outer, inner = path.split("!", 1)
        iz = zipfile.ZipFile(io.BytesIO(_bods.read(outer)))
        return iz.read(inner)
    return _bods.read(path)


def main():
    idx_dir = sys.argv[1]
    n_routes = int(sys.argv[2]) if len(sys.argv) > 2 else 40

    tn = load_index(os.path.join(idx_dir, "txc_index_tnds.csv"))
    bo = load_index(os.path.join(idx_dir, "txc_index_bods.csv"))
    tn_by = route_keys(tn)
    bo_by = route_keys(bo)
    tnds_path_region = {r["path"]: r["group"] for r in tn}

    shared = sorted(set(tn_by) & set(bo_by))
    print("routes (NOC+line) in TNDS: %d, in BODS: %d, in both: %d"
          % (len(tn_by), len(bo_by), len(shared)), flush=True)
    print("only TNDS: %d   only BODS: %d"
          % (len(set(tn_by) - set(bo_by)), len(set(bo_by) - set(tn_by))),
          flush=True)

    # Sample routes where each archive has a manageable number of files, so
    # the comparison is about the timetable rather than about which of
    # fourteen revisions to pick.
    cand = [k for k in shared
            if 1 <= len(tn_by[k]) <= 2 and 1 <= len(bo_by[k]) <= 3]
    print("comparable routes (few files each side): %d" % len(cand),
          flush=True)
    random.seed(42)
    pick = random.sample(cand, min(n_routes, len(cand)))

    out = []
    for noc, line in pick:
        t_dep, t_stops, t_per = [], set(), set()
        ok = True
        for p in tn_by[(noc, line)]:
            region = tnds_path_region.get(p)
            data = None
            if region:
                try:
                    zf = zipfile.ZipFile(
                        os.path.join(TNDS_DIR, region + ".zip"))
                    data = zf.read(p)
                except (KeyError, FileNotFoundError):
                    data = None
            if data is None:
                data = read_tnds(p)
            if data is None:
                ok = False
                continue
            r = journeys_for_line(data, {line})
            if r is None:
                ok = False
                continue
            t_dep += r["deps"]; t_stops |= r["stops"]; t_per.add(r["period"])

        b_dep, b_stops, b_per = [], set(), set()
        for p in bo_by[(noc, line)]:
            try:
                data = read_bods(p)
            except Exception:
                ok = False
                continue
            r = journeys_for_line(data, {line})
            if r is None:
                ok = False
                continue
            b_dep += r["deps"]; b_stops |= r["stops"]; b_per.add(r["period"])

        if not ok and not (t_dep or b_dep):
            continue
        ct, cb = collections.Counter(t_dep), collections.Counter(b_dep)
        common = sum((ct & cb).values())
        out.append({
            "noc": noc, "line": line,
            "tnds_files": len(tn_by[(noc, line)]),
            "bods_files": len(bo_by[(noc, line)]),
            "tnds_journeys": len(t_dep), "bods_journeys": len(b_dep),
            "common_departures": common,
            "tnds_only_dep": len(t_dep) - common,
            "bods_only_dep": len(b_dep) - common,
            "tnds_stops": len(t_stops), "bods_stops": len(b_stops),
            "stops_shared": len(t_stops & b_stops),
            "identical": int(ct == cb and bool(ct)),
            "tnds_period": ";".join(sorted(str(x) for x in t_per)),
            "bods_period": ";".join(sorted(str(x) for x in b_per)),
        })
        print("  %-6s %-6s TNDS %4d jny / BODS %4d jny / common %4d%s"
              % (noc, line, len(t_dep), len(b_dep), common,
                 "   IDENTICAL" if ct == cb and ct else ""), flush=True)

    fields = list(out[0].keys()) if out else []
    dest = os.path.join(idx_dir, "txc_same_route_compare.csv")
    with open(dest, "w", newline="", encoding="utf8") as fh:
        w = csv.DictWriter(fh, fields)
        w.writeheader()
        for r in out:
            w.writerow(r)
    print("\nwrote", dest, "(%d routes)" % len(out))

    if out:
        ident = sum(r["identical"] for r in out)
        print("identical timetables: %d of %d" % (ident, len(out)))
        tot_t = sum(r["tnds_journeys"] for r in out)
        tot_b = sum(r["bods_journeys"] for r in out)
        tot_c = sum(r["common_departures"] for r in out)
        print("journeys  TNDS %d  BODS %d  common %d" % (tot_t, tot_b, tot_c))
        if tot_t:
            print("share of TNDS journeys also in BODS: %.3f" % (tot_c / tot_t))
        if tot_b:
            print("share of BODS journeys also in TNDS: %.3f" % (tot_c / tot_b))


if __name__ == "__main__":
    main()
