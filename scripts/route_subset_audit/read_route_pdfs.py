"""Journeys per day type in a route's printed timetable, at its reference stop.

For every manifest route with a document in data/example_timetables whose
name carries the route (<prefix>_<ROUTE>-timetable-<date>-<hash>.pdf), the
column reader of the zone checks counts the journeys calling at a row that
names the reference stop (the busiest stop of the route in the feeds). Both
directions are counted, as the feeds count trips. A route whose reference
stop is not found in the document is reported with the rows seen, so the
row pattern can be given by hand in ROWS.

usage: python -I read_route_pdfs.py [manifest csv] [out csv]
"""
import collections, csv, glob, os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'zone_pdf_validation'))
import ttread  # noqa: E402
sys.path.insert(0, HERE)
import first_reader  # noqa: E402

EX = os.path.join(HERE, '..', '..', 'data', 'example_timetables')
manifest = sys.argv[1] if len(sys.argv) > 1 else 'data/route_subset/routes.csv'
out = sys.argv[2] if len(sys.argv) > 2 else 'data/route_subset/pdf_counts.csv'
GENERIC = {'bus', 'station', 'stop', 'road', 'street', 'lane', 'centre', 'the', 'and', 'stand',
           'interchange', 'stops', 'opp', 'adj', 'near', 'north', 'south', 'east', 'west'}
# hand-set row patterns: (document prefix regex, route) -> row regex
ROWS = {}
# Arriva publishes HTML tables (arriva_dl.py): data/example_timetables/arriva/<code>_<day>_<out|in>.html
ARRIVA = {('arriva north east', '4'): 'DC_DN_4', ('arriva north east', '13A'): 'DC_DN_13A',
          ('arriva north east', '13B'): 'DC_DN_13B', ('arriva north east', 'X4'): 'DC_SN_X4',
          ('arriva north east', 'X4A'): 'DC_SN_X4', ('arriva north east', 'X93'): 'DC_SN_X93',
          ('arriva kent and surrey', '101'): 'AKS_GM_101', ('arriva kent and surrey', '146'): 'AKS_GM_145',
          ('arriva kent and surrey', '71'): 'AKS_MD_71', ('arriva kent and surrey', '176'): 'AKS_GM_175'}
sys.path.insert(0, os.path.join(HERE, '..', 'stop_pdf_validation'))
# Rotala (Diamond, Preston Bus) portal pages, saved whole from
# portal.<operator>/timetable/<svc>/<op>/<ticketer>/<region>/live/all?print=true
# into data/example_timetables/rotala/<op>_<svc>_<region>.html: every day
# type on one page, each under <h4 id="dayN"> with its heading text
ROTALA = {('diamond bus', '63'): 'DIAM_63_WM.html', ('diamond bus', '65'): 'DIAM_65_WM.html',
          ('diamond bus', '247'): 'DIAM_247_Warwickshire.html', ('diamond bus', '76C'): 'DIAM_76C_Staffordshire.html',
          ('diamond bus', '24'): 'DIAM_24_WM.html',
          ('rotala preston bus', '35'): 'PBLT_35_NW.html', ('rotala preston bus', '8'): 'PBLT_8_NW.html',
          ('rotala preston bus', '31'): 'PBLT_31_NW.html'}

def read_stagecoach(paths):
    """Stagecoach prints one ROW per journey (stops across the page), under a
    'Mon, Tue, Wed, Thu, Fri' / 'Saturday' / 'Sunday' heading, so journeys
    per day type are the rows with times, both directions. The reference
    stop cannot be picked out (partial journeys show a dash in its column),
    so this is a route-level count: compare with the route's trips."""
    import pdfplumber
    days = [('MF', r'^mon,? tue,? wed,? thu\w*,? fri'), ('Sa', r'^saturday'), ('Su', r'^sunday')]
    per = collections.Counter()
    for path in paths:
        day = None
        with pdfplumber.open(path) as pdf:
            for page in pdf.pages:
                for ln in ttread.lines_of(page):
                    t = ln['text'].strip().lower()
                    for code, pat in days:
                        if re.search(pat, t):
                            day = code
                            break
                    times = [w for w in ln['words'] if ttread.TIME.match(w['text'])]
                    if day and len(times) >= 3 and not re.search(r'valid|operate', t):
                        per[day] += 1
    return dict(MF=per.get('MF', 0), Sa=per.get('Sa', 0), Su=per.get('Su', 0), rows={'all journeys (row layout)'},
                quals=set(), pattern='rows', doc=os.path.basename(paths[0]))

