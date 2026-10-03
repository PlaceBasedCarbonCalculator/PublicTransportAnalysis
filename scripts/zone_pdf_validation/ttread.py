"""Column-aware reader for printed bus timetables (passenger timetables, one
column per journey). Counts the journeys that call at any row matching a
pattern, per day type, expanding "then every N minutes" blocks.

Kept deliberately small: the per-document configuration (which rows, which day
types, which columns to drop) lives in the caller, and every count is returned
with the diagnostics needed to check it by eye.
"""
import re, statistics, collections
import pdfplumber

TIME = re.compile(r'^(\d{1,2})[.:](\d{2})$|^(\d{2})(\d{2})$')
DAY_PATTERNS = [
    ('MT', r'monday\S*\s*(to|-|–)\s*thursday|mon\S*\s*-\s*thu'),
    ('Fr', r'^\s*fridays?( only)?\s*$|^fridays?\b(?!.*saturday)'),
    ('MF', r'monday\S*\s*(to|-|–)\s*friday|mon\S*\s*-\s*fri|weekday'),
    ('MS', r'monday\S*\s*(to|-|–)\s*saturday|mon\S*\s*-\s*sat'),
    ('Sa', r'^\s*([a-z]?\d{1,3}[a-z]?\s+)*saturdays?\b'),
    ('Su', r'^\s*([a-z]?\d{1,3}[a-z]?\s+)*sundays?\b|sunday.*(bank|public) holiday'),
]
FREQ_WORDS = {'then', 'every', 'until', 'mins', 'min', 'minutes', 'at', 'least',
              'up', 'to', 'approx', 'approximately', 'or', 'less', 'past',
              'each', 'hour', 'these', 'times', 'and', 'buses', 'bus', 'about'}


def tmin(tok, ampm=None):
    m = TIME.match(tok)
    if not m:
        return None
    if m.group(1) is not None:
        h, mi = int(m.group(1)), int(m.group(2))
    else:
        h, mi = int(m.group(3)), int(m.group(4))
    if mi > 59 or h > 29:
        return None
    if ampm == 'am':
        h = h % 12
    elif ampm == 'pm':
        h = h % 12 + 12
    return h * 60 + mi


def lines_of(page, ytol=2.5):
    words = page.extract_words(x_tolerance=1.5, y_tolerance=2, keep_blank_chars=False)
    words.sort(key=lambda w: (round(w['top']), w['x0']))
    lines = []
    for w in words:
        if lines and abs(lines[-1]['top'] - w['top']) <= ytol:
            lines[-1]['words'].append(w)
        else:
            lines.append({'top': w['top'], 'words': [w]})
    for ln in lines:
        ln['words'].sort(key=lambda w: w['x0'])
        ln['text'] = ' '.join(w['text'] for w in ln['words'])
    return lines


def classify_day(text, extra=None):
    t = text.lower().strip()
    for code, pat in (extra or []) + DAY_PATTERNS:
        if re.search(pat, t):
            return code
    return None


def parse(path, day_override=None, day_extra=None, label_max_x=None, pages=None):
    """Return a list of blocks. A block is a run of timetable rows under one
    day-type heading, with its time tokens, frequency words and note tokens."""
    blocks = []
    with pdfplumber.open(path) as pdf:
        day = day_override
        for pno, page in enumerate(pdf.pages):
            if pages and pno not in pages:
                continue
            cur = None
            pending = []
            last_lab = None
            for ln in lines_of(page):
                ws = ln['words']
                d0 = None if day_override else classify_day(ln['text'], day_extra)
                if d0 and re.search(r'(from|valid|until|20\d\d|^\s*\w+days?\s*$)', ln['text'], re.I) and len(ln['text']) < 160 \
                        and not re.search(r'\d{1,2}[.:]\d{2}.*\d{1,2}[.:]\d{2}.*\d{1,2}[.:]\d{2}', ln['text']):
                    day = d0
                    cur = None
                    continue
                times = [w for w in ws if TIME.match(w['text'])]
                # label: words left of the first time token
                first_tx = times[0]['x0'] if times else 1e9
                lab_words = [w for w in ws if w['x1'] <= first_tx + 0.5 and not TIME.match(w['text'])]
                if label_max_x:
                    lab_words = [w for w in lab_words if w['x0'] < label_max_x]
                label = ' '.join(w['text'] for w in lab_words)
                if times and not label and last_lab and ln['top'] - last_lab[1] < 16:
                    label = last_lab[0]
                if not times and ws and ws[0]['x0'] < 120 and not any(w['text'].lower() in FREQ_WORDS for w in ws):
                    last_lab = (ln['text'], ln['top'])
                elif times:
                    last_lab = None
                if not times:
                    d = None if day_override else classify_day(ln['text'], day_extra)
                    if d and len(ln['text']) < 120:
                        day = d
                        cur = None
                        continue
                    if cur is not None:
                        cur['other'].append(ln)
                    pending.append(ln)
                    continue
                if re.match(r'(downloaded|printed|page \d)', label, re.I):
                    continue
                prev_head = None
                if cur is not None and label and cur['rows'] and cur['rows'][-1]['label'] != label \
                        and any(r['label'] == label for r in cur['rows']):
                    prev_head = cur.get('head')
                    cur = None
                if cur is None or ln['top'] - cur['last_top'] > 60:
                    cur = {'page': pno, 'day': day, 'rows': [], 'last_top': ln['top'],
                           'other': [p for p in pending if p['top'] > ln['top'] - 45],
                           'head': [p for p in pending if p['top'] > ln['top'] - 45]}
                    if not cur['head'] and prev_head:
                        cur['head'] = prev_head
                    blocks.append(cur)
                pending = []
                cur['rows'].append({'label': label, 'top': ln['top'], 'times': times, 'words': ws})
                cur['last_top'] = ln['top']
    return blocks


