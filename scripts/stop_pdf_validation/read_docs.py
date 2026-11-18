"""Read the published timetables for the stop-level disagreement cases.

Writes data/stop_pdf_documents.csv: for each case stop and route, the journeys
per operating day (MF, Sa, Su) the operator's document prints at a timing
point in the same place. The pipeline (R/stop_pdf_validation.R) counts the two
feeds at that same place and compares.

Each reading names a *hub*: the case stops it applies to, the stop at its
centre, a radius, and the document rows that stand for it. A journey is
counted once if it calls at any matching row in the document, and once if it
calls at any stop within the radius in a feed, so the two counts are of the
same thing even where the case stop itself is not a printed timing point.

Readings carried over from the zone checks (data/zone_pdf_validation.csv) are
the exception: they were counted at a whole LSOA, so they are written with
read_zone set and the pipeline counts the feeds over the same zone.

usage: python read_docs.py            (from the repository root or anywhere)
       python read_docs.py --show HUB (print the matched rows, to check)

The documents are fixed; rerun this only when one is added or a pattern is
changed. Python, like the zone scripts whose column reader it reuses
(../zone_pdf_validation/ttread.py); needs pdfplumber and pdftotext.
"""
import ast, csv, os, re, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, os.path.join(REPO, 'scripts', 'zone_pdf_validation'))
import ttread as T  # noqa: E402

EX = os.path.join(REPO, 'data', 'example_timetables')
OUT = os.path.join(REPO, 'data', 'stop_pdf_documents.csv')
WIN0, WIN1 = '2026-07-27', '2026-08-09'

BHAM_ROWS = (r'^Birmingham,? (City Centre|Moor St|Priory|Carrs|Colmore|Corporation|High St|'
             r'Bull St|Digbeth|Coach St|Bus Mall|Park St|Old Square|Paradise|Albert St)|'
             r'^(Bus Mall|Digbeth|Moor St|Park Street|Birmingham Coach Station|Birmingham)\b')

# key: (case stops, centre stop, radius in metres, feed stop-name pattern,
#       document row pattern, document row exclusion)
# The centre is usually a case stop. Where no document prints a timing point
# near the case stops it is the nearest one they all print instead (Hull
# Interchange, for two stops 1.3 km east of it), and the feeds are counted
# there too, so the check is of the routes through the case stop, at the
# timing point the documents give.
HUBS = {
    'BRI': (['149000006355'], '149000006355', 400, None,
            r'Clock Tower|North Street|Churchill Sq|Western Road|Imperial Arcade', None),
    'CHELM': (['1500AA160', '1500IM2089', '15003411303'], '1500AA160', 600, None,
              r'^Chelmsford,? (Bus St|Rail St|Railway St|Parkway|Retail Market)|'
              r'^Chelmsford (Bus|Railway) Station|^(Victoria Road South|Careers Office|'
              r'Job Centre|High Chelmer)$', None),
    'STAN': (['1500IM187U', '1500IM187R'], '1500IM187U', 100, None, r'Stansted Airport', None),
    'HULL': (['2290YHA00295', '2290YHA00296'], '2290YHA01551', 150, r'Interchange',
             r'Hull Interchange', None),
    'BHAM': (['43000202104', '43000202301', '43000211301'], '43000202104', 700, None,
             BHAM_ROWS, r'Airport|NEC|Great Barr'),
    'DUDLEY': (['43000874601'], '43000874601', 600, None,
               r'^Dudley,? (Bus Station|Interchange|Castle Hill|Town Centre|Stone St|'
               r'Ednam Rd|Ednam Road|Coronation|Zoo|Tower St|Priory Rd|Priory Road)|'
               r'^Castle Hill|^Dudley$', None),
    'SHEF': (['370070005'], '370070005', 150, None,
             r'Sheffield,? (Interchange|Intc)|^Interchange', None),
    'REGENT': (['410000060407', '410000060406', '41000008REGE', '41000008REGB'],
               '410000060407', 400, None, r'Regent Centre', None),
    'KEIGHLEY': (['450026807'], '450026807', 200, None,
                 r'Keighley,? Bus St|Keighley Bus Station', None),
    # Arriva's HTML timetables print Stevenage Bus Station (105-185 m from
    # the case stop) and Durham Bus Station (177 m from Millburngate)
    'STEV': (['210021200945'], '210021200945', 250, None,
             r'(Bus Station|Railway Station|Interchange)[^,]*, Stevenage$', None),
    'GATWICK': (['4400CY0389'], '4400CY0389', 200, None, r'North Terminal', None),
    'DUR': (['13005999D'], '13005999D', 250, None,
            r'(Bus Station|Millburngate)[^,]*, Durham$', None),
}