def read_rotala(fname, atco):
    """MF/Sa/Su journeys calling at the reference stop, both directions. The
    portal tags every row with the stop's ATCO code (data-atcocode), so the
    stop is matched exactly. A day heading the reader does not recognise is
    reported in quals rather than guessed."""
    path = os.path.join(EX, 'rotala', fname)
    if not os.path.exists(path):
        return None
    s = open(path, encoding='utf-8', errors='ignore').read()
    parts = re.split(r'<h4 class="clearfix" id="day\d">', s)[1:]
    per, labs = collections.Counter(), set()
    for part in parts:
        # the heading's day is the bold text; buttons come before it
        hb = re.search(r'<b>([^<]*)</b>', part[:1200])
        head = (hb.group(1) if hb else '').strip().lower()
        day = 'MF' if re.search(r'monday\s*(to|-)\s*friday', head) else \
              'Sa' if head.startswith('saturday') else 'Su' if head.startswith('sunday') else head[:30]
        for body in re.findall(r'<tbody[^>]*>(.*?)</tbody>', part, re.S):
            cols = set()
            # split on row starts: the last row of a table is not always closed
            for tr in re.split(r'<tr[\s>]', body)[1:]:
                m = re.search(r'data-atcocode="([^"]*)"', tr)
                if not m or m.group(1).upper() != atco.upper():
                    continue
                th = re.search(r'th-text.*?</th>', tr, re.S)
                lab = re.sub(r'\s+', ' ', re.sub(r'<[^>]*>', ' ', th.group(0)[9:] if th else '')).strip()
                labs.add(lab)
                tds = re.findall(r'<td[^>]*>\s*([^<]*?)\s*</td>', tr)
                cols |= {j for j, x in enumerate(tds) if re.match(r'\d{1,2}:\d{2}', x)}
            per[day] += len(cols)
    if labs:
        return dict(MF=per.get('MF', 0), Sa=per.get('Sa', 0), Su=per.get('Su', 0), rows=labs,
                    quals=set(k for k in per if k not in ('MF', 'Sa', 'Su')), pattern='atco=' + atco, doc=fname)
    return dict(MF='', Sa='', Su='', rows=set(), quals={'stop not found'}, pattern='atco=' + atco, doc=fname)

def read_arriva_route(code, line, words, atco=None):
    """MF/Sa/Su journeys of `line` calling at a row naming the reference stop"""
    import read_docs
    files = {f'{d}/{t}': os.path.join(EX, 'arriva', f'{code}_{d}_{t}.html')
             for d in ('MF', 'Sa', 'Su') for t in ('out', 'in')}
    files = {k: v for k, v in files.items() if os.path.exists(v)}
    if not files:
        return None
    # rows link the stop's NaPTAN code: match the reference stop exactly first
    if atco:
        per, labs = collections.Counter(), set()
        for key, f in files.items():
            rows = read_docs.arriva_table(f)
            if not rows:
                continue
            ncol = max(len(x[2]) for x in rows)
            svc = read_docs.arriva_services(f)
            keep = [j for j in range(ncol) if svc[j] == line.upper()] if len(svc) == ncol else range(ncol)
            hit = [x for x in rows if x[0].upper() == atco.upper()]
            per[key.split('/')[0]] += sum(1 for j in keep if any(j < len(x[2]) and x[2][j] for x in hit))
            labs |= {x[1] for x in hit}
        if labs:
            return dict(MF=per.get('MF', 0), Sa=per.get('Sa', 0), Su=per.get('Su', 0), rows=labs,
                        quals=set(), pattern='atco=' + atco, doc=code)
    for p in ['(?=.*' + ')(?=.*'.join(map(re.escape, words)) + ')', '|'.join(map(re.escape, words))]:
        mf, sa, su, quals, labs, ok = read_docs.read_arriva(files, '(?i)' + p, None, routes=[line])
        if labs:
            return dict(MF=mf, Sa=sa, Su=su, rows=labs, quals=quals, pattern=p, doc=code)
    return dict(MF='', Sa='', Su='', rows=set(), quals={'stop not found'}, pattern='', doc=code)