def columns(block, tol=None):
    xs = sorted((w['x0'] + w['x1']) / 2 for r in block['rows'] for w in r['times'])
    if not xs:
        return []
    if tol is None:
        widths = [w['x1'] - w['x0'] for r in block['rows'] for w in r['times']]
        tol = max(4.0, statistics.median(widths) * 0.6)
    cols = [[xs[0]]]
    for x in xs[1:]:
        if x - statistics.mean(cols[-1]) <= tol:
            cols[-1].append(x)
        else:
            cols.append([x])
    return [statistics.mean(c) for c in cols]


def nearest(cols, x):
    return min(range(len(cols)), key=lambda i: abs(cols[i] - x))


def ampm_map(block, cols):
    m = {}
    for ln in block.get('head', []) + [{'words': r['words']} for r in block['rows']]:
        toks = [w for w in ln['words'] if w['text'].lower() in ('am', 'pm')]
        if len(toks) >= 2:
            for w in toks:
                m[nearest(cols, (w['x0'] + w['x1']) / 2)] = w['text'].lower()
    return m


def route_cols(block, cols, routes):
    """Columns whose service-number header is in `routes` (None when the block
    carries no header row). The header is the line with the most tokens that
    are route codes."""
    rs = {r.upper() for r in routes}
    best = None
    for ln in block.get('head', []) + [{'words': r['words']} for r in block['rows']]:
        toks = [w for w in ln['words'] if re.fullmatch(r'[A-Z]{0,3}\d{1,3}[A-Za-z]{0,2}', w['text']) and not TIME.match(w['text'])]
        if len(toks) >= 2 and len(toks) >= 0.5 * len(ln['words']):
            if best is None or len(toks) > len(best):
                best = toks
    if best is None:
        return None
    keep = set()
    for w in best:
        if w['text'].upper() in rs:
            keep.add(nearest(cols, (w['x0'] + w['x1']) / 2))
    return keep