def first(route, day):
    return os.path.join(EX, 'first_essex_%s_%s.pdf' % (route, day))


def first_days(stem):
    return {d.upper() if d == 'mf' else d.capitalize(): first(stem, d)
            for d in ('mf', 'sa', 'su') if os.path.exists(first(stem, d))}


def ex(name):
    return {'*': os.path.join(EX, name)}


# (hub, route, files {day: path}, reader options, edition_status override)
READS = []
# Brighton & Hove, the edition in force from the operator's own archive
for r, f in [('12', 'brightonhove_BH_12-timetable-20260719-f95021d6.pdf'),
             ('12X', 'brightonhove_BH_12X-timetable-20260719-f95021d6.pdf'),
             ('N12', 'brightonhove_BH_N12-timetable-20260719-f95021d6.pdf'),
             ('12A', 'brightonhove_BH_12A-timetable-20251109-ccc2ebdc.pdf'),
             ('14', 'brightonhove_BH_14-timetable-20260719-ab46269d.pdf'),
             ('14C', 'brightonhove_BH_14C-timetable-20260201-708e27c0.pdf'),
             ('18', 'brightonhove_BH_18-timetable-20251019-61d850f3.pdf'),
             ('20', 'brightonhove_BH_20-timetable-20260614-f218c7e8.pdf'),
             ('50', 'brightonhove_BH_50-timetable-20251019-41bf41ae.pdf'),
             # the editions in force for the November check (bucket relisted
             # 14 November 2026; the others above are still current then)
             ('12', 'brightonhove_BH_12-timetable-20260927-c4003a5c.pdf'),
             ('12X', 'brightonhove_BH_12X-timetable-20260927-d0e3becb.pdf'),
             ('N12', 'brightonhove_BH_N12-timetable-20260927-68c800ee.pdf')]:
    READS.append(('BRI', r, ex(f), {'routes': [r]}))
# Chelmsford and Stansted, First Essex: editions from 30/31 August 2026
for r, stem in [('C1', 'C1'), ('C2', 'C2-C2e'), ('C3', 'C3'), ('C5', 'C5'), ('C6', 'C6'),
                ('C7', 'C7-C7E'), ('C7E', 'C7-C7E'), ('C8', 'C8'), ('C9', 'C9'), ('C10', 'C10'),
                ('C12', 'C12'), ('700', '700'), ('702', 'nov_702'), ('333', '333-375'),
                ('336', '336'), ('351', '351'), ('371', '371'), ('47', '47'), ('31', '31'),
                ('3', '3'), ('331', '331'), ('332', '332'), ('73', '73'), ('73B', '73B'),
                ('13', '13'), ('13A', '13A'), ('13B', '13B'), ('46', '46')]:
    READS.append(('CHELM', r, first_days(stem),
                  {'routes': [r], 'fri_twins': True} if r == '31' else {'routes': [r]}))
# Hedingham & Chambers' 49 (hedinghamandchambers_HEDO_49-timetable-20250831-...)
# is held but prints its stop names as graphics: there is no text row to read.
for r in ['X30', 'X10', '42A']:
    READS.append(('STAN', r, first_days(r), {'routes': [r]}))
# Hull: East Yorkshire from the operator's archive; Stagecoach current only
for r in ['56', '57']:
    READS.append(('HULL', r, ex('eyms_EY_%s-timetable-20260224-01362444.pdf' % r), {'routes': [r]}))
