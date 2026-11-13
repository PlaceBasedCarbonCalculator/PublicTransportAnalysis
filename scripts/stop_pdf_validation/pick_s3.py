"""Pick, from a listing of the Go-Ahead passenger-site bucket (s3list.py in
../zone_pdf_validation), the timetable edition in force at the start of the
stop-validation window, for the routes the stop cases need.

usage: python pick_s3.py s3keys.txt > picks.tsv
Prints prefix, route, the picked key, and any editions dated inside the
window (which would mean the timetable changed part way through it)."""
import re, sys, collections
WIN0, WIN1 = '20260727', '20260809'
want = {
    'brightonhove/BH': '12 12A 12X 14 14C 18 20 50 N12 5B 3X'.split(),
    'brightonhove/COMT': ['37B'],
    'metrobus/MB': '10 100 200'.split(),
    'eyms/EY': '56 57'.split(),
    'centralconnect/HEDO': '7 7A 46 49 305 332 333'.split(),
    'centralconnect/KCTB': '7 7A 46 49 305 332 333'.split(),
    'konectbus/KCTB': '7 7A 46 49 305 332 333'.split(),
    'hedinghamandchambers/HEDO': '49 7 7A 46 332 333'.split(),
    'gonortheast/GNE': 'Q3X Q3 49'.split(),
    'transdevblazefield/KDT': 'K7'.split(),
}
ed = collections.defaultdict(list)
for k in (l.strip() for l in open(sys.argv[1])):
    m = re.match(r'([^/]+/[^/]+)/(.+)-timetable-(\d{8})-[0-9a-f]+\.pdf$', k)
    if m:
        ed[(m.group(1), m.group(2).lower())].append((m.group(3), k))
for pre, routes in want.items():
    for r in routes:
        e = sorted(ed.get((pre, r.lower()), []))
        if not e:
            continue
        before = [x for x in e if x[0] <= WIN0]
        during = [d for d, _ in e if WIN0 < d <= WIN1]
        pick = before[-1][1] if before else ''
        print(pre, r, pick, ','.join(during), sep='\t')