def count(blocks, row_pat, drop_note=None, routes=None, note_pat=r'^(notes?|days? of operation|service no\.?:?)',
          ignore_filler=True, row_exclude=None, debug=False):
    """Journeys per day type calling at any row whose label matches row_pat.

    Returns {day: {'n': explicit+expanded, 'explicit': .., 'expanded': ..,
    'qualifiers': set(), 'rows': set(labels)}}."""
    rp = re.compile(row_pat, re.I)
    rx = re.compile(row_exclude, re.I) if row_exclude else None
    out = collections.defaultdict(lambda: {'n': 0, 'explicit': 0, 'expanded': 0,
                                           'qualifiers': set(), 'rows': set(), 'dropped': 0})
    for b in blocks:
        cols = columns(b)
        if not cols:
            continue
        ap = ampm_map(b, cols)
        hit_rows = [r for r in b['rows'] if rp.search(r['label']) and not (rx and rx.search(r['label']))]
        if not hit_rows:
            continue
        # notes per column
        dropped = set()
        if drop_note:
            dn = re.compile(drop_note)
            for ln in b['other'] + [{'words': r['words'], 'label': r['label']} for r in b['rows']]:
                lab = ' '.join(w['text'] for w in ln['words'][:3])
                if re.search(note_pat, lab, re.I) or ln.get('label') == '':
                    for w in ln['words']:
                        if dn.search(w['text']):
                            dropped.add(nearest(cols, (w['x0'] + w['x1']) / 2))
        if routes:
            keep = route_cols(b, cols, routes)
            if keep is not None:
                dropped |= set(range(len(cols))) - keep
        hit_cols = {}
        for r in hit_rows:
            toks = r['times']
            if ignore_filler:
                # NX pads rows with 0000 cells after the last journey
                while toks and toks[-1]['text'] in ('0000', '00:00'):
                    toks = toks[:-1]
            for w in toks:
                c = nearest(cols, (w['x0'] + w['x1']) / 2)
                if c in dropped:
                    continue
                t = tmin(w['text'], ap.get(c))
                hit_cols.setdefault(c, t)
        d = out[b['day']]
        d['explicit'] += len(hit_cols)
        d['dropped'] += len(dropped)
        d['rows'].update(r['label'] for r in hit_rows)
        # frequency blocks: words between columns on any line of the block
        fw = []
        for ln in b['other'] + [{'words': r['words']} for r in b['rows']]:
            for w in ln['words']:
                if w['text'].lower().strip('.,') in FREQ_WORDS or re.fullmatch(r'\d{1,2}', w['text']):
                    fw.append(w)
        groups = []
        for w in sorted(fw, key=lambda w: w['x0']):
            xc = (w['x0'] + w['x1']) / 2
            # only words that sit between two columns, not on a column
            if groups and xc - groups[-1]['x'] < 25:
                groups[-1]['w'].append(w)
                groups[-1]['x'] = (groups[-1]['x'] + xc) / 2
            else:
                groups.append({'x': xc, 'w': [w]})
        for g in groups:
            txt = ' '.join(w['text'].lower() for w in g['w'])
            if not re.search(r'every|past', txt):
                continue
            nums = [int(w['text']) for w in g['w'] if re.fullmatch(r'\d{1,2}', w['text'])]
            left = [i for i, x in enumerate(cols) if x < g['x'] - 3]
            right = [i for i, x in enumerate(cols) if x > g['x'] + 3]
            if not left or not right:
                continue
            cl, cr = left[-1], right[0]
            if 'past' in txt or (not nums and 'hour' not in txt.split()):
                d['qualifiers'].add('unexpanded:' + txt[:40])
                continue
            h = nums[0] if nums else 60
            t1, t2 = hit_cols.get(cl), hit_cols.get(cr)
            if t1 is None or t2 is None:
                d['qualifiers'].add('gap-without-zone-times:' + txt[:30])
                continue
            while t2 < t1:
                t2 += 720 if ap else 1440
            n = max(0, (t2 - t1 - 1) // h)
            d['expanded'] += n
            tw = set(txt.split())
            q = 'up to' if {'up', 'to'} <= tw else 'at least' if 'least' in tw else 'or less' if 'less' in tw else 'approx' if tw & {'approx', 'approximately', 'about'} else ''
            if q:
                d['qualifiers'].add(q)
            if debug:
                print('freq', b['page'], txt, h, t1, t2, n)
        if any('past' in ' '.join(w['text'].lower() for w in ln['words']) for ln in b['other'] + [{'words': r['words']} for r in b['rows']]):
            best_add = 0
            for r in hit_rows:
                tc = {}
                for w in r['times']:
                    c = nearest(cols, (w['x0'] + w['x1']) / 2)
                    tc[c] = tmin(w['text'], ap.get(c))
                mins = [w for w in r['words'] if re.fullmatch(r'\d{2}', w['text'])]
                add = 0
                groups = collections.defaultdict(set)
                for w in mins:
                    xc = (w['x0'] + w['x1']) / 2
                    left = [i for i, x in enumerate(cols) if x < xc - 2 and i in tc]
                    right = [i for i, x in enumerate(cols) if x > xc + 2 and i in tc]
                    if left and right:
                        groups[(left[-1], right[0])].add(int(w['text']))
                for (cl, cr), M in groups.items():
                    t1, t2 = tc[cl], tc[cr]
                    if t1 is None or t2 is None or not M:
                        continue
                    while t2 < t1:
                        t2 += 720 if ap else 1440
                    add += sum(1 for t in range(t1 + 1, t2) if t % 60 in M)
                best_add = max(best_add, add)
            if best_add:
                d['expanded'] += best_add
                d['qualifiers'] = {q for q in d['qualifiers'] if not q.startswith('unexpanded:') or 'past' not in q}
                d['qualifiers'].add('past-hour expanded')
        d['n'] = d['explicit'] + d['expanded']
    return dict(out)
