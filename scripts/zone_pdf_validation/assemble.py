import paths
import os, re, math, hashlib, shutil, json
import pandas as pd
from registry import docs
from verdict import zone_verdicts

SP = paths.WORK
REPO = paths.REPO
EX = REPO + 'data/example_timetables/'
DOCS = {d['key']: d for d in docs}
WIN0, WIN1 = '2026-07-27', '2026-08-23'
TOL = 0.15


def dest_name(path):
    b = os.path.basename(path)
    if path.startswith(EX):
        return b
    if '/nx/' in path:
        return 'nxbus_' + b
    if '/first/' in path:
        m = re.match(r'first_o(\d+)_(.+)_(\w+)\.pdf', b)
        reg = {'7': 'essex', '12': 'portsmouth', '6': 'wessex', '21': 'swwales'}[m.group(1)]
        return f'first_{reg}_{m.group(2)}_{m.group(3)}.pdf'
    if '/lothian/' in path:
        return 'lothian_' + b
    return b   # passenger platform names already carry operator, route and edition


_HASH = None


def saved_name(path):
    """The name the document has in data/example_timetables, where an
    identical file may already be held under another name."""
    global _HASH
    if _HASH is None:
        _HASH = {hashlib.md5(open(EX + f, 'rb').read()).hexdigest(): f for f in sorted(os.listdir(EX))}
    return _HASH.get(hashlib.md5(open(path, 'rb').read()).hexdigest(), dest_name(path))


def verdict(t, b):
    def ok(x): return x is not None and not pd.isna(x) and abs(x - 1) <= TOL
    def miss(x): return x is not None and not pd.isna(x) and x == 0
    if miss(t) and miss(b): return 'both absent'
    if ok(t) and ok(b): return 'both agree'
    if ok(t): return 'BODS GTFS absent' if miss(b) else 'TNDS right'
    if ok(b): return 'TNDS absent' if miss(t) else 'BODS GTFS right'
    lt = abs(math.log(t)) if t else 9; lb = abs(math.log(b)) if b else 9
    if miss(t): return 'TNDS absent; BODS GTFS off'
    if miss(b): return 'BODS GTFS absent; TNDS off'
    return 'neither; TNDS closer' if lt < lb else 'neither; BODS GTFS closer'


def edition_status(ed, key):
    if ed is None: return 'not stated'
    if ed <= WIN0:
        if key.startswith('P_metrobus_MB_400-timetable-20250927'): return 'in force to 7 Aug'
        return 'in force'
    if ed <= WIN1: return 'starts mid-window'
    return 'later edition'


def main(crawley=None):
    r = pd.read_pickle(SP + 'results.pkl')
    l = pd.read_pickle(SP + 'london.pkl')
    if crawley is None and os.path.exists(SP + 'crawley.pkl'):
        crawley = pd.read_pickle(SP + 'crawley.pkl')
    parts = [r, l] + ([crawley] if crawley is not None else [])
    a = pd.concat(parts, ignore_index=True)
    zv = zone_verdicts()
    a['locality'] = a.zone.map(lambda z: zv[z]['locality'])
    a['zone_verdict'] = a.zone.map(lambda z: zv[z]['verdict'])
    a['zone_gap'] = a.zone.map(lambda z: zv[z]['gap'])
    files, eds = [], []
    for _, x in a.iterrows():
        if x['doc'].startswith('TfL'):
            files.append('; '.join(x['files'])); eds.append(x.get('edition'))
        else:
            d = DOCS[x['doc']]
            files.append('; '.join(sorted({saved_name(f) for f in d['files'].values()})))
            eds.append(x['edition'])
    a['document'] = files
    a['edition'] = eds
    a['edition_status'] = [edition_status(e, k) if not k.startswith('TfL') else 'TfL schedule'
                           for e, k in zip(a.edition, a.doc)]
    a['verdict'] = [verdict(t, b) for t, b in zip(a.t_ratio, a.b_ratio)]
    a['reliable'] = a.reliable.fillna(True).astype(bool)
    a.to_pickle(SP + 'final.pkl')
    return a


def copy_documents(a):
    """Copy every document the comparison used into data/example_timetables,
    skipping exact duplicates of a file already there."""
    have = {}
    for f in os.listdir(EX):
        have[hashlib.md5(open(EX + f, 'rb').read()).hexdigest()] = f
    used = set()
    for k in set(a.doc):
        if k in DOCS:
            used |= set(DOCS[k]['files'].values())
    copied = []
    for f in sorted(used):
        if f.startswith(EX):
            continue
        h = hashlib.md5(open(f, 'rb').read()).hexdigest()
        if h in have:
            continue
        dn = dest_name(f)
        shutil.copy(f, EX + dn)
        have[h] = dn
        copied.append(dn)
    return copied


if __name__ == '__main__':
    a = main()
    print(a.verdict.value_counts())
