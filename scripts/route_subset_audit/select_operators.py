"""Operators behind the filter-candidate routes, with their file counts.

Reads data/route_subset/seed_routes.csv and the two November indexes and
writes data/route_subset/operators.csv: one row per operator named on a
filter-candidate route, the gap it accounts for, its candidate lines, the
NOCs and operator names the index files it under, and how many files a
whole-operator extract would bring from each source.

usage: python -I select_operators.py [seed csv] [out csv]
"""
import csv, re, sys, collections

seed = sys.argv[1] if len(sys.argv) > 1 else 'data/route_subset/seed_routes.csv'
out = sys.argv[2] if len(sys.argv) > 2 else 'data/route_subset/operators.csv'
norm = lambda s: re.sub(r'[^a-z0-9]+', '', s.lower().replace('&', 'and'))

ops = collections.OrderedDict()
for r in csv.DictReader(open(seed, encoding='utf-8')):
    if r['filter_candidate'] != 'TRUE':
        continue
    first = re.split(r' ; | / ', r['operators'])[0]
    o = ops.setdefault(norm(first), dict(op=first, gap=0.0, n=0, lines=[], ease=r['ease'],
                                         names=set(), nocs=set(), pdf=0))
    o['gap'] += float(r['gap']); o['n'] += 1
    o['lines'].append(f"{r['line']}({r['tnds']}/{r['bods_txc']}/{r['bods_gtfs']})")
    o['pdf'] += bool(r['pdf'])
    for nm in re.split(r' ; | / ', r['operators']):
        o['names'].add(norm(nm))
    for c in r['nocs'].split('|'):
        if re.fullmatch(r'[A-Z]{2,5}', c):
            o['nocs'].add(c)

# index files per operator: a file belongs when any of its names or NOCs match
files = {'bods': collections.Counter(), 'tnds': collections.Counter()}
idx_nocs = collections.defaultdict(set)
for src in ('bods', 'tnds'):
    for r in csv.DictReader(open(f'data/txc_index/{src}_20261111.csv', encoding='utf-8')):
        names = {norm(x) for x in r['opname'].split(';') if x}
        nocs = {x.strip() for x in r['noc'].split(';') if x}
        for k, o in ops.items():
            if names & o['names'] or nocs & o['nocs']:
                files[src][k] += 1
                idx_nocs[k] |= nocs

rows = []
for k, o in ops.items():
    rows.append(dict(op=o['op'], gap=int(o['gap']), n_routes=o['n'], ease=o['ease'], pdf_routes=o['pdf'],
                     bods_files=files['bods'][k], tnds_files=files['tnds'][k],
                     nocs='|'.join(sorted(idx_nocs[k] | o['nocs'])),
                     names='|'.join(sorted(o['names'])), lines=' '.join(o['lines'])))
rows.sort(key=lambda r: -r['gap'])
with open(out, 'w', newline='', encoding='utf-8') as f:
    w = csv.DictWriter(f, list(rows[0].keys())); w.writeheader(); w.writerows(rows)
tb = tt = 0
for r in rows[:45]:
    tb += r['bods_files']; tt += r['tnds_files']
    print(f"{r['op'][:34]:34} gap={r['gap']:5} n={r['n_routes']:3} ease={r['ease']} pdf={r['pdf_routes']} "
          f"bods={r['bods_files']:5} tnds={r['tnds_files']:5} cum={tb}/{tt} nocs={r['nocs'][:40]}")
