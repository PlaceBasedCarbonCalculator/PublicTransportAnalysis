"""Journeys the filtered TransXChange files publish, per operator, line and date.
The raw side of a national conversion-faithfulness check. Reads every file
under <filtered dir> (the output of filtered_files.R, so the periods are the
ones the converter saw) with txcday.py's independent reading of the operating
rules, and writes one row per region, file, NOC, line and date with the
number of vehicle journeys the file runs that day. faithful_compare.R sets
this against the converted feed's trips.
usage: python -I faithful.py <filtered dir> <YYYY-MM-DD first day> <ndays> <out.csv>
"""
import csv
import datetime as dt
import os
import sys
import xml.etree.ElementTree as ET
from concurrent.futures import ProcessPoolExecutor

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import txcday  # noqa: E402

NS = txcday.NS


def one(args):
    path, dates = args
    try:
        xml = open(path, 'rb').read()
        root = ET.fromstring(xml)
    except Exception as e:  # malformed file: the converter skips it too
        return [(path, 'ERROR', str(e)[:60], '', 0)]
    # UK2GTFS names the agency by NationalOperatorCode, else OperatorCode
    nocs = sorted({x.text.strip() for x in root.iter('{%s}NationalOperatorCode' % NS['t']) if x.text})
    if not nocs:
        nocs = sorted({x.text.strip() for x in root.iter('{%s}OperatorCode' % NS['t']) if x.text})
    noc = ';'.join(nocs)
    out = []
    for line, days in txcday.runs_on(xml, dates).items():
        for d, n in days.items():
            out.append((path, noc, line, d.isoformat(), n))
    return out


def main(src, first, ndays, outp):
    d0 = dt.date.fromisoformat(first)
    dates = [d0 + dt.timedelta(days=i) for i in range(int(ndays))]
    files = []
    for root, _, names in os.walk(src):
        for n in names:
            if n.lower().endswith('.xml'):
                files.append(os.path.join(root, n))
    files.sort()
    with open(outp, 'w', newline='', encoding='utf-8') as fh:
        w = csv.writer(fh)
        w.writerow(['region', 'file', 'noc', 'line', 'date', 'n'])
        done = 0
        with ProcessPoolExecutor() as ex:
            for rows in ex.map(one, [(f, dates) for f in files], chunksize=8):
                for path, noc, line, d, n in rows:
                    rel = os.path.relpath(path, src).replace('\\', '/')
                    region, _, fname = rel.partition('/')
                    w.writerow([region, fname, noc, line, d, n])
                done += 1
                if done % 2000 == 0:
                    print(done, 'of', len(files), file=sys.stderr, flush=True)
    print('files', len(files), file=sys.stderr)


if __name__ == '__main__':
    main(*sys.argv[1:5])
