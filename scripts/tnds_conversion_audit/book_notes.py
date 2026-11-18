"""Journeys UK2GTFS drops as bookable: any VehicleJourney note containing
"book" (lower case, as transxchange_export() tests it). Counts journeys per
note text, and files that lose every journey.

usage: python -I book_notes.py <tnds snapshot dir | bods archive zip>
"""
import collections, os, re, sys, zipfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from txc_index import walk
inp = sys.argv[1]
if os.path.isdir(inp):
    d = os.path.join(inp, 'TNDSV2.5')
    srcs = [(zipfile.ZipFile(os.path.join(d, f)), f) for f in sorted(os.listdir(d)) if f.endswith('.zip') and f != 'iom.zip']
else:
    srcs = [(zipfile.ZipFile(inp), os.path.basename(inp))]
notes = collections.Counter(); vj_tot = vj_book = 0; whole = []; modes = collections.Counter()
for z, p in srcs:
    for cont, name, data in walk(z, p):
        s = data.decode('utf-8', 'ignore')
        vjs = re.findall(r'<VehicleJourney[ >].*?</VehicleJourney>', s, re.S)
        if not vjs: continue
        mode = (re.search(r'<Mode>([^<]+)', s) or [None, ''])[1]
        nb = 0
        for v in vjs:
            t = re.findall(r'<NoteText>([^<]*)', v)
            if any('book' in x for x in t):
                nb += 1
                for x in t:
                    if 'book' in x: notes[x.strip()[:90]] += 1
        vj_tot += len(vjs); vj_book += nb; modes[mode] += nb
        if nb and nb == len(vjs): whole.append((cont[:40], name[-60:], mode, nb))
print('journeys', vj_tot, 'dropped as bookable', vj_book, 'by mode', dict(modes))
print('files losing every journey:', len(whole))
for w in whole[:40]: print('  ', *w)
print('commonest notes:')
for k, v in notes.most_common(25): print(f'  {v:6d}  {k}')
