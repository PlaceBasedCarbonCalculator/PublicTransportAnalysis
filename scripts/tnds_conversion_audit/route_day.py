"""Trips a GTFS feed runs on one date, by agency and route, for chosen routes.

usage: python -I route_day.py <gtfs zip> <YYYYMMDD> <agency regex> <route,route,...>
"""
import csv, io, re, sys, zipfile, collections, datetime as dt

path, day, agx, rts = sys.argv[1], sys.argv[2], re.compile(sys.argv[3], re.I), set(sys.argv[4].upper().split(','))
z = zipfile.ZipFile(path)
rd = lambda n: csv.DictReader(io.TextIOWrapper(z.open(n), 'utf-8-sig'))
ag = {a.get('agency_id', ''): a['agency_name'] for a in rd('agency.txt')}
routes = {r['route_id']: (ag.get(r.get('agency_id', ''), '?'), r['route_short_name'].upper())
          for r in rd('routes.txt') if r['route_short_name'].upper() in rts and agx.search(ag.get(r.get('agency_id', ''), ''))}
d = dt.datetime.strptime(day, '%Y%m%d').date()
wd = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'][d.weekday()]
on = set()
if 'calendar.txt' in z.namelist():
    for c in rd('calendar.txt'):
        if c['start_date'] <= day <= c['end_date'] and c[wd] == '1':
            on.add(c['service_id'])
if 'calendar_dates.txt' in z.namelist():
    for c in rd('calendar_dates.txt'):
        if c['date'] == day:
            (on.add if c['exception_type'] == '1' else on.discard)(c['service_id'])
cnt = collections.Counter(); svc = collections.defaultdict(collections.Counter)
for t in rd('trips.txt'):
    if t['route_id'] in routes and t['service_id'] in on:
        cnt[routes[t['route_id']]] += 1
        svc[routes[t['route_id']]][t['service_id']] += 1
for k in sorted(cnt):
    print(k, cnt[k], 'services:', dict(svc[k].most_common(6)))
