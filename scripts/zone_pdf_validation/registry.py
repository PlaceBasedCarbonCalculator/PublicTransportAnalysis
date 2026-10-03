import paths
import glob, os, re
SP = paths.WORK
EX = paths.REPO + 'data/example_timetables/'

G = {
 'BHM': ['E01033620', 'E01033617', 'E01033561', 'E01033615', 'E01034947', 'E01010125'],
 'BC': ['E01034313', 'E01010102', 'E01010106', 'E01010368', 'E01009757'],
 'CHELM': ['E01034091', 'E01034092', 'E01033140', 'E01021592', 'E01021587', 'E01021542'],
 'READ': ['E01033415', 'E01033420'],
 'CRAW': ['E01031575', 'E01031585', 'E01031583'],
 'PORTS': ['E01017032', 'E01017034'],
 'WEY': ['E01020554'], 'HULL': ['E01033104'], 'BRI': ['E01016952', 'E01016969'],
 'SOTON': ['E01017191'], 'AYL': ['E01032955'], 'EDI': ['S01014636', 'S01014958'],
 'SWA': ['W01001955'], 'LANCS': ['E01024940', 'E01033223'],
}

docs = []

def add(key, routes, group, files, operator, edition=None, **kw):
    docs.append(dict(key=key, routes=routes, zones=G[group], files=files,
                     operator=operator, edition=edition, **kw))

# --- National Express West Midlands: one PDF per route, all day types inside
nx_routes = {
 '97-birmingham-birmingham-chelmsley-wood': ['97', '97A'], '97a-birmingham-birmingham-airportnec': ['97A'],
 '9-birmingham-stourbridge': ['9'], '95-birmingham-chelmsley-wood': ['95', '94'],
 '96-kingstanding-chelmsley-wood': ['96'], '87-birmingham-dudley': ['87'],
 '35-birmingham-hawkesley': ['35'], '4-birmingham-solihull': ['4'], '4a-birmingham-solihull': ['4A'],
 '5-birmingham-solihull': ['5'], '24-birmingham-quinton-road-west': ['24'],
 '23-birmingham-bartley-green': ['23'], '82-birmingham-bearwood': ['82'],
 '101-birmingham-handsworth-the-leveretts': ['101'], '126-dudley-birmingham': ['126'],
 'x21-birmingham-bartley-green': ['X21'], 'x22-birmingham-bartley-green': ['X22'],
 '17-birmingham-chelmsley-wood': ['17'], '17a-airportnec-birmingham': ['17A'],
 'x12-birmingham-solihull-limited-stop': ['X12'], 'x13-birmingham-city-centre-chelmsley-wood': ['X13'],
 '47-birmingham-longbridge': ['47'], '79-wolverhampton-west-bromwich': ['79'],
 '529-wolverhampton-walsall': ['529'], '530-wolverhampton-rocket-pool': ['530'],
 'x8-wolverhampton-birmingham': ['X8'], 'x51-birmingham-cannock-limited-stop': ['X51'],
 '59-wolverhampton-ashmore-park': ['59'], '82-wolverhampton-dudley': ['82'],
 '9-walsall-wolverhampton': ['9'], '16-wolverhampton-stourbridge': ['16'],
 '6-birmingham-solihull': ['6'], '14-birmingham-chelmsley-wood': ['14'],
 '50-birmingham-druids-heath': ['50'], '74-birmingham-dudley': ['74'],
}
for slug, routes in nx_routes.items():
    f = SP + 'nx/' + slug + '.pdf'
    if os.path.exists(f):
        grp = 'BC' if 'wolverhampton' in slug or 'walsall' in slug else 'BHM'
        if slug in ('87-birmingham-dudley', '74-birmingham-dudley', '126-dudley-birmingham', 'x8-wolverhampton-birmingham', 'x51-birmingham-cannock-limited-stop', '82-birmingham-bearwood'):
            grp = 'BHM'
            add('NX_' + slug, routes, 'BC', {'*': f}, 'National Express West Midlands')
        add('NX_' + slug, routes, grp, {'*': f}, 'National Express West Midlands')

