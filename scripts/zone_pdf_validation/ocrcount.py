"""Count journeys at a stop in OCR text of a column timetable (Metrobus).

OCR loses the column geometry but keeps each stop row on one line, with the
'Then every N mins until' legend spilling into the rows as words. A non-time
token sitting between two times in the counted row marks the abbreviated
block; N is read from the legend words in the same section."""
import re, sys, glob

DAY = [('MF', r'monday'), ('Sa', r'^\s*saturday'), ('Su', r'^\s*sunday')]
T4 = re.compile(r'^\d{4}$')


def tm(t):
    return int(t[:2]) * 60 + int(t[2:])


def count(text, row_pat):
    rp = re.compile(row_pat, re.I)
    day, out, notes = None, {}, []
    section = []

    def flush():
        if not section or day is None:
            return
        # headway for the section
        h = None
        for ln in section:
            toks = [t.strip('.,;:|') for t in ln.split()]
            for i in range(1, len(toks) - 1):
                m = re.fullmatch(r'(\d{1,2})(?:-(\d{1,2}))?', toks[i])
                if m and T4.match(toks[i - 1]) and T4.match(toks[i + 1]):
                    a, b = int(m.group(1)), int(m.group(2) or m.group(1))
                    if 3 <= a <= 60:
                        h = (a + b) / 2
                        break
            if h:
                break
        if h is None:
            m = re.search(r'every\D{0,40}?(\d{1,2})\s*min', ' '.join(section), re.I)
            h = int(m.group(1)) if m else None
        best = 0
        for ln in section:
            lab = re.split(r'\d{4}', ln)[0]
            if not rp.search(lab):
                continue
            toks = ln[len(lab):].split()
            n, add, prev, gap = 0, 0, None, False
            for t in toks:
                t = t.strip('.,;:|')
                if T4.match(t) and int(t[:2]) < 30 and int(t[2:]) < 60:
                    if not gap and prev is not None and h and (tm(t) - tm(prev)) % 1440 > 2.5 * h \
                            and any(re.search(r'every', x, re.I) for x in section):
                        gap = True
                    if gap and prev is not None and h:
                        a, b = tm(prev), tm(t)
                        if b < a:
                            b += 1440
                        add += max(0, int((b - a - 1) // h))
                    n += 1; prev = t; gap = False
                elif prev is not None and t:
                    gap = True
            best = max(best, n + add)
        out[day] = out.get(day, 0) + best

    for ln in text.splitlines():
        low = ln.lower().strip()
        d = next((c for c, p in DAY if re.search(p, low) and not re.search(r'\d{4}', ln)), None)
        if d:
            flush(); section = []; day = d
            continue
        if re.search(r'\d{4}', ln) or re.search(r'every|then|until|mins', low):
            section.append(ln)
        elif not low:
            continue
        else:
            # a stop row with no times, or a title: a new table if it looks like a heading
            if re.search(r'from|towards|timetable', low):
                flush(); section = []
    flush()
    return out


if __name__ == '__main__':
    f, pat = sys.argv[1], sys.argv[2]
    print(count(open(f).read(), pat))
