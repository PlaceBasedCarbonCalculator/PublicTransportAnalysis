"""Departures at one stop from First Bus per-day timetable PDFs.

First's PDFs (Norfolk & Suffolk, Berkshire) print each stop as a row of
times followed by a "Stop code: <ATCO>" line, and head each column with a
service number and a note (SD school days only, SH school holidays only).
Plain text loses the column alignment, so the notes are matched to the
times by x position. On a school day SH columns are left out; on a holiday
SD columns would be.
"""
import re
import pdfplumber

def _lines(page):
    words = page.extract_words(keep_blank_chars=False, use_text_flow=False)
    rows = {}
    for w in words:
        key = round(w['top'] / 3)
        rows.setdefault(key, []).append(w)
    return [sorted(v, key=lambda w: w['x0']) for _, v in sorted(rows.items())]

def count_stop(path, atco, line, school_day=True):
    """departures at <atco> on route <line>, all directions, in one PDF"""
    skip = 'SH' if school_day else 'SD'
    n = 0
    with pdfplumber.open(path) as pdf:
        for page in pdf.pages:
            ls = _lines(page)
            notes, svc, hdr = [], [], False
            for i, l in enumerate(ls):
                txt = ' '.join(w['text'] for w in l)
                if txt.startswith('Service No'):
                    svc = [w for w in l if not w['text'].startswith(('Service', 'No'))]
                    notes, hdr = [], True
                    continue
                # the notes ("SD", "SH") sit on their own line under the
                # service numbers, apart from the "Notes:" label
                if hdr and all(re.fullmatch(r'Notes:|[A-Z]{1,4}', w['text']) for w in l):
                    notes += [w for w in l if w['text'] != 'Notes:']
                    continue
                hdr = False
                if txt.startswith('Stop code:') and atco in txt and i > 0:
                    for w in ls[i - 1]:
                        if not re.fullmatch(r'\d{4}', w['text']):
                            continue
                        cx = (w['x0'] + w['x1']) / 2
                        near = lambda ws: [x for x in ws if abs((x['x0'] + x['x1']) / 2 - cx) < 12]
                        s = near(svc)
                        if s and s[0]['text'] != line:
                            continue
                        if any(x['text'] == skip for x in near(notes)):
                            continue
                        n += 1
    return n

if __name__ == '__main__':
    import sys
    print(count_stop(sys.argv[1], sys.argv[2], sys.argv[3]))