# Stagecoach heads its weekday tables "Mon, Tue, Wed, Thur, Fri", which the
# reader's own day patterns miss. The 14/15 sheet (XGAO015) prints no Hull
# Interchange row, so the 14 has no reading; the 15 is read from XGCO015.
SC_DAYS = [('MF', r'^mon,? tue,? wed,? thu\w*,? fri')]
for r, f in [('11', 'stagecoach_XGCO011.pdf'), ('12', 'stagecoach_XGAO012.pdf'),
             ('12A', 'stagecoach_XGCO012A.pdf'), ('13', 'stagecoach_XGAO013.pdf'),
             ('15', 'stagecoach_XGCO015.pdf'),
             ('33C', 'stagecoach_XGAO033C.pdf'), ('34', 'stagecoach_XGAO034.pdf'),
             ('40', 'stagecoach_XGAO040.pdf'), ('111', 'stagecoach_XGAO111.pdf')]:
    READS.append(('HULL', r, ex(f), {'routes': [r], 'day_extra': SC_DAYS}))
# West Midlands: NX summer editions where held, else the nearest later one
NXB = {'2': '2-birmingham-maypole', '3': '3-birmingham-yardley-wood',
       '4': '4-birmingham-solihull', '4A': '4a-birmingham-solihull', '5': '5-birmingham-solihull',
       '6': '6-birmingham-solihull', '17': '17-birmingham-chelmsley-wood',
       '17A': '17a-airportnec-birmingham', '23': '23-birmingham-bartley-green',
       '24': '24-birmingham-quinton-road-west', '35': '35-birmingham-hawkesley',
       '50': '50-birmingham-druids-heath', '80': '80-birmingham-west-bromwich',
       '97': '97-birmingham-birmingham-chelmsley-wood',
       '97A': '97a-birmingham-birmingham-airportnec', 'X20': 'x20-birmingham-bromsgrove',
       'X21': 'x21-birmingham-bartley-green', 'X22': 'x22-birmingham-bartley-green'}
NXD = {'1': '1-dudley-tettenhall-wood', '11': '11-dudley-walsall', '11A': '11a-dudley-walsall',
       '12': '12-dudley-birmingham', '126': '126-dudley-birmingham', '5A': '5a-dudley-wall-heath',
       '74': '74-birmingham-dudley', '87': '87-birmingham-dudley',
       'X8': 'x8-wolverhampton-birmingham', '81': '81-wolverhampton-dudley',
       '8': '8-wolverhampton-wollaston-farm'}
SUMMER = {'6': 'nxbus_6.pdf', '50': 'nxbus_50.pdf', '74': 'nxbus_74.pdf'}
for hub, table in [('BHAM', NXB), ('DUDLEY', NXD)]:
    for r, slug in table.items():
        cands = [SUMMER.get(r), 'nxbus_%s.pdf' % slug, 'nxbus_nov_%s.pdf' % slug]
        for c in cands:
            if c and os.path.exists(os.path.join(EX, c)):
                READS.append((hub, r, ex(c), {'routes': [r]}))
# Sheffield: First South Yorkshire, September 2026 editions
for r in ['207', '73']:
    READS.append(('SHEF', r, {d.upper() if d == 'mf' else d.capitalize():
                              os.path.join(EX, 'first_sy_%s_%s.pdf' % (r, d))
                              for d in ('mf', 'sa', 'su')
                              if os.path.exists(os.path.join(EX, 'first_sy_%s_%s.pdf' % (r, d)))},
                  {'routes': [r]}))
# Regent Centre: Go North East Q3 (the Q3X is printed with it)
READS.append(('REGENT', 'Q3X', ex('gonortheast_GNE_Q3-timetable-20260719-9bd7f957.pdf'),
              {'routes': ['Q3X']}))
