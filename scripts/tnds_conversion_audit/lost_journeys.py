"""Journeys removed by txc_filter_files(), and whether anything replaces them.

For every file the filter dropped or truncated (filter_actions.R), each
journey it would have run on a window date under its published period but no
longer runs under the filtered one is looked up among the files the filter
kept, under their filtered periods: same operator, same line, same first
stop, departing within TOL minutes on the same date. Found, it was superseded
and removing it was right. Not found, the filter deleted service.

usage: python -I lost_journeys.py <snapshot TNDSV2.5 dir> <filter_actions.csv> <out prefix>
Writes <out>_files.csv (per affected file) and prints a summary.
"""
import collections, csv, datetime as dt, os, re, sys, zipfile
import xml.etree.ElementTree as ET
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from txcday import NS, Profile, runs, _d

TOL = 3
DATES = [dt.date(2026, 7, 27) + dt.timedelta(days=i) for i in range(14)]


def journeys(xml):
    """(noc set, line, first stop, departure minute, profile) per journey,
    and the organisations the profiles refer to."""
    root = ET.fromstring(xml)
    nocs = frozenset(x.text for x in root.iter('{%s}NationalOperatorCode' % NS['t']))
    orgs = {}
    for so in root.findall('.//t:ServicedOrganisations/t:ServicedOrganisation', NS):
        code = so.findtext('t:OrganisationCode', None, NS)
        rng = lambda p: [(_d(r.findtext('t:StartDate', None, NS)),
                          _d(r.findtext('t:EndDate', None, NS)) or _d(r.findtext('t:StartDate', None, NS)))
                         for r in so.findall(p, NS)]
        orgs[code] = {'WorkingDays': rng('t:WorkingDays/t:DateRange'),
                      'Holidays': rng('t:Holidays/t:DateRange')}
    first = {}
    for jps in root.findall('.//t:JourneyPatternSections/t:JourneyPatternSection', NS):
        tl = jps.find('t:JourneyPatternTimingLink/t:From/t:StopPointRef', NS)
        first[jps.get('id')] = tl.text if tl is not None else None
    out = []
    for svc in root.findall('.//t:Services/t:Service', NS):
        sprof = Profile(svc.find('t:OperatingProfile', NS))
        lines = {l.get('id'): l.findtext('t:LineName', None, NS)
                 for l in svc.findall('t:Lines/t:Line', NS)}
        jp = {}
        for p in svc.findall('t:StandardService/t:JourneyPattern', NS):
            ref = p.find('t:JourneyPatternSectionRefs', NS)
            jp[p.get('id')] = (p.find('t:OperatingProfile', NS),
                               first.get(ref.text) if ref is not None else None)
        scode = svc.findtext('t:ServiceCode', None, NS)
        for vj in root.findall('.//t:VehicleJourneys/t:VehicleJourney', NS):
            if vj.findtext('t:ServiceRef', None, NS) != scode:
                continue
            jop, fstop = jp.get(vj.findtext('t:JourneyPatternRef', None, NS), (None, None))
            op = vj.find('t:OperatingProfile', NS)
            prof = Profile(op) if op is not None else (Profile(jop) if jop is not None else sprof)
            dep = vj.findtext('t:DepartureTime', '00:00:00', NS)
            h, m = int(dep[:2]), int(dep[3:5])
            out.append((nocs, lines.get(vj.findtext('t:LineRef', None, NS), '?'), fstop, h * 60 + m, prof))
    return out, orgs


def running(js, orgs, start, end):
    """{date: [(line, first stop, minute)]} for journeys in the period."""
    r = collections.defaultdict(list)
    for nocs, line, fs, mins, prof in js:
        for d in DATES:
            if start <= d <= end and runs(prof, d, orgs, {}):
                r[d].append((line, fs, mins))
    return r


