"""Raw TransXChange journeys per line and date, for files matching a pattern.

usage: python -I raw_counts.py <region zip> <file-name regex> [line,line,...]
Prints one row per file and line: journeys on each audit date.
"""
import datetime as dt, os, re, sys, zipfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from txcday import runs_on

DATES = [dt.date(2026, 7, 28), dt.date(2026, 8, 1), dt.date(2026, 8, 2),
         dt.date(2026, 8, 4), dt.date(2026, 8, 8), dt.date(2026, 8, 9)]
if os.environ.get('AUDIT_ALL_DATES'):   # every date of the window
    DATES = [dt.date(2026, 7, 27) + dt.timedelta(days=i) for i in range(14)]
zp, pat = sys.argv[1], re.compile(sys.argv[2])
want = set(sys.argv[3].split(',')) if len(sys.argv) > 3 else None
z = zipfile.ZipFile(zp)
print('file', 'line', *[d.strftime('%a%d%b') for d in DATES], sep='\t')
tot = {}
for n in sorted(x for x in z.namelist() if pat.search(x)):
    r = runs_on(z.read(n), DATES)
    for line, by in sorted(r.items()):
        if want and line not in want:
            continue
        print(n[:60], line, *[by.get(d, 0) for d in DATES], sep='\t')
        for d in DATES:
            tot.setdefault(line, {}).setdefault(d, 0)
            tot[line][d] += by.get(d, 0)
for line, by in sorted(tot.items()):
    print('TOTAL', line, *[by[d] for d in DATES], sep='\t')
