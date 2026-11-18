"""What a change to txc_filter_files() changes: two filter runs side by side.

Takes two filter_actions.R outputs over the same snapshot (before, after) and
reports, for every file whose outcome differs:

 * newly dropped or newly truncated files - service the change would remove;
 * newly kept files, and for each, how many of its window journeys duplicate
   a journey of a file kept by both runs (same line, first stop, date, within
   TOL minutes) - the change putting a copy back rather than service;
 * per line touched, journeys a day over the window before and after, and the
   largest any single kept file runs, so a re-timed duplicate (which the
   3-minute match cannot see) shows up as a line whose volume roughly doubles.

usage: python -I compare_actions.py <TNDSV2.5 dir> <before.csv> <after.csv> <out prefix>
"""
import collections, csv, os, re, sys, zipfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lost_journeys import journeys, running, DATES, TOL
from txcday import _d
import datetime as dt


def load(p):
    rows = list(csv.DictReader(open(p, encoding='utf-8')))
    for a in rows:
        for k in ('start', 'end', 'new_start', 'new_end'):
            if a[k] == 'NA':
                a[k] = ''
    return {(a['region'], a['file']): a for a in rows}


def period(a):
    if a['status'] == 'dropped':
        return None
    s = _d(a['new_start'] or a['start'])
    e = _d(a['new_end'] or a['end']) or dt.date(2100, 1, 1)
    return s, e


def main(src, before_csv, after_csv, out):
    B, A = load(before_csv), load(after_csv)
    diff = [k for k in A if k in B and (A[k]['status'], A[k]['new_start'], A[k]['new_end']) !=
            (B[k]['status'], B[k]['new_start'], B[k]['new_end'])]
    print('files whose outcome changed:', len(diff))
    cnt = collections.Counter((B[k]['status'], A[k]['status']) for k in diff)
    for (b, a), n in sorted(cnt.items()):
        print(f'  {b:9s} -> {a:9s} {n}')
    rows, line_rows = [], []
    by_region = collections.defaultdict(list)
    for k in diff:
        by_region[k[0]].append(k[1])
    for region, files in sorted(by_region.items()):
        z = zipfile.ZipFile(os.path.join(src, region + '.zip'))
        names = [k[1] for k in A if k[0] == region]
        head, nocs = {}, {}
        for f in names:
            s = z.read(f).decode('utf-8', 'ignore')
            head[f] = frozenset(re.findall(r'<LineName>([^<]+)</LineName>', s))
            nocs[f] = frozenset(re.findall(r'<NationalOperatorCode>([^<]+)<', s) or
                                re.findall(r'<OperatorCode>([^<]+)<', s))
        cache = {}

        def parsed(f):
            if f not in cache:
                cache[f] = journeys(z.read(f))
            return cache[f]

        def runs_of(f, a):
            p = period(a)
            if p is None:
                return {}
            js, orgs = parsed(f)
            return running(js, orgs, *p)

        lines = set().union(*(head[f] for f in files))
        on_lines = [f for f in names if head[f] & lines]
        rb = {f: runs_of(f, B[(region, f)]) for f in on_lines}
        ra = {f: runs_of(f, A[(region, f)]) for f in on_lines}
        both = [f for f in on_lines if f not in files and B[(region, f)]['status'] != 'dropped']
        base = collections.defaultdict(lambda: collections.defaultdict(list))
        for f in both:
            for d, lst in ra[f].items():
                for line, fs, m in lst:
                    base[d][(line, fs)].append(m)
        for f in files:
            n_b = sum(len(v) for v in rb[f].values())
            n_a = sum(len(v) for v in ra[f].values())
            dup = 0
            if n_a > n_b:
                for d in DATES:
                    extra = collections.Counter(ra[f].get(d, [])) - collections.Counter(rb[f].get(d, []))
                    for (line, fs, m), c in extra.items():
                        if any(abs(x - m) <= TOL for x in base[d].get((line, fs), [])):
                            dup += c
            rows.append(dict(region=region, file=f, before=B[(region, f)]['status'],
                             after=A[(region, f)]['status'], lines=' '.join(sorted(head[f])),
                             journeys_before=n_b, journeys_after=n_a, gained=n_a - n_b,
                             gained_duplicating=dup))
        seen = set()
        for f in files:
            for ln in sorted(head[f]):
                key = (nocs[f], ln)
                if key in seen:
                    continue
                seen.add(key)
                fb = [g for g in on_lines if ln in head[g] and (nocs[g] & nocs[f] or not nocs[g] or not nocs[f])]
                cnt = lambda r, g: sum(1 for d in DATES for j in r[g].get(d, []) if j[0] == ln)
                tot_b = sum(cnt(rb, g) for g in fb)
                tot_a = sum(cnt(ra, g) for g in fb)
                single = max([cnt(ra, g) for g in fb] + [0])
                line_rows.append(dict(region=region, nocs=' '.join(sorted(nocs[f])), line=ln,
                                      before=tot_b, after=tot_a, largest_single_file=single,
                                      ratio_to_single=round(tot_a / single, 2) if single else ''))
        print(region, 'done', flush=True)
    for name, rr in (('_files.csv', rows), ('_lines.csv', line_rows)):
        if rr:
            with open(out + name, 'w', newline='', encoding='utf-8') as fh:
                w = csv.DictWriter(fh, fieldnames=list(rr[0].keys()))
                w.writeheader(); w.writerows(rr)
    g = sum(r['gained'] for r in rows if r['gained'] > 0)
    l = -sum(r['gained'] for r in rows if r['gained'] < 0)
    d = sum(r['gained_duplicating'] for r in rows)
    print(f'window journeys gained {g}, of which duplicating a kept journey {d}; removed {l}')


if __name__ == '__main__':
    main(*sys.argv[1:5])