def main(src, actions_csv, out):
    acts = list(csv.DictReader(open(actions_csv, encoding='utf-8')))
    for a in acts:                       # R writes missing dates as "NA"
        for k in ('start', 'end', 'new_start', 'new_end'):
            if a[k] == 'NA':
                a[k] = ''
    by_region = collections.defaultdict(list)
    for a in acts:
        by_region[a['region']].append(a)
    rows, tot = [], collections.Counter()
    for region, aa in sorted(by_region.items()):
        affected = [a for a in aa if a['status'] in ('dropped', 'truncated')]
        if not affected:
            continue
        z = zipfile.ZipFile(os.path.join(src, region + '.zip'))
        # cheap header pass: operator and lines of every file
        head = {}
        for a in aa:
            s = z.read(a['file']).decode('utf-8', 'ignore')
            head[a['file']] = (frozenset(re.findall(r'<NationalOperatorCode>([^<]+)<', s)),
                               frozenset(re.findall(r'<LineName>([^<]+)</LineName>', s)))
        want = set()
        for a in affected:
            n, l = head[a['file']]
            # Same line; the operator only where both files name one. Some
            # regions' files carry no NationalOperatorCode at all, and the
            # first stop and departure minute are specific enough without it.
            want |= {b['file'] for b in aa if b['status'] != 'dropped'
                     and head[b['file']][1] & l
                     and (not n or not head[b['file']][0] or head[b['file']][0] & n)}
        cache = {}

        def parsed(f):
            if f not in cache:
                cache[f] = journeys(z.read(f))
            return cache[f]

        def period(a, new):
            s = _d(a['new_start'] if new and a['new_start'] else a['start'])
            e = _d(a['new_end'] if new and a['new_end'] else a['end']) or dt.date(2100, 1, 1)
            return s, e

        kept_runs = collections.defaultdict(lambda: collections.defaultdict(list))
        for b in aa:
            if b['file'] in want:
                js, orgs = parsed(b['file'])
                s, e = period(b, True)
                for d, lst in running(js, orgs, s, e).items():
                    for line, fs, mins in lst:
                        kept_runs[d][(line, fs)].append(mins)
        for a in affected:
            js, orgs = parsed(a['file'])
            before = running(js, orgs, *period(a, False))
            after = (running(js, orgs, *period(a, True)) if a['status'] == 'truncated'
                     else collections.defaultdict(list))
            lost = replaced = 0
            for d in DATES:
                left = collections.Counter(after[d])
                for j in before[d]:
                    if left[j] > 0:
                        left[j] -= 1
                        continue
                    line, fs, mins = j
                    if any(abs(m - mins) <= TOL for m in kept_runs[d].get((line, fs), [])):
                        replaced += 1
                    else:
                        lost += 1
            nocs, lines = head[a['file']]
            # what the kept files still run on this file's lines in the window:
            # a line that keeps most of its volume was re-timed, not lost
            kept_line = sum(len(v) for d in DATES for (ln, fs), v in kept_runs[d].items()
                            if ln in lines)
            before_n = sum(len(before[d]) for d in DATES)
            rows.append(dict(kept_same_line=kept_line, published=before_n,
                             sc=re.findall(r'<ServiceCode>([^<]+)<',
                                           z.read(a['file']).decode('utf-8', 'ignore'))[:1][0]
                             if re.search(r'<ServiceCode>', z.read(a['file']).decode('utf-8', 'ignore')) else '',
                             region=region, file=a['file'], status=a['status'],
                             nocs=' '.join(sorted(nocs)), lines=' '.join(sorted(lines)),
                             start=a['start'], end=a['end'], new_start=a['new_start'],
                             new_end=a['new_end'], removed=lost + replaced,
                             replaced=replaced, lost=lost))
            tot[(region, 'removed')] += lost + replaced
            tot[(region, 'lost')] += lost
        print(region, 'affected files', len(affected), 'journeys removed in window',
              tot[(region, 'removed')], 'of which not replaced', tot[(region, 'lost')], flush=True)
    with open(out + '_files.csv', 'w', newline='', encoding='utf-8') as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        w.writeheader(); w.writerows(rows)
    print('TOTAL removed', sum(r['removed'] for r in rows), 'not replaced', sum(r['lost'] for r in rows))


if __name__ == '__main__':
    main(*sys.argv[1:4])