PREFIX = {'metrobus': 'metrobus_MB_', 'more bus': 'morebus_WDBC_', 'bluestar': 'bluestar_BLUS_',
          'brighton & hove': 'brightonhove_BH_', 'redline': 'redgroup_RLNE_',
          'stagecoach south wales': 'stagecoach/stagecoach_SSWL_',
          'stagecoach midlands': 'stagecoach/stagecoach_SCNH_',
          'stagecoach cumbria and lancashire': 'stagecoach/stagecoach_SCMY_',
          'border buses': ['bordersbuses_BORD_', 'bordersbuses_PERY_'],
          'banga buses': 'other/banga_BANG_', 'dartline coaches': 'other/truro_DTCO_',
          'red eagle': 'other/redeagle_REDE_'}
# First publishes one PDF per day type: <dir>/<prefix>_<line>_<mf|sa|su>.pdf
FIRST = {'first': 'first_ns/first_ns_', 'first berkshire': 'first_bk/first_bk_'}
# National Express West Midlands (nxdl.js): whole-week PDFs named by site slug;
# some print every journey twice, so columns at the same time count once
NX = {('west midlands bus', '61'): ['nxbus_nov_61-birmingham-frankley.pdf'],
      ('west midlands bus', '63'): ['nxbus_nov_63-birmingham-frankley.pdf'],
      ('west midlands bus', '10'): ['nxbus_nov_10-wolverhampton-perton.pdf', 'nxbus_nov_10-walsall-brownhills.pdf'],
      ('west midlands bus', '10A'): ['nxbus_nov_10a-wolverhampton-pattingham.pdf'],
      ('west midlands bus', '59'): ['nxbus_nov_59-wolverhampton-ashmore-park.pdf', 'nxbus_59-wolverhampton-ashmore-park.pdf']}

def docs_for(operator, line):
    """[(path, day_override)] for the route's documents"""
    op = operator.lower()
    if (op, line) in NX:
        have = [os.path.join(EX, f) for f in NX[(op, line)] if os.path.exists(os.path.join(EX, f))]
        return [(p, None) for p in have]
    if op in FIRST:
        return [(p, {'mf': 'MF', 'sa': 'Sa', 'su': 'Su'}[d]) for d in ('mf', 'sa', 'su')
                for p in glob.glob(os.path.join(EX, f'{FIRST[op]}{line}_{d}.pdf'))]
    pre = PREFIX.get(op)
    if not pre:
        return []
    docs = []
    for p in ([pre] if isinstance(pre, str) else pre):
        docs += glob.glob(os.path.join(EX, f'{p}{line}-timetable-*.pdf'))
    # latest edition across the publisher's prefixes
    docs.sort(key=lambda d: re.search(r'-(\d{8})-', d).group(1))
    return [(docs[-1], None)] if docs else []

def row_pattern(stop_name):
    words = [w for w in re.findall(r'[A-Za-z]{3,}', stop_name) if w.lower() not in GENERIC]
    if not words:
        words = re.findall(r'[A-Za-z]{3,}', stop_name)
    return words

