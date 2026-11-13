"""Which txc_filter_files() rule is behind each journey it removes.

Reads lost_journeys.py's per-file table and the raw headers, and puts every
dropped or truncated file in one class by the kept file it deferred to:

  line-blind supersession  a kept file shares its operator and ServiceCode
                           but none of its lines (rule 2 keeps the latest
                           start per ServiceCode, not per line)
  same-code duplicate      a kept file shares operator, ServiceCode and
                           lines (rules 1-2: a repeated upload)
  other-code overlap       no kept file shares its ServiceCode (rule 4:
                           overlapping registrations of "one service")

and, separately, whether the removal was a re-timing or a loss: a line whose
kept files still run at least 80% of the journeys this file published there
in the window has been re-timed, however far the times moved.

usage: python -I classify_losses.py <TNDSV2.5 dir> <filter_actions.csv> <lost_files.csv>
"""
import collections, csv, re, sys, zipfile


def header(z, f):
    s = z.read(f).decode('utf-8', 'ignore')
    return (frozenset(re.findall(r'<NationalOperatorCode>([^<]+)<', s)),
            (re.findall(r'<ServiceCode>([^<]+)<', s) or [''])[0],
            frozenset(re.findall(r'<LineName>([^<]+)</LineName>', s)))


def main(src, actions_csv, lost_csv):
    acts = list(csv.DictReader(open(actions_csv, encoding='utf-8')))
    lost = list(csv.DictReader(open(lost_csv, encoding='utf-8')))
    kept = collections.defaultdict(list)
    for a in acts:
        if a['status'] != 'dropped':
            kept[a['region']].append(a['file'])
    zips, heads = {}, {}
    for r in {x['region'] for x in lost}:
        zips[r] = zipfile.ZipFile('%s/%s.zip' % (src, r))
        heads[r] = {f: header(zips[r], f) for f in kept[r]}
    tab = collections.defaultdict(lambda: collections.Counter())
    out = []
    for x in lost:
        r = x['region']
        noc, sc, lines = header(zips[r], x['file'])
        same_code = [h for f, h in heads[r].items() if h[1] == sc and (h[0] == noc or not noc)]
        if x['status'] == 'truncated':
            cls = 'truncated (rule 4)'
        elif same_code and not any(h[2] & lines for h in same_code):
            cls = 'line-blind supersession (rule 2)'
        elif same_code:
            cls = 'same-code duplicate (rules 1-2)'
        else:
            cls = 'other-code overlap (rule 4)'
        pub, kl = int(x['published']), int(x['kept_same_line'])
        retimed = int(x['lost']) > 0 and kl >= 0.8 * pub
        kind = 'nothing lost' if int(x['lost']) == 0 else ('re-timed' if retimed else 'lost')
        t = tab[cls]
        t['files'] += 1; t['removed'] += int(x['removed']); t['unmatched'] += int(x['lost'])
        t['lost_files'] += kind == 'lost'
        t['lost_journeys'] += int(x['lost']) if kind == 'lost' else 0
        out.append(dict(x, cls=cls, kind=kind))
    print('%-34s %6s %9s %10s %11s %14s' % ('class', 'files', 'removed', 'unmatched',
                                          'lost files', 'lost journeys'))
    for cls, t in sorted(tab.items()):
        print('%-34s %6d %9d %10d %11d %14d' % (cls, t['files'], t['removed'], t['unmatched'],
                                              t['lost_files'], t['lost_journeys']))
    with open(lost_csv.replace('.csv', '_classified.csv'), 'w', newline='', encoding='utf-8') as f:
        w = csv.DictWriter(f, fieldnames=list(out[0].keys()))
        w.writeheader(); w.writerows(out)


if __name__ == '__main__':
    main(*sys.argv[1:4])
