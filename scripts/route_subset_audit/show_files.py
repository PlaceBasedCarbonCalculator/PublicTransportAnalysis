"""Kept and dropped files of one run for given operator code and lines.

usage: python -I show_files.py <run>_kept.csv NOC[,NOC] line[,line] [src]
"""
import csv, sys
run, nocs, lines = sys.argv[1], set(sys.argv[2].split(',')), set(sys.argv[3].split(','))
src = sys.argv[4] if len(sys.argv) > 4 else None
rows = [r for r in csv.DictReader(open(run, encoding='utf-8'))
        if r['noc'] in nocs and set(r['lines'].split('|')) & lines and (src is None or r['src'] == src)]
rows.sort(key=lambda r: (r['src'], r['lines'], r['start'] or ''))
for r in rows:
    print(f"{r['src']:4} {r['group']:5} {'KEPT' if r['kept'] in ('TRUE', 'True') else 'drop'} "
          f"{r['start']}..{r['end'] or 'open':10} vj={r['vj']:>4} rev={r['rev']:>4} mod={r['mod'][:16]} "
          f"lines={r['lines'][:20]:20} so={r['so'][:24]:24} {r['file'][:70]}")
