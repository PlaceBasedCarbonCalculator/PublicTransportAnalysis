import paths
import json, re, time, urllib.request, collections
import pandas as pd
import gen_report as G
c = pd.read_pickle(paths.WORK + 'checks.pkl')
s = pd.read_pickle(paths.WORK + 'services.pkl'); s['name'] = s.name.astype(str)
s['absgap'] = (s.tnds - s.bods_gtfs).abs()
r = s.groupby(['zone_id', 'locality', 'name']).agg(t=('tnds', 'sum'), b=('bods_gtfs', 'sum'), g=('absgap', 'sum'),
                                                   ln=('long_name', 'first')).reset_index()
done = set(zip(c[c.reliable].zone, c[c.reliable].route))
area = lambda z: G.AREA.get(z)
have = collections.defaultdict(set)
for _, x in c.iterrows():
    have[area(x.zone)].add(x.route.upper())
r = r[(r.g >= 1000)]
r = r[~r.apply(lambda x: (x.zone_id, x['name']) in done, axis=1)]
r = r[~r.apply(lambda x: area(x.zone_id) is not None and x['name'].upper() in have[area(x.zone_id)], axis=1)]
zs = collections.defaultdict(list)
for z, a, n, st, i, l in json.load(open(paths.WORK + 'geo/zone_stops.json')):
    zs[z].append(a)

def get(u):
    for k in range(3):
        try:
            return urllib.request.urlopen(urllib.request.Request(u, headers={'User-Agent': 'Mozilla/5.0'}), timeout=30).read().decode('utf8', 'ignore')
        except Exception:
            time.sleep(2)
    return ''

lines = {}
for z in sorted(set(r.zone_id)):
    m = collections.defaultdict(set)
    for a in zs[z][:25]:
        h = get('https://bustimes.org/stops/' + a)
        for slug, ln in re.findall(r'href="/services/([^"]+)">([^<]+)</a>', h):
            m[ln.strip().upper()].add(slug)
    lines[z] = m
out = []
svc_cache = {}
for _, x in r.iterrows():
    slugs = sorted(lines.get(x.zone_id, {}).get(x['name'].upper(), []))
    found = []
    for sl in slugs[:3]:
        if sl not in svc_cache:
            h = get('https://bustimes.org/services/' + sl)
            t = re.search(r'<title>([^<]+)', h)
            svc_cache[sl] = t.group(1).replace(' – Bus Times', '') if t else ''
        found.append((sl, svc_cache[sl]))
    out.append(dict(zone=x.zone_id, locality=x.locality, route=x['name'], tnds=x.t, bods=x.b, gap=x.g,
                    long_name=x.ln, services=found))
    print(x.zone_id, x.locality, x['name'], found, flush=True)
json.dump(out, open(paths.WORK + 'missing.json', 'w'))

# Each operator's own website, as its bustimes operator page gives it.
ops = {'_svc': {}}
for sl in sorted({sl for x in out for sl, t in x['services']}):
    h = get('https://bustimes.org/services/' + sl)
    o = re.search(r'href="/operators/([^"]+)">([^<]+)</a>', h)
    if not o:
        continue
    ops['_svc'][sl] = o.group(1)
    if o.group(1) not in ops:
        oh = get('https://bustimes.org/operators/' + o.group(1))
        w = [u for u in re.findall(r'href="(https?://[^"]+)"[^>]*rel="nofollow"', oh)
             if not re.search(r'bustimes|google|facebook|twitter|x\.com|instagram|open-data|app', u)]
        ops[o.group(1)] = (o.group(2), w[:2])
json.dump(ops, open(paths.WORK + 'ops.json', 'w'))
