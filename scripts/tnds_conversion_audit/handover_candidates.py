"""Extract the BODS files the operator-handover rule could act on.

From a txc_index.py index of a BODS archive: files live around a date, in
groups that share their line names and hold more than one operator, where
one operator's file starts later than another's and the earlier is still
running then. Writes those files to a directory, one sub-directory per
line group, for handover_check.R.

usage: python -I handover_candidates.py <bods index csv> <bods archive zip> <date> <out dir>
"""
import csv, io, os, sys, zipfile, collections

idx, arch, day, out = sys.argv[1:5]
rows = [r for r in csv.DictReader(open(idx, encoding='utf-8'))
        if r['noc'] and r['lines'] and not r['mode'].startswith('ERROR')
        and (r['end'] or '9999') >= day and r['mode'] in ('bus', 'coach', '')]
groups = collections.defaultdict(list)
for r in rows:
    groups[r['lines'].upper()].append(r)
want = collections.defaultdict(list)
for ln, g in groups.items():
    if len({r['noc'] for r in g}) < 2:
        continue
    hit = set()
    for a in g:
        for b in g:
            if a['noc'] == b['noc'] or not a['start'] or not b['start']:
                continue
            if a['start'] < b['start'] <= (a['end'] or '9999'):
                hit.add(a['file']); hit.add(b['file'])
    if hit:
        want[ln] = [r for r in g if r['file'] in hit]
print('line groups', len(want), 'files', sum(len(v) for v in want.values()))
z = zipfile.ZipFile(arch)
by_cont = collections.defaultdict(list)
for ln, g in want.items():
    for r in g:
        by_cont[r['container'].split('!')[0]].append((ln, r['file']))
safe = lambda s: ''.join(c if c.isalnum() else '_' for c in s)[:40]
for cont, items in by_cont.items():
    if cont.lower().endswith('.zip'):
        zz = zipfile.ZipFile(io.BytesIO(z.read(cont)))
        get = zz.read
    else:
        get = z.read
    for ln, f in items:
        d = os.path.join(out, safe(ln))
        os.makedirs(d, exist_ok=True)
        try:
            data = get(f)
        except KeyError:
            continue
        open(os.path.join(d, safe(cont) + '__' + os.path.basename(f)), 'wb').write(data)
