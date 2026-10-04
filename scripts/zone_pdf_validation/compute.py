"""PDF journeys at a reference zone, scaled to the 28-day window, against the
TNDS and BODS GTFS counts for the same route in the same zone."""
import re, json, collections
import pandas as pd
import ttread as T
from review import blocks_for, runs
from registry import docs, SP

DOCS = {d['key']: d for d in docs}
WINDOW = {'MT': 16, 'Fr': 4, 'MF': 20, 'Sa': 4, 'Su': 4, 'MS': 24}

BHAM = r"^Birmingham (Moor St|Priory|Carrs|Colmore|City Centre Old Square|Corporation|High Street)|^Bus Mall"
CHELM_BS = r'^Chelmsford, Bus Stn'
FIRST_SCH = r'^(SCH|SD|Sch|SchD|S)$'

# (doc, route as named in the zone table, zone, row pattern, options)
C = [
 # --- Birmingham city centre: summer edition (window) and autumn edition
 ('NXS_6', '6', 'E01033620', BHAM, {}), ('NX_6-birmingham-solihull', '6', 'E01033620', BHAM, {}),
 ('NXS_14', '14', 'E01033561', BHAM, {}), ('NX_14-birmingham-chelmsley-wood', '14', 'E01033561', BHAM, {}),
 ('NXS_14', '14', 'E01010125', r'^Chelmsley Interchange', {}),
 ('NXS_50', '50', 'E01033561', BHAM, {}), ('NX_50-birmingham-druids-heath', '50', 'E01033561', BHAM, {}),
 ('NXS_74', '74', 'E01033620', BHAM, {}), ('NX_74-birmingham-dudley', '74', 'E01033620', BHAM, {}),
 ('NXS_74', '74', 'E01010102', r'^West Bromwich Bus Station', {}),
 ('NX_74-birmingham-dudley', '74', 'E01010102', r'^West Bromwich Bus Station', {}),
 ('NX_97-birmingham-birmingham-chelmsley-wood', '97', 'E01033620', BHAM, {'routes': ['97']}),
 ('NX_9-birmingham-stourbridge', '9', 'E01033620', BHAM, {}),
 ('NX_95-birmingham-chelmsley-wood', '95', 'E01033561', BHAM, {'routes': ['95']}),
 ('NX_95-birmingham-chelmsley-wood', '94', 'E01033617', BHAM, {'routes': ['94']}),
 ('NX_95-birmingham-chelmsley-wood', '95', 'E01010125', r'^Chelmsley (Wood )?Interchange', {'routes': ['95']}),
 ('NX_96-kingstanding-chelmsley-wood', '96', 'E01010125', r'^Chelmsley (Wood )?Interchange', {}),
 ('NX_87-birmingham-dudley', '87', 'E01033620', BHAM, {'routes': ['87']}),
 ('NX_87-birmingham-dudley', '82', 'E01033620', BHAM, {'routes': ['82']}),
 ('NX_87-birmingham-dudley', '87', 'E01009757', r'^Dudley Ednam Road', {'routes': ['87']}),
 ('NX_82-wolverhampton-dudley', '82', 'E01009757', r'^Dudley Priory Road', {}),
 ('NX_35-birmingham-hawkesley', '35', 'E01033615', BHAM, {}),
 ('NX_4-birmingham-solihull', '4', 'E01033620', BHAM, {'routes': ['4']}),
 ('NX_4-birmingham-solihull', '4A', 'E01033620', BHAM, {'routes': ['4A']}),
 ('NX_5-birmingham-solihull', '5', 'E01033620', BHAM, {}),
 ('NX_24-birmingham-quinton-road-west', '24', 'E01033620', BHAM, {'routes': ['24']}),
 ('NX_24-birmingham-quinton-road-west', '23', 'E01033620', BHAM, {'routes': ['23']}),
 ('NX_101-birmingham-handsworth-the-leveretts', '101', 'E01033620', BHAM, {}),
 ('NX_126-dudley-birmingham', '126', 'E01033620', BHAM, {}),
 ('NX_126-dudley-birmingham', '126', 'E01009757', r'^Dudley Ednam Road', {}),
 ('NX_x21-birmingham-bartley-green', 'X21', 'E01033620', BHAM, {'routes': ['X21']}),
 ('NX_x21-birmingham-bartley-green', 'X22', 'E01033620', BHAM, {'routes': ['X22']}),
 ('NX_x21-birmingham-bartley-green', 'X20', 'E01033620', BHAM, {'routes': ['X20']}),
 ('NX_17-birmingham-chelmsley-wood', '17', 'E01033561', BHAM, {'routes': ['17']}),
 ('NX_17-birmingham-chelmsley-wood', '17A', 'E01033561', BHAM, {'routes': ['17A']}),
 ('NX_x12-birmingham-solihull-limited-stop', 'X12', 'E01010125', r'^Chelmsley Interchange', {'routes': ['X12']}),
 ('NX_x12-birmingham-solihull-limited-stop', 'X13', 'E01033617', BHAM, {'routes': ['X13']}),
 ('NX_x8-wolverhampton-birmingham', 'X8', 'E01033620', BHAM, {'routes': ['X8']}),
 ('NX_x51-birmingham-cannock-limited-stop', 'X51', 'E01010368', r'^WALSALL Bus Station', {}),
 ('NX_x51-birmingham-cannock-limited-stop', 'X51', 'E01033617', BHAM, {}),
 # --- Black Country bus stations
 ('NX_79-wolverhampton-west-bromwich', '79', 'E01034313', r'^Wolverhampton Bus Station', {}),
 ('NX_79-wolverhampton-west-bromwich', '79', 'E01010102', r'^West Bromwich Bus Station', {}),
 ('NX_529-wolverhampton-walsall', '529', 'E01034313', r'^Wolverhampton Bus Station', {}),
 ('NX_529-wolverhampton-walsall', '529', 'E01010368', r'^Walsall Bus Station', {}),
 ('NX_59-wolverhampton-ashmore-park', '59', 'E01034313', r'^Wolverhampton Bus Station', {}),
 ('NX_9-walsall-wolverhampton', '9', 'E01034313', r'^Wolverhampton Bus Station', {'routes': ['9']}),
 ('NX_16-wolverhampton-stourbridge', '16', 'E01034313', r'^Wolverhampton Bus Station', {'routes': ['16']}),
 # --- Reading (summer or window-valid editions)
 *[(k, r, z, r'^(Central Reading|C Reading|Reading Station|Central)', {'routes': [r]} if r in ('4', '50') else {}) for k, r, z in [
   ('P_readingbuses_RBUS_17-timetable-20260720-c8bc5231', '17', 'E01033415'),
   ('P_readingbuses_RBUS_5-timetable-20260601-52302a4c', '5', 'E01033415'),
   ('P_readingbuses_RBUS_6-timetable-20260601-5e23c016', '6', 'E01033415'),
   ('P_readingbuses_RBUS_26-timetable-20260105-4e189325', '26', 'E01033415'),
   ('P_readingbuses_RBUS_21-timetable-20250901-6b3c0712', '21', 'E01033415'),
   ('P_readingbuses_RBUS_3-timetable-20250519-5821fd74', '3', 'E01033415'),
   ('P_readingbuses_RBUS_600-timetable-20260105-1d4faf9b', '600', 'E01033415'),
   ('P_readingbuses_RBUS_33-timetable-20260105-1756000a', '33', 'E01033415'),
   ('P_readingbuses_RBUS_11-timetable-20260105-684c892d', '11', 'E01033415'),
   ('P_readingbuses_RBUS_500-timetable-20240902-63b6a01d', '500', 'E01033415'),
   ('P_readingbuses_RBUS_16-timetable-20260105-68aeec4d', '16', 'E01033415'),
   ('P_readingbuses_RBUS_1-timetable-20260105-9fe0283c', '1', 'E01033415'),
   ('P_readingbuses_RBUS_4-timetable-20250106-d38cdd0f', '4', 'E01033415'),
   ('P_readingbuses_RBUS_18-timetable-20250901-6532a793', '18', 'E01033415'),
   ('P_readingbuses_RBUS_29-timetable-20260720-8b3c0aeb', '29', 'E01033415'),
   ('P_readingbuses_RBUS_28-timetable-20260720-d9836376', '28', 'E01033415'),
   ('P_readingbuses_RBUS_25-timetable-20260720-c897aa84', '25', 'E01033415'),
   ('P_readingbuses_RBUS_50-timetable-20260105-b2d13319', '50', 'E01033415'),
   ('P_readingbuses_RBUS_9-timetable-20250519-796a5bca', '9', 'E01033420')]],
 # --- Hull (EYMS, edition 24 Feb 2026, in force for the window)
 *[(k, r, 'E01033104', r'^(Hull Interchange|Hull Carr Lane|Carr Lane|Ferensway)', {'routes': [r]}) for k, r in [
   ('P_eyms_EY_57-timetable-20260224-01362444', '57'), ('P_eyms_EY_56-timetable-20260224-01362444', '56'),
   ('P_eyms_EY_45-timetable-20260224-a127c438', '45'), ('P_eyms_EY_51-timetable-20260224-96b2fcea', '51'),
   ('P_eyms_EY_58-timetable-20260224-8870f29a', '58'), ('P_eyms_EY_X46-timetable-20260224-47a68643', 'X46'),
   ('P_eyms_EY_104-timetable-20260224-8807c385', '104'), ('P_eyms_EY_54-timetable-20260224-6cc27ec1', '54'),
   ('P_eyms_EY_35-timetable-20260224-581cc7f6', '35')]],
 # --- Brighton & Hove
 *[(k, r, z, p, {'routes': [r]}) for k, r, z, p in [
   ('P_brightonhove_BH_18-timetable-20251019-61d850f3', '18', 'E01016952', r'(Churchill Square|North Street|Old Steine)'),
   ('P_brightonhove_BH_50-timetable-20251019-41bf41ae', '50', 'E01016969', r'(Royal Pavilion|Old Steine|Brighton Station)'),
   ('P_brightonhove_BH_20-timetable-20260614-f218c7e8', '20', 'E01016969', r'(Imperial Arcade|Old Steine|Brighton Station)'),
   ('P_brightonhove_BH_12A-timetable-20251109-ccc2ebdc', '12A', 'E01016969', r'(Old Steine|Clock Tower|Brighton Station)'),
   ('P_brightonhove_BH_25-timetable-20260614-fbf21cce', '25', 'E01016969', r'(Royal Pavilion|Old Steine)'),
   ('P_brightonhove_BH_14-timetable-20260719-ab46269d', '14', 'E01016969', r'(Brighton Station|Old Steine)'),
   ('P_brightonhove_BH_12-timetable-20260719-f95021d6', '12', 'E01016969', r'(Brighton Station|Old Steine)')]],
 # --- Southampton (Bluestar), Aylesbury (Redline)
 ('P_bluestar_BLUS_17-timetable-20260223-ef4e05d6', '17', 'E01017191', r'^Central Station North Side', {}),
 ('P_bluestar_BLUS_18-timetable-20251107-c592b958', '18', 'E01017191', r'^Central Station North Side', {}),
 ('P_redgroup_RLNE_130-timetable-20251217-766242d8', '130', 'E01032955', r'^Aylesbury,? Bus Station', {'routes': ['130']}),
 ('P_redgroup_RLNE_300-timetable-20251217-766242d8', '300', 'E01032955', r'^Aylesbury,? Bus Station', {'routes': ['300']}),
 ('P_redgroup_RLNE_4-timetable-20260711-be141bf8', '4', 'E01032955', r'^Aylesbury,? Bus Station', {}),
 # --- Chelmsford (First Essex)
 *[('F7_' + s, r, 'E01034091', CHELM_BS, {'drop_note': FIRST_SCH, 'routes': rr}) for s, r, rr in [
   ('C1', 'C1', ['C1']), ('C2-C2e', 'C2', ['C2', 'C2E', 'C2e']), ('C3', 'C3', ['C3']), ('C5', 'C5', ['C5']),
   ('C7-C7E', 'C7', ['C7', 'C7E']), ('C8', 'C8', ['C8']), ('C10', 'C10', ['C10']), ('X10', 'X10', ['X10']),
   ('X30', 'X30', ['X30']), ('351', '351', ['351']), ('170', '170', ['170']), ('336', '336', ['336']),
   ('333-375', '333', ['333'])]],
 ('F7_C9', 'C9', 'E01034092', r'^Chelmsford, Rail Stn', {'drop_note': FIRST_SCH}),
 ('F7_700', '700', 'E01033140', r'^(Job Centre|High Chelmer|Parkway)', {'drop_note': FIRST_SCH}),
 ('F7_C1', 'C1', 'E01021542', r'^Broomfield Hospital', {'drop_note': FIRST_SCH}),
 ('F7_C1', 'C1', 'E01021587', r'^Patching Hall Lane', {'drop_note': FIRST_SCH}),
 # --- Portsmouth (First)
 *[('F12_' + s, r, z, p, {'drop_note': FIRST_SCH}) for s, r, z, p in [
   ('1', '1', 'E01017032', r'^City Centre'), ('3', '3', 'E01017032', r'^City Centre'),
   ('2', '2', 'E01017032', r'^City Centre'), ('8', '8', 'E01017032', r'^City Centre'),
   ('7', '7', 'E01017032', r'^City Centre'), ('X3-X4-X5', 'X3', 'E01017032', r'^City Centre')]],
 # --- Weymouth (First)
 *[('F6_' + s, r, 'E01020554', r"(King'?s? Statue|Commercial Road)", {'drop_note': FIRST_SCH}) for s, r in [
   ('1', '1'), ('2', '2'), ('4', '4'), ('8', '8'), ('10-10A', '10')]],
 # --- Swansea (First Cymru)
 ('F21_4-4A', '4', 'W01001955', r'^Swansea Bus Station', {'drop_note': FIRST_SCH, 'routes': ['4']}),
 ('F21_X6', 'X6', 'W01001955', r'^Swansea Bus Station', {'drop_note': FIRST_SCH}),
 ('EX_SC125', '125', 'E01024940', r'^Chorley Interchange', {}),
 ('EX_SC125', '125', 'E01033223', r'^Preston Bus Station', {}),
 # --- Edinburgh (Lothian). Neither zone's own stops is a timing point, so the
 # adjacent timing point on the same corridor stands in for it.
 *[('L_' + k, r, 'S01014636', r'^Newington Road', {'routes': [r]} if r == '47' else {}) for k, r in [
   ('03_26e02r22', '3'), ('31_26g02d22', '31'), ('37_X37_25b09j07', '37'), ('07_25g09u07', '7'),
   ('29_X29_26a02d22', '29'), ('49_25b09k07', '49'), ('08_25g04F06', '8'), ('47_47B_25f09y07', '47')]],
 *[('L_' + k, r, 'S01014958', r'^Crewe Toll', {}) for k, r in [
   ('21_25s04D06', '21'), ('27_25d09t07', '27'), ('29_X29_26a02d22', '29'), ('37_X37_25b09j07', '37')]],
]


