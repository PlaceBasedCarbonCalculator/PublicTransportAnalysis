"""Python port of UK2GTFS `txc_overlap_plan()` (rule 4 of txc_filter_files),
run over the header scans of every TNDS region, with and without the proposed
fix: two files with the same CreationDateTime but different ServiceCodes are
siblings of one publication (one registration split across files), not
competing registrations, so they are never reconciled against each other.

Usage: python3 overlap_emulation.py v21   (needs txscan.py output in
$TNDS_WORK/tnds/scan/)
"""
import os, sys, pickle, re, datetime as dt, collections

WORK = os.environ.get('TNDS_WORK', '.')
REGIONS = ['EA', 'W', 'NE', 'Y', 'WM', 'EM', 'L', 'SW', 'NW', 'SE']


def norm_desc(x):
    x = re.sub(r'[^0-9A-Za-z]+', ' ', x or '').lower().split()
    return ' '.join(sorted(x))


def day(s):
    return dt.date.fromisoformat(s[:10]) if s else dt.date(2099, 12, 31)


def plan(meta, fix):
    """meta: list of dicts (file, noc, desc, lines, sc, start, end, created, rev).
    Returns set of dropped files and dict file -> (new_start, new_end)."""
    st = {m['file']: [m['start'], m['end']] for m in meta}
    drop = set()
    groups = collections.defaultdict(list)
    for m in meta:
        if not (m['desc'] or m['noc']):
            continue
        groups[(m['noc'], norm_desc(m['desc']), m['lines'])].append(m)
    for g in groups.values():
        if len(g) < 2:
            continue
        g.sort(key=lambda m: (st[m['file']][0], st[m['file']][1]))
        while True:
            live = [m for m in g if m['file'] not in drop]
            acted = False
            for a in range(len(live) - 1):
                for b in range(a + 1, len(live)):
                    i, j = live[a], live[b]
                    (si, ei), (sj, ej) = st[i['file']], st[j['file']]
                    if max(si, sj) > min(ei, ej):
                        continue
                    if fix and i['created'] == j['created'] and i['sc'] != j['sc']:
                        continue
                    if si == sj and ei == ej:
                        if i['created'] == j['created']:
                            older = i if i['rev'] < j['rev'] else j
                        else:
                            older = i if i['created'] < j['created'] else j
                        drop.add(older['file'])
                        acted = True
                    elif si == sj:
                        short, long_ = (i, j) if ei < ej else (j, i)
                        st[long_['file']][0] = st[short['file']][1] + dt.timedelta(1)
                        acted = True
                    else:
                        early, late = (i, j) if si < sj else (j, i)
                        if st[early['file']][1] <= st[late['file']][1]:
                            st[early['file']][1] = st[late['file']][0] - dt.timedelta(1)
                            acted = True
                    for m in (i, j):
                        if st[m['file']][0] > st[m['file']][1]:
                            drop.add(m['file'])
                    if acted:
                        break
                if acted:
                    break
            if not acted:
                break
    return drop, st


if __name__ == '__main__':
    ver = sys.argv[1] if len(sys.argv) > 1 else 'v21'
    W0, W1 = dt.date(2026, 7, 27), dt.date(2026, 8, 23)
    tot = collections.Counter()
    for reg in REGIONS:
        rows = pickle.load(open(f'{WORK}/tnds/scan/{ver}_{reg}.pkl', 'rb'))
        meta = [dict(file=r['file'], noc=(r['noc'] or [''])[0], desc=r['desc'] or '',
                     lines='\r'.join(r['line']), sc=tuple(r['sc']), start=day(r['opstart']),
                     end=day(r['opend']), created=r['created'] or '', rev=int(r['rev'] or 0), vj=r['vj'])
                for r in rows if r['sc']]
        by = {m['file']: m for m in meta}
        d0, s0 = plan(meta, fix=False)
        d1, s1 = plan(meta, fix=True)
        lost = d0 - d1
        # also files the bug truncates away from the analysis window
        cut = [f for f in by if f not in d0 and f not in d1 and
               (s0[f][0] > max(s1[f][0], W0) or s0[f][1] < min(s1[f][1], W1)) and s1[f][0] <= W1 and s1[f][1] >= W0]
        live = [f for f in lost if by[f]['start'] <= W1 and by[f]['end'] >= W0]
        n = sum(by[f]['vj'] for f in live)
        print(reg, 'dropped', len(d0), 'with fix', len(d1), 'siblings restored', len(lost),
              'live in window', len(live), 'VJ', n, 'sibling truncations restored', len(cut))
        for f in sorted(live)[:8]:
            print('   ', f, by[f]['lines'], by[f]['desc'][:40], by[f]['vj'])
        tot.update(dict(drop=len(d0), drop_fix=len(d1), restored=len(lost), live=len(live), vj=n, cut=len(cut)))
    print('ALL', dict(tot))
