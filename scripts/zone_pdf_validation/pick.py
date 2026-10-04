import re, sys, collections
keys = [l.strip() for l in open('s3keys.txt')]
want = {
 'readingbuses/RBUS': '17 5 6 26 21 3 600 500 33 11 16 1 4 4a 50 50a 18 29 28 15a 25 TVP 2 9'.split(),
 'metrobus/MB': '10 100 20 3 200 2 4 5 400 1 21 281'.split(),
 'brightonhove/BH': '18 50 20 12A 25 14 12'.split(),
 'bluestar/BLUS': '17 18'.split(),
 'eyms/EY': '57 45 56 51 58 104 54 35 X46'.split(),
 'redgroup/RRTR': '130 4 300'.split(), 'redgroup/RLNE': '130 4 300'.split(),
 'carouselbuses/CSLB': '130 300 4'.split(),
}
ed = collections.defaultdict(list)
for k in keys:
    m = re.match(r'([^/]+/[^/]+)/(.+)-timetable-(\d{8})-[0-9a-f]+\.pdf$', k)
    if m: ed[(m.group(1), m.group(2).lower())].append((m.group(3), k))
for pre, routes in want.items():
    for r in routes:
        e = sorted(ed.get((pre, r.lower()), []))
        if not e: print('MISSING', pre, r); continue
        before = [x for x in e if x[0] <= '20260727']
        during = [x for x in e if '20260727' < x[0] <= '20260823']
        pickd = before[-1] if before else None
        print(pre, r, 'PICK', pickd[1] if pickd else None, '| mid-window:', [d for d,_ in during], '| all:', [d for d,_ in e][-4:])
