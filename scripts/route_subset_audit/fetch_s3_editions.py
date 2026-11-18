"""Download, from the Go-Ahead passenger-site bucket, the timetable edition of
each wanted route in force on the check day.

usage: python -I fetch_s3_editions.py <s3keys.txt> <YYYYMMDD> <out dir> prefix:route,route,... [prefix:...]
  e.g. metrobus/MB:10,100,200 morebus/WDBC:22,X6
Picks the latest edition dated on or before the day (reports a later one
dated before the end of the month, which would mean a change in the window).
Files are named <prefix>_<key basename>, as data/example_timetables holds them.
"""
import collections, os, re, sys, urllib.request

B = "https://passenger-line-assets.s3.eu-west-1.amazonaws.com/"
keys, day, out = sys.argv[1], sys.argv[2], sys.argv[3]
os.makedirs(out, exist_ok=True)
ed = collections.defaultdict(list)
for k in (l.strip() for l in open(keys)):
    m = re.match(r'([^/]+/[^/]+)/(.+)-timetable-(\d{8})-[0-9a-f]+\.pdf$', k)
    if m:
        ed[(m.group(1), m.group(2).lower())].append((m.group(3), k))
for spec in sys.argv[4:]:
    pre, routes = spec.split(':')
    for r in routes.split(','):
        e = sorted(ed.get((pre, r.lower()), []))
        before = [x for x in e if x[0] <= day]
        if not before:
            print(f'{pre} {r}: no edition on or before {day} ({len(e)} editions)')
            continue
        d, k = before[-1]
        later = [x[0] for x in e if x[0] > day and x[0] <= day[:6] + '31']
        name = pre.replace('/', '_') + '_' + os.path.basename(k)
        path = os.path.join(out, name)
        if not os.path.exists(path):
            urllib.request.urlretrieve(B + k, path)
        print(f'{pre} {r}: {d} -> {name}' + (f'  LATER {later}' if later else ''))