# Keighley: Transdev's archive stops in 2023
READS.append(('KEIGHLEY', 'K7', ex('transdevblazefield_KDT_K7-timetable-20230903-9581cd03.pdf'), {}))
# Sheffield: Travel South Yorkshire sheets. Each table is headed by its route
# numbers, a glyph and the day ("SC1 <glyph> Saturday"); one sheet can hold
# several routes (SC1 and SC2), and bold headings can come out with every
# letter doubled ("MMoonnddaayy"). So the day patterns are built per route:
# the route's own headings get its day type, any other route's heading the
# uncounted code 'X', which also keeps that route's tables from being read as
# the previous heading's. The 95/95s sheet (29 August 2026) is held but not
# read: its Sheffield Interchange rows print symbols, not times.
def tfsy_days(route):
    mf = r'm+o+n+d+a+y+\W+t+o+\W+f+r+i+d+a+y+'
    sa = r's+a+t+u+r+d+a+y+'
    su = r's+u+n+d+a+y+'
    own = r'^%s(?![a-z0-9])[^a-z]*' % re.escape(route.lower())
    other = r'^[a-z]*\d+[a-z]*(?![a-z0-9])[^a-z]*'
    return [('MF', own + mf), ('Sa', own + sa), ('Su', own + su),
            ('X', other + '(' + mf + '|' + sa + '|' + su + ')')]


for r, f, ed in [('181', '181-Sheffield-valid-from-24-July-2023-(PDF-360kb).pdf', '2023-07-24'),
                 ('SC1', 'SC1-SC2-Sheffield-valid-from-17-November-2024-(PDF-541kb).pdf', '2024-11-17'),
                 ('SC2', 'SC1-SC2-Sheffield-valid-from-17-November-2024-(PDF-541kb).pdf', '2024-11-17')]:
    READS.append(('SHEF', r, ex(f), {'day_extra': tfsy_days(r), 'edition': ed}))
# Hull: Stagecoach editions of 6 September 2026 ("060926" in the file name);
# the current XGAO015 sheet prints no Interchange row for the 14. The 7/8
# sheet (Hu_007 008 060926.pdf) is held but not read: the 7 and 8 run through
# at Hull Interchange ("continues as service 8") and the 8 is printed with
# its 8C short workings, so its journeys at the Interchange cannot be counted
# by route without guessing how the feeds file the 8C.
for r, f in [('14', 'Hu_014 016 060926.pdf')]:
    READS.append(('HULL', r, ex(f), {'routes': [r], 'edition': '2026-09-06'}))
# Gatwick Hoppa: the operator's Ticketer widget, for Tuesday 28 July 2026
# (ticketer_dl.py). Weekday only: the portal's firewall refused the weekend.
READS.append(('GATWICK', 'GH1', {'MF': os.path.join(EX, 'gatwickhoppa', 'GH1_MF.html')},
              {'format': 'ticketer', 'edition': '2026-07-28', 'in_force': True}))

# Arriva: HTML timetables, one file per day type and direction, saved by
# arriva_dl.py (no PDFs are published). Current editions only.
ARR = os.path.join(EX, 'arriva')
ARR_DATES = {}
if os.path.exists(os.path.join(ARR, 'dates.txt')):
    ARR_DATES = dict(x.split('=') for x in open(os.path.join(ARR, 'dates.txt')).read().split())
for hub, routes in [('REGENT', {'43': 'NMS_BH_43', '44': 'NMS_BH_44', '45': 'NMS_BH_45',
                                'X9': 'NMS_BH_X9', 'X10': 'NMS_BH_X10', 'X11': 'NMS_BH_X11',
                                'X14': 'NMS_AN_X14', 'X15': 'NMS_AN_X15', 'X16': 'NMS_AN_X16',
                                'X18': 'NMS_AN_X18', 'X20': 'NMS_AN_X20', 'X21': 'NMS_AN_X21',
                                'X22': 'NMS_AN_X22', 'X30': 'NMS_AN_X30'}),
                    ('DUR', {'24': 'DC_DM_24'}),
                    ('STEV', {r: 'AKE_BR_' + r for r in
                              ['SB1', 'SB2', 'SB3', 'SB4', 'SB5', 'SB7', 'SB8', 'SB50',
                               '55', '301', '400']})]:
    for r, code in routes.items():
        files = {'%s/%s' % (d, io): os.path.join(ARR, '%s_%s_%s.html' % (code, d, io))
                 for d in ('MF', 'Sa', 'Su') for io in ('out', 'in')}
        if all(os.path.exists(f) for f in files.values()):
            READS.append((hub, r, files, {'format': 'arriva', 'routes': [r],
                                          'edition': ARR_DATES.get('MF', '')}))

