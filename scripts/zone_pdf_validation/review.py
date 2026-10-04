import json, pickle, os, re, collections, sys
import pandas as pd
import ttread as T
from registry import docs, SP

svc = pd.read_pickle(SP + 'services.pkl')
svc['name'] = svc['name'].astype(str)
runs = svc.groupby(['zone_id', 'name'])[['tnds', 'bods_gtfs']].sum().reset_index()
zs = collections.defaultdict(set)
for z, a, n, s, i, l in json.load(open(SP + 'geo/zone_stops.json')):
    zs[z].add(n)

def norm(s):
    s = s.lower().replace('&', ' and ').replace('ﬁ', 'fi').replace("'", '')
    s = re.sub(r'\bst\b\.?', 'street', s)
    s = re.sub(r'\brd\b', 'road', s)
    s = re.sub(r'[^a-z0-9 ]', ' ', s)
    return ' '.join(s.split())

GENERIC = {'bus station', 'railway station', 'station', 'high street', 'market place', 'hospital',
           'church street', 'new street', 'king street', 'castle street', 'queen street', 'bus garage',
           'arrival stand', 'library', 'pavilion', 'leisure', 'the centre', 'health centre', 'broadway'}

CACHE = SP + 'parsed7/'
os.makedirs(CACHE, exist_ok=True)

def blocks_for(path, day):
    key = CACHE + re.sub(r'\W', '_', path) + '_' + day + '.pkl'
    if os.path.exists(key):
        return pickle.load(open(key, 'rb'))
    b = T.parse(path, day_override=None if day == '*' else day)
    for x in b:   # drop pdfplumber objects we don't need
        pass
    pickle.dump(b, open(key, 'wb'))
    return b

def labels(blocks):
    return sorted({r['label'] for b in blocks for r in b['rows'] if r['label']})

if __name__ == '__main__':
    out = []
    for d in docs:
        rset = {r.upper() for r in d['routes']}
        sel = runs[runs.zone_id.isin(d['zones']) & runs.name.str.upper().isin(rset)]
        if sel.empty:
            continue
        labs = set()
        for day, f in d['files'].items():
            labs.update(labels(blocks_for(f, day)))
        for z in sorted(set(sel.zone_id)):
            stops = {norm(s) for s in zs[z]}
            cand = []
            for l in labs:
                nl = norm(l)
                for s in stops:
                    if len(s) < 4:
                        continue
                    if re.search(r'\b' + re.escape(s) + r'\b', nl):
                        cand.append((l, s, s in GENERIC))
                        break
            out.append(dict(doc=d['key'], zone=z, routes=list(rset), cand=cand))
            print(d['key'], z, '|', '; '.join(f"{l}{' [G]' if g else ''}" for l, s, g in cand)[:400])
    json.dump(out, open(SP + 'review.json', 'w'), default=list)
