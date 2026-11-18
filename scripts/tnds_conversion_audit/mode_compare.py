"""Route types for the same services in two GTFS feeds.

Every route either feed gives a type other than bus (3) is looked up in the
other feed by the stops it serves: the other feed's route sharing the most
stops with it (at least half of the smaller stop set). Prints each pair with
both types, so a correct service filed under the wrong mode in one feed shows
up as a disagreement. Reads only routes, trips, stops-per-trip (first pass
over stop_times, one sampled trip per route).

usage: python -I mode_compare.py <feed A zip> <label A> <feed B zip> <label B> <out.csv>
"""
import csv, io, sys, zipfile, collections

TYPES = {'0': 'tram', '1': 'metro', '2': 'rail', '3': 'bus', '4': 'ferry', '5': 'cable tram',
         '6': 'gondola', '7': 'funicular', '200': 'coach', '11': 'trolleybus', '12': 'monorail'}


def simple(t):
    t = int(float(t))
    if 100 <= t < 200: return 'rail'
    if 200 <= t < 300: return 'coach'
    if 400 <= t < 500: return 'metro'
    if 700 <= t < 800: return 'bus'
    if 900 <= t < 1000: return 'tram'
    if t in (1000, 1200): return 'ferry'
    if t == 1300: return 'gondola'
    if t == 1400: return 'funicular'
    return TYPES.get(str(t), str(t))


def read(path):
    z = zipfile.ZipFile(path)
    rd = lambda n: csv.DictReader(io.TextIOWrapper(z.open(n), 'utf-8-sig'))
    ag = {a.get('agency_id', ''): a['agency_name'] for a in rd('agency.txt')}
    routes = {r['route_id']: dict(type=simple(r['route_type']), name=r.get('route_short_name', '') or r.get('route_long_name', ''),
                                  agency=ag.get(r.get('agency_id', ''), r.get('agency_id', '')))
              for r in rd('routes.txt')}
    trip_route = {}
    for t in rd('trips.txt'):
        trip_route[t['trip_id']] = t['route_id']
    stops = collections.defaultdict(set)
    ntrips = collections.Counter(trip_route.values())
    for st in rd('stop_times.txt'):
        r = trip_route.get(st['trip_id'])
        if r is not None:
            stops[r].add(st['stop_id'])
    return routes, stops, ntrips


def main(pa, la, pb, lb, out):
    A, B = read(pa), read(pb)
    idx = {}
    for lab, (routes, stops, _) in ((la, A), (lb, B)):
        inv = collections.defaultdict(set)
        for r, ss in stops.items():
            for s in ss:
                inv[s].add(r)
        idx[lab] = inv
    rows = []
    for (lab, (routes, stops, nt)), (olab, (oroutes, ostops, ont)) in (((la, A), (lb, B)), ((lb, B), (la, A))):
        for r, info in routes.items():
            if info['type'] == 'bus' or not stops.get(r):
                continue
            cand = collections.Counter()
            for s in stops[r]:
                for o in idx[olab].get(s, ()):
                    cand[o] += 1
            best = None
            for o, n in cand.most_common(5):
                if n >= 0.5 * min(len(stops[r]), len(ostops[o])):
                    best = (o, n); break
            o = oroutes.get(best[0]) if best else None
            rows.append({'feed': lab, 'agency': info['agency'], 'route': info['name'], 'type': info['type'],
                         'trips': nt[r], 'stops': len(stops[r]),
                         'other_agency': o['agency'] if o else '', 'other_route': o['name'] if o else '',
                         'other_type': o['type'] if o else 'NOT FOUND',
                         'shared_stops': best[1] if best else 0})
    with open(out, 'w', newline='', encoding='utf-8') as f:
        w = csv.DictWriter(f, list(rows[0])); w.writeheader(); w.writerows(rows)
    c = collections.Counter((r['feed'], r['type'], r['other_type']) for r in rows)
    for k, n in sorted(c.items()):
        print(k, n)


if __name__ == '__main__':
    main(*sys.argv[1:6])