rows = []
for r in csv.DictReader(open(manifest, encoding='utf-8')):
    akey = (r['operator'].lower(), r['line'])
    if akey in ARRIVA or akey in ROTALA:
        a = read_arriva_route(ARRIVA[akey], r['line'], row_pattern(r['stop_name']), r['ref_stop']) if akey in ARRIVA \
            else read_rotala(ROTALA[akey], r['ref_stop'])
        if a is None:
            continue
        row = dict(operator=r['operator'], line=r['line'], document=a['doc'], edition='20261117',
                   ref_stop=r['stop_name'], pattern=a['pattern'], MF=a['MF'], Sa=a['Sa'], Su=a['Su'],
                   MS='', MT='', Fr='', rows_hit=' | '.join(sorted(a['rows'])), rows_seen=' '.join(a['quals']))
        rows.append(row)
        print(f"{r['operator'][:12]:12} {r['line']:5} arriva   MF={a['MF']} Sa={a['Sa']} Su={a['Su']} "
              f"feeds {r['tnds']}/{r['bods_txc']}/{r['bods_gtfs']} ref={r['ref_tnds']}/{r['ref_bods_txc']}/{r['ref_bods_gtfs']} "
              f"rows: {row['rows_hit'][:60]} {row['rows_seen']}")
        continue
    docs = docs_for(r['operator'], r['line'])
    if not docs:
        continue
    if r['operator'].lower() in FIRST:
        # column notes matter: 17 November is a school day, so SH columns
        # (school holidays only) are left out (first_reader.py)
        cnt = {day: first_reader.count_stop(p, r['ref_stop'], r['line']) for p, day in docs}
        row = dict(operator=r['operator'], line=r['line'], document=os.path.basename(docs[0][0]),
                   edition='20261117', ref_stop=r['stop_name'], pattern='Stop code: ' + r['ref_stop'],
                   MF=cnt.get('MF', ''), Sa=cnt.get('Sa', ''), Su=cnt.get('Su', ''), MS='', MT='', Fr='',
                   rows_hit='Stop code ' + r['ref_stop'], rows_seen='')
        rows.append(row)
        print(f"{r['operator'][:12]:12} {r['line']:5} first    MF={row['MF']} Sa={row['Sa']} Su={row['Su']} "
              f"ref={r['ref_tnds']}/{r['ref_bods_txc']}/{r['ref_bods_gtfs']} (school day, SH left out)")
        continue
    if 'stagecoach' in r['operator'].lower():
        # Collected but not counted: Stagecoach documents mix routes in one
        # table ("Services 8 8 8") and restrict journeys by dated period
        # notes (Date1..Date4, XPrd1/Prd2); read_stagecoach() counts every
        # row and overstates. Reported as unread rather than wrong.
        print(f"{r['operator'][:12]:12} {r['line']:5} document held, not read (mixed routes, period notes)")
        continue
        a = read_stagecoach([p for p, _ in docs])
        row = dict(operator=r['operator'], line=r['line'], document=a['doc'],
                   edition=re.search(r'-(\d{8})-', a['doc']).group(1), ref_stop='(route total)', pattern=a['pattern'],
                   MF=a['MF'], Sa=a['Sa'], Su=a['Su'], MS='', MT='', Fr='', rows_hit='all journeys', rows_seen='')
        rows.append(row)
        print(f"{r['operator'][:12]:12} {r['line']:5} {row['edition']} MF={a['MF']} Sa={a['Sa']} Su={a['Su']} "
              f"route trips {r['tnds']}/{r['bods_txc']}/{r['bods_gtfs']} (row layout, route total)")
        continue
    doc = docs[0][0]
    blocks = []
    # Stagecoach heads its tables "Mon, Tue, Wed, Thu, Fri"
    extra = [('MF', r'^mon,? tue,? wed,? thu\w*,? fri')] if 'stagecoach' in r['operator'].lower() else None
    for p, day in docs:
        blocks += ttread.parse(p, day_override=day, day_extra=extra)
    labels = sorted({row['label'] for b in blocks for row in b['rows'] if row['label']})
    key = (os.path.basename(doc).split('_')[0], r['line'])
    words = row_pattern(r['stop_name'])
    pats = [ROWS[key]] if key in ROWS else \
        ['(?=.*' + ')(?=.*'.join(map(re.escape, words)) + ')', '|'.join(map(re.escape, words))]
    res, used = None, ''
    nx = (r['operator'].lower(), r['line']) in NX
    for p in pats:
        c = ttread.count(blocks, p, distinct_times=nx)
        if any(v['n'] for v in c.values()):
            res, used = c, p
            break
    row = dict(operator=r['operator'], line=r['line'], document=os.path.basename(doc),
               edition=(re.search(r'-(\d{8})-', doc) or re.search(r'()', '')).group(1),
               ref_stop=r['stop_name'], pattern=used)
    for d in ('MF', 'Sa', 'Su', 'MS', 'MT', 'Fr'):
        row[d] = res[d]['n'] if res and d in res else ''
    row['rows_hit'] = ' | '.join(sorted({x for v in res.values() for x in v['rows']})) if res else ''
    row['rows_seen'] = '' if res else ' | '.join(labels[:40])
    rows.append(row)
    print(f"{r['operator'][:12]:12} {r['line']:5} {row['edition']} MF={row['MF']} Sa={row['Sa']} Su={row['Su']} "
          f"feeds {r['tnds']}/{r['bods_txc']}/{r['bods_gtfs']} ref={r['ref_tnds']}/{r['ref_bods_txc']}/{r['ref_bods_gtfs']} "
          f"{'rows: ' + row['rows_hit'][:60] if res else 'NOT FOUND ' + r['stop_name']}")
with open(out, 'w', newline='', encoding='utf-8') as f:
    w = csv.DictWriter(f, list(rows[0].keys())); w.writeheader(); w.writerows(rows)
