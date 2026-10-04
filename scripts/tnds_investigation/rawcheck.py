"""For every zone check where TNDS missed the timetable, count the raw TNDS
TransXChange (both versions) at the zone and set it against the pipeline's
TNDS count and the document."""
import json, collections, pickle, zipfile, sys, os
import pandas as pd
import txc_count as T

SP = os.environ.get('TNDS_WORK', '.') + '/'
REGIONS = ['EA', 'W', 'NE', 'Y', 'WM', 'EM', 'L', 'SW', 'NW', 'SE']
zs = collections.defaultdict(set)
for z, a, n, s, i, l in json.load(open(SP + 'geo/zone_stops.json')):
    zs[z].add(a)
W = T.window()
scan = {(v, r): pickle.load(open(f'{SP}tnds/scan/{v}_{r}.pkl', 'rb')) for v in ('v21', 'v25') for r in REGIONS}
zips = {}


def raw(ver, route, zone):
    """All files, in any region, publishing `route`; runs at the zone."""
    out = []
    for reg in REGIONS:
        for r in scan[(ver, reg)]:
            if route.upper() not in {x.upper() for x in r['line']}:
                continue
            key = (ver, reg)
            if key not in zips:
                zips[key] = zipfile.ZipFile(f'{SP}tnds/{ver}/{reg}.zip')
            fn = r['file'].split('/')[-1] if '/' not in r['file'] else r['file']
            try:
                b = zips[key].read(r['file'])
            except KeyError:
                continue
            per, det = T.count(b, zs[zone], W, keep={route, route.upper(), route.lower()})
            n = sum(per.values())
            if n:
                last = max(d for d in per)
                out.append(dict(region=reg, file=r['file'], noc='/'.join(r['noc']), start=r['opstart'],
                                end=r['opend'], runs=n, last=str(last),
                                wk=sum(per[d] for d in W[:7])))
    return out


if __name__ == '__main__':
    c = pd.read_pickle(SP + 'checks.pkl')
    c = c[c.reliable & c.basis.eq('counted at the zone')]
    bad = c[(c.t_ratio - 1).abs() > 0.15].copy()
    rows = []
    for _, x in bad.iterrows():
        rec = dict(zone=x.zone, locality=x.locality, area=x.area, route=x.route, doc=x.pdf, tnds=x.tnds,
                   bods=x.bods, t_ratio=x.t_ratio)
        for ver in ('v21', 'v25'):
            files = raw(ver, x.route, x.zone)
            rec[ver] = sum(f['runs'] for f in files)
            rec[ver + '_files'] = files
        rows.append(rec)
        print(x.area, x.route, x.zone, 'doc', x.pdf, 'pipeline', x.tnds, 'raw21', rec['v21'], 'raw25', rec['v25'],
              [(f['region'], f['file'][-40:], f['runs'], f['last']) for f in rec['v21_files']], flush=True)
    pickle.dump(rows, open(SP + 'rawcheck.pkl', 'wb'))