def edition_of(d):
    if d['edition']:
        return d['edition']
    import subprocess
    f = list(d['files'].values())[0]
    t = subprocess.run(['pdftotext', '-l', '2', f, '-'], capture_output=True, text=True).stdout
    m = re.search(r'Valid from (\d\d)/(\d\d)/(\d{4})', t)
    if m:
        return f'{m.group(3)}-{m.group(2)}-{m.group(1)}'
    m = re.search(r'From (\d{1,2})\w\w (\w+) (\d{4})', t)
    if m:
        mo = ['january', 'february', 'march', 'april', 'may', 'june', 'july', 'august', 'september',
              'october', 'november', 'december'].index(m.group(2).lower()) + 1
        return f'{m.group(3)}-{mo:02d}-{int(m.group(1)):02d}'
    return None


def run():
    rows = []
    for key, route, zone, pat, opt in C:
        d = DOCS[key]
        per = {}
        quals, labs = set(), set()
        for day, f in d['files'].items():
            b = blocks_for(f, day)
            if day != '*':
                for x in b:
                    x['day'] = day
            r = T.count(b, pat, drop_note=opt.get('drop_note'), routes=opt.get('routes'))
            for dd, v in r.items():
                per[dd] = per.get(dd, 0) + v['n']
                quals |= v['qualifiers']
                labs |= v['rows']
        days = dict(per)
        # resolve day types into the window
        if 'MT' in days or 'Fr' in days:
            mt = days.get('MT', days.get('MF', 0)); fr = days.get('Fr', days.get('MF', mt))
            wk = 16 * mt + 4 * fr
        elif 'MF' in days:
            wk = 20 * days['MF']
        elif 'MS' in days:
            wk = 20 * days['MS']
            days.setdefault('Sa', days['MS'])
        else:
            wk = 0
        tot = wk + 4 * days.get('Sa', 0) + 4 * days.get('Su', 0)
        src = runs[(runs.zone_id == zone) & (runs.name.str.upper() == route.upper())]
        tn, bo = (float(src.tnds.sum()), float(src.bods_gtfs.sum())) if len(src) else (None, None)
        rows.append(dict(doc=key, route=route, zone=zone, operator=d['operator'], edition=edition_of(d),
                         days={k: v for k, v in days.items() if k}, unknown_day=days.get(None),
                         pdf=tot, tnds=tn, bods=bo,
                         t_ratio=round(tn / tot, 2) if tot and tn is not None else None,
                         b_ratio=round(bo / tot, 2) if tot and bo is not None else None,
                         quals=sorted(quals), rows=sorted(labs)[:4],
                         reliable=not any(q.startswith(('unexpanded', 'gap-without')) for q in quals) and None not in days))
        print(rows[-1]['doc'][:40], route, zone, rows[-1]['days'], 'pdf', tot, 'T', tn, 'B', bo,
              rows[-1]['t_ratio'], rows[-1]['b_ratio'], rows[-1]['edition'], sorted(quals)[:2], flush=True)
    pd.DataFrame(rows).to_pickle(SP + 'results.pkl')


if __name__ == '__main__':
    run()
