"""TfL running schedules: one row per trip, one column per timing point. A trip
touches a zone when it has a time under a timing point whose transit node is
in the zone."""
import re, collections, pdfplumber
from ttread import lines_of

NODE = re.compile(r'^(?:A[A-Z0-9]{2}\d{2}|J\d{4})$')
TIME4 = re.compile(r'^\d{4}$')


def trips(path, nodes):
    nodes = set(nodes)
    n_all, n_hit = 0, 0
    with pdfplumber.open(path) as pdf:
        cols = None
        for page in pdf.pages:
            for ln in lines_of(page):
                ws = ln['words']
                nd = [w for w in ws if NODE.match(w['text'])]
                if len(nd) >= 3 and len(nd) >= 0.6 * len(ws):
                    cols = [((w['x0'] + w['x1']) / 2, w['text']) for w in nd]
                    continue
                if cols is None or not ws or not re.fullmatch(r'\d{1,4}', ws[0]['text']) or ws[0]['x0'] > 100:
                    continue
                times = [w for w in ws[1:] if TIME4.match(w['text']) and w['x0'] > cols[0][0] - 25]
                if not times:
                    continue
                n_all += 1
                hit = False
                for w in times:
                    xc = (w['x0'] + w['x1']) / 2
                    x, code = min(cols, key=lambda c: abs(c[0] - xc))
                    if abs(x - xc) < 16 and code in nodes:
                        hit = True
                n_hit += hit
    return n_hit, n_all