# Collected from the operator's site during the window (July 2026, for the
# zone checks), so in force although not from an archive: NXWM's 19 July
# editions, whose successors start on 30 August.
# West Midlands Bus timetables printed with every journey twice. The
# November 2026 sheets for these routes show pairs of columns leaving the
# same stop at the same minute and differing only in a stop or two (route
# 17A: two journeys from Birmingham International at 04:47). TNDS and the
# BODS TransXChange archive each carry one (one 04:47); the DfT's BODS GTFS
# carries three. The operator's sheets look generated from its own data with
# both its 1 and 15 November versions in force - the same doubling BODS GTFS
# shows - so they count twice what is run and cannot judge the feeds. Kept
# in the table, marked unreliable. See reports/gtfs_iteration_nov2026.md.
PRINTED_TWICE = {'nxbus_nov_2-birmingham-maypole.pdf', 'nxbus_nov_3-birmingham-yardley-wood.pdf',
                 'nxbus_nov_4-birmingham-solihull.pdf', 'nxbus_nov_5-birmingham-solihull.pdf',
                 'nxbus_nov_17-birmingham-chelmsley-wood.pdf',
                 'nxbus_nov_17a-airportnec-birmingham.pdf',
                 'nxbus_nov_35-birmingham-hawkesley.pdf'}

COLLECTED_IN_WINDOW = {'nxbus_6.pdf', 'nxbus_14.pdf', 'nxbus_50.pdf', 'nxbus_50-1.pdf',
                       'nxbus_74.pdf'}

MONTHS = ['january', 'february', 'march', 'april', 'may', 'june', 'july', 'august',
          'september', 'october', 'november', 'december']


def edition_of(path):
    """Edition start date: from the archive file name, else the document."""
    m = re.search(r'-timetable-(\d{4})(\d{2})(\d{2})-', os.path.basename(path))
    if m:
        return '%s-%s-%s' % m.groups()
    t = subprocess.run(['pdftotext', '-l', '2', path, '-'], capture_output=True,
                       text=True, errors='ignore').stdout
    m = re.search(r'Valid from (\d\d)/(\d\d)/(\d{4})', t)
    if m:
        return '%s-%s-%s' % (m.group(3), m.group(2), m.group(1))
    m = re.search(r'[Vv]alid from (?:\w+day )?(\d{1,2})(?:st|nd|rd|th)? (\w+) (\d{4})', t) or \
        re.search(r'[Ff]rom (\d{1,2})(?:st|nd|rd|th)? (\w+) (\d{4})', t)
    mon = [x[:3] for x in MONTHS]
    if m and m.group(2).lower()[:3] in mon:
        return '%s-%02d-%02d' % (m.group(3), mon.index(m.group(2).lower()[:3]) + 1, int(m.group(1)))
    return ''


def edition_status(ed, archive):
    """In force over the window, an earlier edition, or one from after it.

    An archive edition (Go-Ahead's bucket keeps every edition) dated on or
    before the window start is the one in force, because the picker took the
    latest such and checked none starts inside the window. A document from an
    operator's current site dated before the window is only known not to be
    later, so it is "earlier edition"."""
    if not ed:
        return 'unknown edition'
    if ed > WIN1:
        return 'later edition'
    if ed > WIN0:
        return 'changed in window'
    return 'in force' if archive else 'earlier edition'


