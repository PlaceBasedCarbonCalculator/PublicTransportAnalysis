"""The route manifest of the working subset.

From seed_routes.csv and the selected operators: every filter-candidate route
of those operators, plus the routes of the same operators where the sources
agree (controls, so a rule change that breaks a good route is seen), with the
reference stop and the November feed counts. Verdict columns are filled in by
hand as routes are checked.

usage: python -I make_manifest.py [seed csv] [operators txt] [out csv]
"""
import csv, re, sys

seed = sys.argv[1] if len(sys.argv) > 1 else 'data/route_subset/seed_routes.csv'
sel = sys.argv[2] if len(sys.argv) > 2 else 'data/route_subset/selected_operators.txt'
out = sys.argv[3] if len(sys.argv) > 3 else 'data/route_subset/routes.csv'
norm = lambda s: re.sub(r'[^a-z0-9]+', '', s.lower().replace('&', 'and'))
names = set()
for line in open(sel, encoding='utf-8'):
    if line.startswith('names='):
        names = set(line[6:].strip().split(','))

rows = []
for r in csv.DictReader(open(seed, encoding='utf-8')):
    ops = {norm(x) for x in re.split(r' ; | / ', r['operators'])}
    if not ops & names:
        continue
    cand = r['filter_candidate'] == 'TRUE'
    agree = r['class'].startswith('agree')
    if not (cand or agree):
        continue
    rows.append(dict(
        grp=r['grp'], line=r['line'], operator=re.split(r' ; | / ', r['operators'])[0],
        operators=r['operators'],
        role='candidate' if cand else 'control', seed_class=r['class'],
        tnds=r['tnds'], bods_txc=r['bods_txc'], bods_gtfs=r['bods_gtfs'],
        tnds_raw_max=r['tnds_raw_max'], bods_raw_max=r['bods_raw_max'],
        ref_stop=r['ref_stop'], stop_name=r['stop_name'],
        ref_tnds=r['ref_tnds'], ref_bods_txc=r['ref_bods_txc'], ref_bods_gtfs=r['ref_bods_gtfs'],
        ease=r['ease'], pdf=r['pdf'], pdf_MF='', verdict='', cause=''))
rows.sort(key=lambda r: (r['role'] != 'candidate', r['operator'], -abs(float(r['tnds']) - float(r['bods_txc']))))
with open(out, 'w', newline='', encoding='utf-8') as f:
    w = csv.DictWriter(f, list(rows[0].keys())); w.writeheader(); w.writerows(rows)
nc = sum(r['role'] == 'candidate' for r in rows)
print(len(rows), 'routes:', nc, 'candidates,', len(rows) - nc, 'controls ->', out)