# summer editions already held (downloaded 2 Aug 2026, "From 19th July 2026")
for r, f in [('6', 'nxbus_6.pdf'), ('14', 'nxbus_14.pdf'), ('50', 'nxbus_50.pdf'), ('74', 'nxbus_74.pdf')]:
    add('NXS_' + r, [r], 'BHM', {'*': EX + f}, 'National Express West Midlands', '2026-07-19')
add('NXS_74', ['74'], 'BC', {'*': EX + 'nxbus_74.pdf'}, 'National Express West Midlands', '2026-07-19')

# --- passenger platform (Go-Ahead, Reading, EYMS, Redline): file name carries the edition
pmap = {'readingbuses_RBUS': ('READ', 'Reading Buses'), 'eyms_EY': ('HULL', 'East Yorkshire'),
        'brightonhove_BH': ('BRI', 'Brighton & Hove'), 'bluestar_BLUS': ('SOTON', 'Bluestar'),
        'redgroup_RLNE': ('AYL', 'Redline'), 'metrobus_MB': ('CRAW', 'Metrobus')}
for f in sorted(glob.glob(SP + 'passenger/*.pdf')):
    b = os.path.basename(f)
    m = re.match(r'(\w+?_[A-Z]+)_(.+)-timetable-(\d{8})-', b)
    if not m or m.group(1) not in pmap:
        continue
    grp, op = pmap[m.group(1)]
    ed = m.group(3); ed = f'{ed[:4]}-{ed[4:6]}-{ed[6:]}'
    add('P_' + b[:-4], [m.group(2)], grp, {'*': f}, op, ed)

# --- First Bus API PDFs: one file per day type
first_groups = {'7': 'CHELM', '12': 'PORTS', '6': 'WEY', '21': 'SWA'}
fdocs = {}
for f in sorted(glob.glob(SP + 'first/first_o*.pdf')):
    m = re.match(r'first_o(\d+)_(.+)_(mf|mh|fr|sa|su)\.pdf', os.path.basename(f))
    if not m:
        continue
    fdocs.setdefault((m.group(1), m.group(2)), {})[{'mf': 'MF', 'mh': 'MT', 'fr': 'Fr', 'sa': 'Sa', 'su': 'Su'}[m.group(3)]] = f
for (op, svc), files in fdocs.items():
    routes = svc.replace('C2-C2e', 'C2-C2E').upper().split('-')
    if svc == 'C7-C7E': routes = ['C7', 'C7E']
    if svc == '333-375': routes = ['333', '375']
    if svc == '10-10A': routes = ['10', '10A']
    if svc == '4-4A': routes = ['4', '4A']
    if svc == 'X3-X4-X5': routes = ['X3', 'X4', 'X5']
    add(f'F{op}_{svc}', routes, first_groups[op], files, 'First Bus')

# --- Lothian timing sheets (edition from file name code)
lo = {'03_26e02r22': (['3'], '2026-02-22'), '31_26g02d22': (['31'], '2026-02-22'),
      '29_X29_26a02d22': (['29'], '2026-02-22'), '37_X37_25b09j07': (['37'], '2025-09-07'),
      '07_25g09u07': (['7'], '2025-09-07'), '27_25d09t07': (['27'], '2025-09-07'),
      '47_47B_25f09y07': (['47'], '2025-09-07'), '49_25b09k07': (['49'], '2025-09-07'),
      '08_25g04F06': (['8'], '2025-04-06'), '21_25s04D06': (['21'], '2025-04-06')}
for k, (r, ed) in lo.items():
    add('L_' + k, r, 'EDI', {'*': SP + 'lothian/' + k + '.pdf'}, 'Lothian', ed)

# --- Stagecoach 125 Preston - Bolton, already held (edition May 2026, in force)
add('EX_SC125', ['125'], 'LANCS', {'*': EX + 'C&L 125 0526 WEB.pdf'}, 'Stagecoach', '2026-05')