def arriva_table(path):
    """Rows of an Arriva HTML timetable: (stop code, stop label, cells), where
    cells[j] is True when journey (column) j calls there."""
    import html as H
    s = open(path, encoding='utf-8', errors='ignore').read()
    rows = []
    for tr in re.findall(r'<tr[^>]*>(.*?)</tr>', s, re.S):
        m = re.search(r'href="/stops/([^"]+)".*?title="View departure board for ([^"]+)"', tr, re.S)
        if not m:
            continue
        cells = [bool(re.search(r'\d{1,2}:\d{2}', c))
                 for c in re.findall(r'<td[^>]*>(.*?)</td>', tr, re.S)]
        rows.append((m.group(1), H.unescape(re.sub(r'\s+', ' ', m.group(2))).strip(), cells))
    return rows


def arriva_services(path):
    """Service number of each journey column. Arriva prints related routes
    in one table (X10 with X11, SB4 with SB5 and SB50) and heads every column
    with its service."""
    s = open(path, encoding='utf-8', errors='ignore').read()
    m = re.search(r'<thead.*?</thead>', s, re.S)
    if not m:
        return []
    return [x.strip().upper() for x in
            re.findall(r'<th scope="col".*?Service</span>\s*([^<]+)</span>', m.group(0), re.S)]


def read_arriva(files, pat, excl, routes=None):
    """Journeys per day type calling at any row matching `pat`, both
    directions summed. A file saying the service does not run that day or in
    that direction counts 0; one that holds no table for another reason is
    flagged."""
    rp = re.compile(pat)
    rx = re.compile(excl) if excl else None
    per, quals, labs = {}, set(), set()
    for key, f in files.items():
        day = key.split('/')[0]
        rows = arriva_table(f)
        if not rows:
            txt = open(f, encoding='utf-8', errors='ignore').read()
            if 'does not run' not in txt and "aren&#039;t any timetables" not in txt:
                quals.add('unexpanded:no table in ' + os.path.basename(f))
            per[day] = per.get(day, 0)
            continue
        hit = [r for r in rows if rp.search(r[1]) and not (rx and rx.search(r[1]))]
        ncol = max(len(r[2]) for r in rows)
        svc = arriva_services(f)
        keep = range(ncol)
        if routes and len(svc) == ncol:
            keep = [j for j in range(ncol) if svc[j] in {x.upper() for x in routes}]
        elif routes and svc:
            quals.add('unexpanded:service headers do not match columns in ' + os.path.basename(f))
        n = sum(1 for j in keep if any(j < len(r[2]) and r[2][j] for r in hit))
        per[day] = per.get(day, 0) + n
        labs |= {r[1] for r in hit}
    if not labs:
        return None, 0, 0, quals, labs, False
    ok = not any(q.startswith('unexpanded') for q in quals)
    return per.get('MF', 0), per.get('Sa', 0), per.get('Su', 0), quals, labs, ok


def read_ticketer(files, pat, excl):
    """Journeys per day type at rows matching `pat` in a Ticketer widget
    timetable. The day is split into groups (<tbody>) of up to 15 journeys
    that repeat the stop list; a journey is a column within its group."""
    import html as H
    rp = re.compile(pat)
    per, labs = {}, set()
    for day, f in files.items():
        s = open(f, encoding='utf-8', errors='ignore').read()
        n = 0
        for body in re.findall(r'<tbody[^>]*>(.*?)</tbody>', s, re.S):
            cols = set()
            for tr in re.findall(r'<tr[^>]*>(.*?)</tr>', body, re.S):
                m = re.search(r'th-text.*?</span>\s*([^<]+)</a>', tr, re.S)
                if not m:
                    continue
                lab = H.unescape(m.group(1)).strip()
                if not rp.search(lab):
                    continue
                labs.add(lab)
                tds = re.findall(r'<td[^>]*>\s*([^<]*?)\s*</td>', tr)
                cols |= {j for j, x in enumerate(tds) if re.match(r'\d{1,2}:\d{2}', x)}
            n += len(cols)
        per[day] = n
    if not labs:
        return None, None, None, set(), labs, False
    return per.get('MF'), per.get('Sa'), per.get('Su'), set(), labs, True


