"""Join the manifest, one or more harness runs, the BODS GTFS counts and the
timetable readings into one table per route.

Routes are linked to harness output by line and reference stop (the stop
ids are NaPTAN codes in every feed), so operator naming differences between
feeds do not matter. For each run the table carries trips on the day in
TNDS and BODS TXC for the route and departures at the reference stop.

usage: python -I compare_runs.py <out csv> label=<run prefix> [label=<run prefix> ...]
  e.g. compare_runs.py data/route_subset/comparison.csv r6b=runs/r6b r7d=runs/r7d
"""
import collections, csv, os, re, sys

out = sys.argv[1]
runs = [kv.split('=', 1) for kv in sys.argv[2:]]
manifest = list(csv.DictReader(open('data/route_subset/routes.csv', encoding='utf-8')))
norm_line = lambda s: re.sub(r'\s+', '', s).upper()

pdf = {}
p = 'data/route_subset/pdf_counts.csv'
if os.path.exists(p):
    for r in csv.DictReader(open(p, encoding='utf-8')):
        pdf[(r['operator'].lower(), r['line'])] = r

norm = lambda s: re.sub(r'[^a-z0-9]+', '', (s or '').lower().replace('&', 'and'))
stops_by_agency = {}

def load_run(prefix, lab):
    stops = collections.defaultdict(lambda: collections.defaultdict(int))   # (line, stop) -> src -> deps
    agencies = collections.defaultdict(set)
    sba = stops_by_agency.setdefault(lab, collections.defaultdict(int))
    for r in csv.DictReader(open(prefix + '_stops.csv', encoding='utf-8')):
        # ATCO codes are case-insensitive: BODS writes Hodgsons' 13004000A
        # as 13004000a, and an exact match found no departures there
        r['stop_id'] = r['stop_id'].upper()
        stops[(norm_line(r['line']), r['stop_id'])][r['src']] += int(r['deps'])
        agencies[(norm_line(r['line']), r['stop_id'], r['src'])].add(r['agency'])
        sba[(r['agency'], norm_line(r['line']), r['stop_id'], r['src'])] += int(r['deps'])
    routes = collections.defaultdict(lambda: collections.defaultdict(int))  # (agency, line) -> src -> trips
    for r in csv.DictReader(open(prefix + '_routes.csv', encoding='utf-8')):
        routes[(r['agency'], norm_line(r['line']))][r['src']] += int(r['trips'])
    return stops, agencies, routes

loaded = [(lab, load_run(pre, lab)) for lab, pre in runs]
rows = []
for m in manifest:
    row = dict(m)
    key = (m['operator'].lower(), m['line'])
    d = pdf.get(key)
    row['pdf_MF'] = d['MF'] if d else ''
    row['pdf_edition'] = d['edition'] if d else ''
    # only the route's own operators: other operators can run the same
    # number past the same stop (Phil Anslow's and Stagecoach's route 1)
    names = {norm(x) for x in re.split(r' ; | / ', m.get('operators') or m['operator'])}
    for lab, (stops, agencies, routes) in loaded:
        for src in ('tnds', 'bods'):
            ref = m['ref_stop'].upper()
            ags = agencies.get((m['line'], ref, src), set())
            mine = {a for a in ags if norm(a) in names} or ags
            row[f'{lab}_ref_{src}'] = sum(stops_by_agency[lab].get((a, m['line'], ref, src), 0) for a in mine)
            row[f'{lab}_{src}'] = sum(routes[(a, m['line'])].get(src, 0) for a in mine)
    # verdict against the document, at the reference stop, for the last run
    if d and d['MF'] and loaded:
        lab = loaded[-1][0]
        ref = float(d['MF'])
        ok = lambda v: abs(v - ref) <= 0.15 * max(ref, 1)
        t, b = row[f'{lab}_ref_tnds'], row[f'{lab}_ref_bods']
        row['auto_verdict'] = ('tnds ok' if ok(t) else 'tnds ' + ('low' if t < ref else 'high')) + '; ' + \
                              ('bods ok' if ok(b) else 'bods ' + ('low' if b < ref else 'high'))
    else:
        row['auto_verdict'] = ''
    rows.append(row)
with open(out, 'w', newline='', encoding='utf-8') as f:
    w = csv.DictWriter(f, list(rows[0].keys())); w.writeheader(); w.writerows(rows)
print(len(rows), 'routes ->', out)
# summary of candidates: how the two-source gap moved between the first and last run
if len(loaded) >= 1:
    cands = [r for r in rows if r['role'] == 'candidate']
    for lab, _ in loaded:
        agree = sum(1 for r in cands if abs(r[f'{lab}_ref_tnds'] - r[f'{lab}_ref_bods']) <= 0.15 * max(r[f'{lab}_ref_tnds'], r[f'{lab}_ref_bods'], 1))
        print(f'{lab}: candidates where TNDS and BODS TXC agree at the reference stop: {agree}/{len(cands)}')
    for r in cands:
        print(f"{r['operator'][:22]:22} {r['line']:5} seed {r['ref_tnds']:>4}/{r['ref_bods_txc']:>4}/{r['ref_bods_gtfs']:>4} "
              + ' '.join(f"{lab} {r[f'{lab}_ref_tnds']:>4}/{r[f'{lab}_ref_bods']:>4}" for lab, _ in loaded)
              + f"  pdf {r['pdf_MF']:>4} {r['auto_verdict']}")
