"""Pull the TransXChange files of chosen operators out of a raw archive.

Selection is driven by the index that txc_index.py wrote, so the whole of an
operator comes out (every file for every NOC or operator name that matches),
which keeps txc_filter_files' decisions the same as in the national run: the
rules compare files within an operator and line.

usage: python -I extract_subset.py <index.csv> <archive zip | tnds snapshot dir> <out dir>
                                   [--noc A,B,...] [--opname regex] [--lines 12,X4,...]
A file is taken when any of the given tests matches (lines only narrow the
operator tests when given with them). TNDS files land in <out>/<region>/,
BODS files in <out>/<container>/.
"""
import argparse, csv, io, os, re, sys, zipfile

ap = argparse.ArgumentParser()
ap.add_argument('index'); ap.add_argument('archive'); ap.add_argument('out')
ap.add_argument('--noc', default=''); ap.add_argument('--opname', default='')
ap.add_argument('--lines', default='')
ap.add_argument('--names', default='', help='operator names, matched after normalising '
                '(lower case, & -> and, non-alphanumerics dropped), as select_operators.py lists them')
a = ap.parse_args()
nocs = {x.strip().upper() for x in a.noc.split(',') if x.strip()}
oprx = re.compile(a.opname, re.I) if a.opname else None
lines = {x.strip().upper() for x in a.lines.split(',') if x.strip()}
norm = lambda s: re.sub(r'[^a-z0-9]+', '', s.lower().replace('&', 'and'))
names = {norm(x) for x in a.names.split(',') if x.strip()}

def wanted(r):
    hit = False
    if nocs and {x.strip().upper() for x in r['noc'].split(';')} & nocs:
        hit = True
    if oprx and any(oprx.fullmatch(p.strip()) for p in r.get('opname', '').split(';')):
        hit = True
    if names and {norm(p) for p in r.get('opname', '').split(';')} & names:
        hit = True
    if lines:
        if not ({x.strip().upper() for x in r['lines'].split(';')} & lines):
            return False
        if not (nocs or oprx):
            hit = True
    return hit

rows = [r for r in csv.DictReader(open(a.index, encoding='utf-8')) if wanted(r)]
print(len(rows), 'files selected', file=sys.stderr)
safe = lambda s: re.sub(r'[^A-Za-z0-9_.-]+', '_', s)[:80]
cache = {}

def open_chain(path, container):
    """ZipFile for the (possibly nested) container holding the file."""
    key = (path, container)
    if key in cache:
        return cache[key]
    if os.path.isdir(path):                     # TNDS: container is a regional zip
        d = os.path.join(path, 'TNDSV2.5')
        z = zipfile.ZipFile(os.path.join(d if os.path.isdir(d) else path, container))
    else:
        z = zipfile.ZipFile(path)
        if container.lower().endswith('.zip'):
            for part in container.split('!'):
                z = zipfile.ZipFile(io.BytesIO(z.read(part)))
    cache[key] = z
    return z

n = 0
for r in rows:
    z = open_chain(a.archive, r['container'])
    member = r['file']
    if r['source'] == 'tnds':
        sub = os.path.splitext(r['container'])[0]
    else:
        sub = safe(r['container'].split('/')[0])
    dest = os.path.join(a.out, sub)
    os.makedirs(dest, exist_ok=True)
    try:
        data = z.read(member)
    except KeyError:
        print('missing', r['container'], member, file=sys.stderr)
        continue
    with open(os.path.join(dest, os.path.basename(member)), 'wb') as f:
        f.write(data)
    n += 1
print('extracted', n, 'to', a.out)
