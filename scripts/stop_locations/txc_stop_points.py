"""Every stop every TransXChange file declares, and where (if anywhere) it says it is.

    python -I scripts/stop_locations/txc_stop_points.py <out dir> <source>=<zip or folder> ...

    e.g. tnds21=".../data_20261118"  tnds25=".../data_20261118/TNDSV2.5"
         bods_txc=".../bodds_archive_20261118.zip"

A source is a folder of zips (each zip one region, read in turn) or a single
zip; zips nested inside zips (the BODS archive) are opened in memory. For
each file this records the stops declared under <StopPoints>, as a reference
to NaPTAN (<AnnotatedStopPointRef>) or a full definition (<StopPoint>), with
the location the file gives - an OS grid reference, a WGS84 position or both
- and whether the timetable actually calls there. Stops the timetable calls
at without declaring them are recorded too (form "undeclared").

Writes, per source:
  <source>_points.csv.gz  source, zip, file, publisher, noc, stop_id, form,
                          used, easting, northing, lon, lat, grid
  <source>_files.csv      one row per file: declared, full definitions,
                          located, used, used but undeclared

publisher is the file-name prefix TNDS uses for whoever supplied the file
(tfl, twm, essex, square, ...); for the BODS archive it is the folder or zip
the file came in.
"""
import csv
import gzip
import io
import os
import re
import sys
import zipfile

DECL = re.compile(r"<(StopPoint|AnnotatedStopPointRef)\b[^>]*>(.*?)</\1>", re.S)
ID = re.compile(r"<(?:AtcoCode|StopPointRef)>\s*([^<\s]+)\s*<")
LOC = re.compile(r"<Location\b[^>]*>(.*?)</Location>", re.S)
REF = re.compile(r"<StopPointRef>\s*([^<\s]+)\s*</StopPointRef>")


def num(pat, text):
    m = re.search(r"<" + pat + r">\s*([-0-9.]+)\s*</" + pat + ">", text)
    return m.group(1) if m else ""


def scan(text):
    """(rows, summary) for one TransXChange document."""
    a, b = text.find("<StopPoints"), text.find("</StopPoints>")
    sp = text[a:b] if a >= 0 and b > a else ""
    rest = text[b:] if b > 0 else text
    used = set(REF.findall(rest[:rest.find("<VehicleJourneys")] if "<VehicleJourneys" in rest else rest))
    rows, seen = [], set()
    for m in DECL.finditer(sp):
        form, body = m.group(1), m.group(2)
        i = ID.search(body)
        if not i:
            continue
        sid = i.group(1)
        loc = LOC.search(body)
        lt = loc.group(1) if loc else ""
        grid = re.search(r"<GridType>([^<]+)</GridType>", lt)
        rows.append([sid, form, sid in used, num("Easting", lt), num("Northing", lt),
                     num("Longitude", lt), num("Latitude", lt),
                     grid.group(1) if grid else ""])
        seen.add(sid)
    for sid in sorted(used - seen):
        rows.append([sid, "undeclared", True, "", "", "", "", ""])
    noc = re.search(r"<NationalOperatorCode>([^<]+)<", text)
    s = {
        "noc": noc.group(1) if noc else "",
        "declared": sum(1 for r in rows if r[1] != "undeclared"),
        "full": sum(1 for r in rows if r[1] == "StopPoint"),
        "located": sum(1 for r in rows if r[3] or r[5]),
        "used": len(used),
        "undeclared": sum(1 for r in rows if r[1] == "undeclared"),
    }
    return rows, s


def publisher(name, outer):
    base = os.path.basename(name)
    m = re.match(r"^([A-Za-z]+)_", base)
    if outer:
        return outer
    return m.group(1).lower() if m else ""


def walk_zip(z, zipname, outer, emit):
    for n in z.namelist():
        low = n.lower()
        if low.endswith(".zip"):
            try:
                inner = zipfile.ZipFile(io.BytesIO(z.read(n)))
            except zipfile.BadZipFile:
                continue
            walk_zip(inner, zipname, outer or os.path.basename(n)[:-4], emit)
        elif low.endswith(".xml"):
            pub = outer if outer else publisher(n, "")
            if not outer and "/" in n:
                pub = n.split("/")[0]
            emit(zipname, n, pub, z.read(n).decode("utf-8", "replace"))


def main(argv):
    out = argv[1]
    os.makedirs(out, exist_ok=True)
    for spec in argv[2:]:
        name, path = spec.split("=", 1)
        zips = ([os.path.join(path, f) for f in sorted(os.listdir(path))
                 if f.lower().endswith(".zip") and f.lower() != "iom.zip"]
                if os.path.isdir(path) else [path])
        pf = gzip.open(os.path.join(out, f"{name}_points.csv.gz"), "wt",
                       newline="", encoding="utf-8")
        ff = open(os.path.join(out, f"{name}_files.csv"), "w", newline="",
                  encoding="utf-8")
        pw, fw = csv.writer(pf), csv.writer(ff)
        pw.writerow(["source", "zip", "file", "publisher", "noc", "stop_id", "form",
                     "used", "easting", "northing", "lon", "lat", "grid"])
        fw.writerow(["source", "zip", "file", "publisher", "noc", "declared", "full",
                     "located", "used", "undeclared"])
        count = [0]

        def emit(zipname, fname, pub, text):
            rows, s = scan(text)
            for r in rows:
                pw.writerow([name, zipname, fname, pub, s["noc"]] + r)
            fw.writerow([name, zipname, fname, pub, s["noc"], s["declared"], s["full"],
                         s["located"], s["used"], s["undeclared"]])
            count[0] += 1
            if count[0] % 2000 == 0:
                print(f"  {name}: {count[0]} files", flush=True)

        for zp in zips:
            zn = os.path.basename(zp)
            if zn.upper().startswith("NCSD"):
                continue
            walk_zip(zipfile.ZipFile(zp), zn, "", emit)
        pf.close()
        ff.close()
        print(f"{name}: {count[0]} files", flush=True)


if __name__ == "__main__":
    main(sys.argv)
