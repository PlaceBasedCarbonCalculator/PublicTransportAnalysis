"""Extract one pass of the BODS archive into per-operator directories.

The index already says which file carries which operator code, so the paths
are known up front and the 1.6 GB archive needs to be walked exactly once.
"""
import collections
import csv
import io
import os
import sys
import zipfile

DATA = "D:/OneDrive - University of Leeds/Data/UK2GTFS"
BODS = DATA + "/OpenBusData/TransXchange/20261003/bodds_archive_20261003.zip"

idx_dir, out_dir = sys.argv[1], sys.argv[2]
WANT = set(sys.argv[3].split(","))

want_paths = collections.defaultdict(set)   # noc -> {path}
by_outer = collections.defaultdict(list)    # outer entry -> [(inner, noc)]
with open(os.path.join(idx_dir, "txc_index_bods.csv"), encoding="utf8") as fh:
    for r in csv.DictReader(fh):
        nocs = set(x for x in r["noc"].split("|") if x) & WANT
        if not nocs:
            continue
        p = r["path"]
        for n in nocs:
            want_paths[n].add(p)
        outer, inner = (p.split("!", 1) + [None])[:2] if "!" in p else (p, None)
        by_outer[outer].append((inner, sorted(nocs)[0]))

for n in sorted(WANT):
    print("%s: %d files in %d archive entries"
          % (n, len(want_paths[n]),
             sum(1 for o, v in by_outer.items()
                 if any(x[1] == n for x in v))), flush=True)
    os.makedirs(os.path.join(out_dir, n), exist_ok=True)

bz = zipfile.ZipFile(BODS)
done = 0
for outer, items in by_outer.items():
    if outer.lower().endswith(".zip"):
        try:
            iz = zipfile.ZipFile(io.BytesIO(bz.read(outer)))
        except Exception as e:
            print("  skip", outer, e, flush=True)
            continue
        for inner, noc in items:
            try:
                data = iz.read(inner)
            except KeyError:
                continue
            # Short names: Windows MAX_PATH is reached otherwise, and
            # txc_filter_files reads the XML content, not the file name.
            done += 0
            name = "%05d.xml" % (len(os.listdir(os.path.join(out_dir, noc))) + 1)
            with open(os.path.join(out_dir, noc, name), "wb") as fh:
                fh.write(data)
            done += 1
    else:
        noc = items[0][1]
        data = bz.read(outer)
        with open(os.path.join(out_dir, noc,
                               os.path.basename(outer)), "wb") as fh:
            fh.write(data)
        done += 1
print("extracted", done, "files", flush=True)
for n in sorted(WANT):
    d = os.path.join(out_dir, n)
    print("  %s: %d on disk" % (n, len(os.listdir(d))))
