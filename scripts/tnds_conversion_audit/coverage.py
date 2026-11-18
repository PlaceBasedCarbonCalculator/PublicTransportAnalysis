"""Operator + line coverage of two raw sources over a window.

A line is live when some file's operating period overlaps the window.
Prints, by TNDS region (for lines only in TNDS) and by NOC, what each source
has that the other lacks, with raw vehicle-journey counts as a weight.

usage: python -I coverage.py <tnds index> <bods index> <win0> <win1>
"""
import csv, sys, collections
tn, bo, W0, W1 = sys.argv[1:5]
def load(p):
    d = collections.defaultdict(lambda: [0, set(), set()])
    for r in csv.DictReader(open(p, encoding='utf-8')):
        if not r['noc'] or r['mode'].startswith('ERROR'): continue
        if (r['start'] or '0000') > W1 or (r['end'] or '9999') < W0: continue
        for noc in r['noc'].split(';'):
            for ln in r['lines'].split(';'):
                e = d[(noc, ln.upper())]
                e[0] += int(r['n_vj'] or 0); e[1].add(r['container'].split('!')[0]); e[2].add(r['mode'])
    return d
T, B = load(tn), load(bo)
onlyT = {k: v for k, v in T.items() if k not in B}
onlyB = {k: v for k, v in B.items() if k not in T}
print('live lines: TNDS %d, BODS %d, both %d, TNDS only %d, BODS only %d' % (len(T), len(B), len(set(T) & set(B)), len(onlyT), len(onlyB)))
reg = collections.Counter(); regvj = collections.Counter()
for k, v in onlyT.items():
    for c in v[1]: reg[c] += 1; regvj[c] += v[0]
print('TNDS-only lines by region:', ', '.join(f'{c} {n} ({regvj[c]} vj)' for c, n in reg.most_common()))
mode = collections.Counter(m for v in onlyT.values() for m in v[2])
print('TNDS-only by mode:', dict(mode))
mode = collections.Counter(m for v in onlyB.values() for m in v[2])
print('BODS-only by mode:', dict(mode))
def top(D, n=20):
    c = collections.Counter(); vj = collections.Counter()
    for (noc, ln), v in D.items(): c[noc] += 1; vj[noc] += v[0]
    return ', '.join(f'{k} {c[k]}/{vj[k]}' for k, _ in vj.most_common(n))
print('TNDS-only top NOCs (lines/vj):', top(onlyT))
print('BODS-only top NOCs (lines/vj):', top(onlyB))
