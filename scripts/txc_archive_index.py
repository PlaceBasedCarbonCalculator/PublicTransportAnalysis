"""Index every TransXChange file in the TNDS and BODS archives for one snapshot.

The two archives are supposed to describe the same bus network. TNDS is the
Traveline aggregation, compiled regionally from the traffic commissioners'
registrations; BODS is what operators publish themselves under the Bus
Services Act. Whether they agree, and whether a service in both is described
by the *same* file or by two different ones, decides whether the two can be
merged into a single feed: a merged feed is only safe if the duplicate
journeys can be recognised and dropped.

This writes one row per TransXChange file with

  * the service registration code and line names, which is how a service can
    be followed between the two archives
  * the revision metadata (RevisionNumber, ModificationDateTime,
    CreationDateTime) that says which of two files is the later one
  * the operating period, which says how far forward the file carries
  * a fingerprint of the actual timetable: the multiset of vehicle-journey
    departure times and the set of stop points. Two files with the same
    fingerprint describe the same timetable whatever their metadata says,
    which is the only test that answers the merge question.

Output is a CSV per archive, written to the scratchpad path given on the
command line. Parsing is iterative and the element tree is cleared as it
goes, so memory stays flat across the ~37,500 files.

Usage: python scripts/txc_archive_index.py <out_dir> [tnds|bods|both]
"""

import csv
import glob
import hashlib
import io
import os
import sys
import zipfile
import xml.etree.ElementTree as ET

DATA = "D:/OneDrive - University of Leeds/Data/UK2GTFS"
TNDS_GLOB = DATA + "/TransXChange/data_20261002/TNDSV2.5/*.zip"
BODS_ZIP = (DATA + "/OpenBusData/TransXchange/20261003/"
            "bodds_archive_20261003.zip")

FIELDS = [
    "archive", "group", "path", "service_code", "line_names", "noc",
    "revision", "modification", "creation", "period_start", "period_end",
    "n_journeys", "n_stops", "n_patterns", "dep_fingerprint",
    "stop_fingerprint", "bytes",
]


def local(tag):
    """Element tag without its namespace."""
    return tag.rsplit("}", 1)[-1] if "}" in tag else tag


def parse_txc(data):
    """Pull the index fields out of one TransXChange document.

    Returns None when the document is not parseable as XML, which happens in
    the BODS archive for a handful of truncated uploads.
    """
    try:
        it = ET.iterparse(io.BytesIO(data), events=("start", "end"))
    except Exception:
        return None

    svc_codes, lines, nocs = [], [], []
    rev = mod = cre = pstart = pend = ""
    stops, deps, patterns = set(), [], set()
    # depth tracking so a DepartureTime inside a VehicleJourney is not
    # confused with one inside a JourneyPatternTimingLink
    in_vj = False

    try:
        for event, el in it:
            t = local(el.tag)
            if event == "start":
                if t == "VehicleJourney":
                    in_vj = True
                elif t == "TransXChange":
                    rev = el.get("RevisionNumber", "") or rev
                    mod = el.get("ModificationDateTime", "") or mod
                    cre = el.get("CreationDateTime", "") or cre
                continue

            # end events
            if t == "ServiceCode":
                if el.text:
                    svc_codes.append(el.text.strip())
            elif t == "LineName":
                if el.text:
                    lines.append(el.text.strip())
            elif t in ("NationalOperatorCode", "OperatorCode"):
                if el.text:
                    nocs.append(el.text.strip())
            elif t == "StopPointRef":
                if el.text:
                    stops.add(el.text.strip())
            elif t == "JourneyPatternRef":
                if el.text:
                    patterns.add(el.text.strip())
            elif t == "DepartureTime" and in_vj:
                if el.text:
                    deps.append(el.text.strip())
            elif t == "VehicleJourney":
                in_vj = False
            elif t == "StartDate" and not pstart:
                if el.text:
                    pstart = el.text.strip()
            elif t == "EndDate" and not pend:
                if el.text:
                    pend = el.text.strip()

            # Clearing on every end event keeps memory flat. The parent link
            # is not maintained by iterparse, so children of a still-open
            # element are cleared individually, which is safe here because
            # every value wanted has already been read by this point.
            el.clear()
    except ET.ParseError:
        # A truncated file still yields whatever was read before the break,
        # which is worth keeping: it is itself a finding about the archive.
        pass

    def fp(seq):
        if not seq:
            return ""
        h = hashlib.sha1()
        for s in seq:
            h.update(s.encode("utf8", "replace"))
            h.update(b"\x00")
        return h.hexdigest()[:16]

    return {
        "service_code": "|".join(sorted(set(svc_codes))),
        "line_names": "|".join(sorted(set(lines))),
        "noc": "|".join(sorted(set(nocs))),
        "revision": rev,
        "modification": mod,
        "creation": cre,
        "period_start": pstart,
        "period_end": pend,
        "n_journeys": len(deps),
        "n_stops": len(stops),
        "n_patterns": len(patterns),
        # sorted: two files listing the same journeys in a different order
        # describe the same timetable
        "dep_fingerprint": fp(sorted(deps)),
        "stop_fingerprint": fp(sorted(stops)),
    }


def emit(writer, archive, group, path, data, n_done):
    row = parse_txc(data)
    if row is None:
        row = {k: "" for k in FIELDS}
        row["n_journeys"] = row["n_stops"] = row["n_patterns"] = -1
    row.update(archive=archive, group=group, path=path, bytes=len(data))
    writer.writerow(row)
    if n_done % 2000 == 0:
        print("   %6d files" % n_done, flush=True)


def index_tnds(out_path):
    n = 0
    with open(out_path, "w", newline="", encoding="utf8") as fh:
        w = csv.DictWriter(fh, FIELDS)
        w.writeheader()
        for z in sorted(glob.glob(TNDS_GLOB)):
            region = os.path.splitext(os.path.basename(z))[0]
            print(" TNDS", region, flush=True)
            zf = zipfile.ZipFile(z)
            for name in zf.namelist():
                if not name.lower().endswith(".xml"):
                    continue
                n += 1
                emit(w, "tnds", region, name, zf.read(name), n)
    print(" TNDS done:", n, "files ->", out_path, flush=True)


def index_bods(out_path):
    n = 0
    bz = zipfile.ZipFile(BODS_ZIP)
    with open(out_path, "w", newline="", encoding="utf8") as fh:
        w = csv.DictWriter(fh, FIELDS)
        w.writeheader()
        for name in bz.namelist():
            org = name.split("/")[0]
            low = name.lower()
            if low.endswith(".xml"):
                n += 1
                emit(w, "bods", org, name, bz.read(name), n)
            elif low.endswith(".zip"):
                try:
                    iz = zipfile.ZipFile(io.BytesIO(bz.read(name)))
                except Exception as e:
                    print("   unreadable nested zip", name, e, flush=True)
                    continue
                for inner in iz.namelist():
                    if not inner.lower().endswith(".xml"):
                        continue
                    n += 1
                    emit(w, "bods", org, name + "!" + inner,
                         iz.read(inner), n)
    print(" BODS done:", n, "files ->", out_path, flush=True)


if __name__ == "__main__":
    out_dir = sys.argv[1]
    which = sys.argv[2] if len(sys.argv) > 2 else "both"
    os.makedirs(out_dir, exist_ok=True)
    if which in ("tnds", "both"):
        index_tnds(os.path.join(out_dir, "txc_index_tnds.csv"))
    if which in ("bods", "both"):
        index_bods(os.path.join(out_dir, "txc_index_bods.csv"))