def read_one(files, pat, excl, opt):
    if opt.get('format') == 'ticketer':
        return read_ticketer(files, pat, excl)
    if opt.get('format') == 'arriva':
        return read_arriva(files, pat, excl, opt.get('routes'))
    per, quals, labs = {}, set(), set()
    for day, f in files.items():
        b = T.parse(f, day_override=None if day == '*' else day, day_extra=opt.get('day_extra'))
        if day != '*':
            for x in b:
                x['day'] = day
        # First Essex prints each weekday journey of route 31 twice, an
        # unmarked Monday-Thursday column and a "Fri" (Fridays only) twin at
        # the same times, so each time is counted once
        r = T.count(b, pat, routes=opt.get('routes'), row_exclude=excl,
                    distinct_times=bool(opt.get('fri_twins')))
        for dd, v in r.items():
            per[dd] = per.get(dd, 0) + v['n']
            quals |= v['qualifiers']
            labs |= v['rows']
    if 'MF' in per:
        mf = per['MF']
    elif 'MT' in per or 'Fr' in per:
        mt = per.get('MT', 0)
        mf = (4 * mt + per.get('Fr', mt)) / 5
    elif 'MS' in per:
        mf = per['MS']
        per.setdefault('Sa', per['MS'])
    elif per:
        mf = 0          # a route that does not run Monday to Friday
    else:
        mf = None
    reliable = (mf is not None and None not in per and
                not any(q.startswith(('unexpanded', 'gap-without')) for q in quals))
    return mf, per.get('Sa', 0), per.get('Su', 0), quals, labs, reliable


def zone_rows():
    """Readings from the zone checks whose zone holds a case stop."""
    zones = {
        'E01016969': ['149000006355'], 'E01031575': ['4400CY0389'],
        'E01033140': ['15003411303'], 'E01034092': ['1500AA160', '1500IM2089'],
        'E01009757': ['43000874601'], 'E01033615': ['43000202301'],
        'E01033561': ['43000202104'], 'E01034947': ['43000211301'],
    }
    out = []
    for z in csv.DictReader(open(os.path.join(REPO, 'data', 'zone_pdf_validation.csv'),
                                 encoding='utf-8')):
        if z['zone'] not in zones or z['reliable'] != 'True':
            continue
        d = ast.literal_eval(z['document_journeys_per_day'])
        if 'MF' in d:
            mf = d['MF']
        elif 'MT' in d:
            mf = (4 * d['MT'] + d.get('Fr', d['MT'])) / 5
        else:
            continue
        ed = z['edition'][:10] if re.match(r'\d{4}-\d{2}-\d{2}', z['edition']) else ''
        arch = (bool(re.search(r'-timetable-\d{8}-', z['document'])) or
                z['document'] in COLLECTED_IN_WINDOW)
        for cs in zones[z['zone']]:
            out.append(dict(case_stop=cs, route=z['route'].upper(), document=z['document'],
                            edition_from=ed, edition_status=edition_status(ed, arch),
                            read_at='zone ' + z['zone'] + ' (' + z['basis'] + ')',
                            read_centre='', read_radius_m='', read_name='', read_zone=z['zone'],
                            MF=mf, Sa=d.get('Sa', 0), Su=d.get('Su', 0),
                            basis='zone check', reliable=True, note=''))
    return out


def notice_rows():
    """Readings from an operator's own notice rather than a timetable.

    Gatwick Hoppa's GH1 page (saved as "Gatwick Hoppa LTD _ GH1.htm"): "New
    updated timetable will go live 23rd May 2026 ... just the GH1 route". The
    GH2 is withdrawn from before the window, so its timetable is zero
    journeys; both feeds still carry it. The widget has no GH2 for July."""
    out = []
    for cs in HUBS['GATWICK'][0]:
        out.append(dict(case_stop=cs, route='GH2',
                        document='Gatwick Hoppa LTD _ GH1.htm (service notice)',
                        edition_from='2026-05-23', edition_status='in force',
                        read_at='operator notice: just the GH1 route from 23 May 2026',
                        read_centre=HUBS['GATWICK'][1], read_radius_m=HUBS['GATWICK'][2],
                        read_name='', read_zone='', MF=0, Sa=0, Su=0,
                        basis='operator notice', reliable=True, note='withdrawn'))
    return out


