"""Compare the TNDS TransXChange 2.1 and 2.5 snapshots file by file, from the
txscan.py header scans: what 2.5 removes, and whether what it removes is
still published in another region (a cross-boundary duplicate)."""
import os, pickle, collections

WORK = os.environ.get('TNDS_WORK', '.')
REGIONS = ['EA', 'W', 'NE', 'Y', 'WM', 'EM', 'L', 'SW', 'NW', 'SE']
scan = {(v, r): pickle.load(open(f'{WORK}/tnds/scan/{v}_{r}.pkl', 'rb'))
        for v in ('v21', 'v25') for r in REGIONS}


def name(f):
    return f.split('/')[-1]


# where each (operator, line) is published in 2.5
where25 = collections.defaultdict(set)
for r in REGIONS:
    for x in scan[('v25', r)]:
        for n in x['noc']:
            for l in x['line']:
                where25[(n, l.upper())].add(r)

tot = collections.Counter()
for r in REGIONS:
    a = {name(x['file']): x for x in scan[('v21', r)]}
    b = {name(x['file']): x for x in scan[('v25', r)]}
    gone, new = set(a) - set(b), set(b) - set(a)
    elsewhere = [f for f in gone if any(where25[(n, l.upper())] - {r}
                                        for n in a[f]['noc'] for l in a[f]['line'])]
    vj = sum(a[f]['vj'] for f in gone)
    changed_vj = sum(1 for f in set(a) & set(b) if a[f]['vj'] != b[f]['vj'])
    print(f'{r}: 2.1 {len(a)} files, 2.5 {len(b)}; removed {len(gone)} ({vj} VJ), '
          f'of which still published in another region {len(elsewhere)}; new {len(new)}; '
          f'same name, different VJ count {changed_vj}')
    for f in sorted(gone)[:5]:
        print('    -', f, a[f]['noc'], a[f]['line'][:4], a[f]['vj'])
    tot.update(dict(v21=len(a), v25=len(b), removed=len(gone), vj=vj, elsewhere=len(elsewhere), new=len(new)))
print('ALL', dict(tot))
