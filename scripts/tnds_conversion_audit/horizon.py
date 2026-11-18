"""Why services run out early in TNDS and not in BODS.

For every operator + line in both raw sources, the last date any file
covers (an open-ended file covers forever), set against the window. A line
"runs out" in a source when its last covered date falls inside the window.

usage: python -I horizon.py <tnds index csv> <bods index csv> <win0> <win1>
"""
import csv, sys, collections
tn, bo, W0, W1 = sys.argv[1:5]
def load(p):
    d = collections.defaultdict(list)
    for r in csv.DictReader(open(p, encoding='utf-8')):
        if not r['noc'] or r['mode'].startswith('ERROR'):
            continue
        for noc in r['noc'].split(';'):
            for ln in r['lines'].split(';'):
                d[(noc, ln.upper())].append(r)
    return d
T, B = load(tn), load(bo)
def last(rows):
    live = [r for r in rows if (r['start'] or '0') <= W1]
    if not live: return None
    return max((r['end'] or '9999-12-31') for r in live)
def first_created(rows):
    return max((r['created'] or '')[:10] for r in rows)
both = set(T) & set(B)
cnt = collections.Counter(); ex = collections.defaultdict(list)
lag = []
for k in both:
    lt, lb = last(T[k]), last(B[k])
    if lt is None or lb is None: continue
    if lt < W0 and lb < W0: continue
    t_out = W0 <= lt < W1; b_out = W0 <= lb < W1
    t_open = sum(1 for r in T[k] if not r['end']); b_open = sum(1 for r in B[k] if not r['end'])
    cls = ('TNDS runs out' if t_out else 'TNDS ok') + ' / ' + ('BODS runs out' if b_out else 'BODS ok')
    cnt[cls] += 1
    if t_out and not b_out:
        ex[k[0]].append((k[1], lt, lb, first_created(T[k]), first_created(B[k])))
        lag.append((k, lt, lb))
print('lines in both sources, live in window:', sum(cnt.values()))
for c, n in cnt.most_common(): print(f'  {c}: {n}')
print('\nTNDS runs out, BODS does not - by operator (lines, example):')
for noc, v in sorted(ex.items(), key=lambda x: -len(x[1]))[:25]:
    v.sort()
    print(f'  {noc}: {len(v)}  e.g. {v[0][0]} TNDS ends {v[0][1]} (newest file created {v[0][3]}), BODS to {v[0][2]} (newest {v[0][4]})')
# open-ended share
def share_open(D):
    n = o = 0
    for rows in D.values():
        for r in rows:
            n += 1; o += (not r['end'])
    return o / max(n, 1)
print('\nshare of (line, file) rows open-ended: TNDS %.1f%%, BODS %.1f%%' % (100*share_open(T), 100*share_open(B)))