def by_eye_rows():
    """Readings counted by eye from documents with no text layer.

    East Yorkshire's 6 September 2026 edition of the 56/57 sheet is images
    only (pdftotext returns nothing; no OCR is installed). Rendered with
    pypdfium2 and counted column by column: every journey with a time at
    either Hull Interchange row, both directions, the 56 and 57 apart, as the
    reader would count them. The February edition read 78/69/32 and 81/73/33,
    so the new edition mainly adds Sunday journeys."""
    counts = {'56': (83, 72, 50), '57': (86, 73, 53)}
    cases, centre, radius, fname, pat, excl = HUBS['HULL']
    out = []
    for r, (mf, sa, su) in counts.items():
        for cs in cases:
            out.append(dict(case_stop=cs, route=r,
                            document='eyms_EY_%s-timetable-20260906-a7cbe3f3.pdf' % r,
                            edition_from='2026-09-06',
                            edition_status=edition_status('2026-09-06', True),
                            read_at='Hull Interchange (counted by eye)', read_centre=centre,
                            read_radius_m=radius, read_name=fname or '', read_zone='',
                            MF=mf, Sa=sa, Su=su, basis='by eye', reliable=True,
                            note='image-only PDF, counted by eye'))
    return out


def main(show=None):
    rows = []
    for hub, route, files, opt in READS:
        if not files:
            continue
        cases, centre, radius, fname, pat, excl = HUBS[hub]
        if show and hub != show:
            continue
        mf, sa, su, quals, labs, ok = read_one(files, pat, excl, opt)
        path = list(files.values())[0]
        ed = opt.get('edition') or edition_of(path)
        arch = (bool(re.search(r'-timetable-\d{8}-', os.path.basename(path))) or
                os.path.basename(path) in COLLECTED_IN_WINDOW or bool(opt.get('in_force')))
        doc = '; '.join(sorted(os.path.basename(p) for p in files.values()))
        print(hub, route, doc[:50], 'MF', mf, 'Sa', sa, 'Su', su, ed, sorted(quals)[:2],
              '| rows:', '; '.join(sorted(labs))[:120], flush=True)
        if mf is None or not labs:
            continue
        for cs in cases:
            rows.append(dict(case_stop=cs, route=route, document=doc, edition_from=ed,
                             edition_status=('in force' if opt.get('in_force')
                                             else edition_status(ed, arch)),
                             read_at='; '.join(sorted(labs))[:200], read_centre=centre,
                             read_radius_m=radius, read_name=fname or '', read_zone='', MF=round(mf, 2), Sa=sa, Su=su,
                             basis='expanded' if any('expanded' in q for q in quals) else 'explicit',
                             reliable=ok and doc not in PRINTED_TWICE,
                             note=('every journey printed twice; ' if doc in PRINTED_TWICE else '') +
                             '; '.join(sorted(quals))[:200]))
    if show:
        return
    rows += zone_rows() + notice_rows() + by_eye_rows()
    cols = ['case_stop', 'route', 'document', 'edition_from', 'edition_status', 'read_at',
            'read_centre', 'read_radius_m', 'read_name', 'read_zone', 'MF', 'Sa', 'Su', 'basis',
            'reliable', 'note']
    with open(OUT, 'w', newline='', encoding='utf-8') as f:
        w = csv.DictWriter(f, fieldnames=cols)
        w.writeheader()
        w.writerows(rows)
    print(len(rows), 'rows to', OUT)


if __name__ == '__main__':
    main(sys.argv[2] if len(sys.argv) > 2 and sys.argv[1] == '--show' else None)
