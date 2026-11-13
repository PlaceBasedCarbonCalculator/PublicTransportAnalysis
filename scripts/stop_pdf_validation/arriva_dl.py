"""Download Arriva timetables as HTML.

Arriva publishes no PDFs. Each service page (arrivabus.co.uk/services/<code>)
loads its timetable from /_ajax/lines/timetable/<code>?date=&direction=, one
operating date and one direction at a time, as an HTML table: a column per
journey, a row per principal stop, each row linked to the stop's NaPTAN code.
That is a published timetable in the same sense as a PDF, so it is saved
whole and read by read_docs.py.

Only current and future dates are served (a July 2026 date returns "no
timetables available"), so these are later editions for the July window.

usage: python -I arriva_dl.py [YYYY-MM-DD]   (a Tuesday; default 2026-11-17)
Writes data/example_timetables/arriva/<code>_<MF|Sa|Su>_<out|in>.html and
records the dates in arriva/dates.txt.
"""
import datetime as dt, os, sys, time, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', '..', 'data', 'example_timetables', 'arriva')
UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/130.0 Safari/537.36'

# Service codes from arrivabus.co.uk/locations/<region>; route -> code
CODES = {
    # Tyne and Wear, through Regent Centre
    '43': 'NMS_BH_43', '44': 'NMS_BH_44', '45': 'NMS_BH_45', 'X9': 'NMS_BH_X9',
    'X10': 'NMS_BH_X10', 'X11': 'NMS_BH_X11', 'X14': 'NMS_AN_X14', 'X15': 'NMS_AN_X15',
    'X16': 'NMS_AN_X16', 'X18': 'NMS_AN_X18', 'X20': 'NMS_AN_X20', 'X21': 'NMS_AN_X21',
    'X22': 'NMS_AN_X22', 'X30': 'NMS_AN_X30',
    # Durham
    '24': 'DC_DM_24',
    # Stevenage
    'SB1': 'AKE_BR_SB1', 'SB2': 'AKE_BR_SB2', 'SB3': 'AKE_BR_SB3', 'SB4': 'AKE_BR_SB4',
    'SB5': 'AKE_BR_SB5', 'SB7': 'AKE_BR_SB7', 'SB8': 'AKE_BR_SB8', 'SB50': 'AKE_BR_SB50',
    '55': 'AKE_BR_55', '301': 'AKE_BR_301', '400': 'AKE_BR_400',
}


def get(url):
    for k in range(3):
        try:
            req = urllib.request.Request(url, headers={'User-Agent': UA,
                                                       'X-Requested-With': 'XMLHttpRequest'})
            return urllib.request.urlopen(req, timeout=60).read().decode('utf-8', 'ignore')
        except Exception:
            time.sleep(3)
    return ''


def main(tuesday='2026-11-17'):
    d0 = dt.date.fromisoformat(tuesday)
    days = {'MF': d0, 'Sa': d0 + dt.timedelta(days=4), 'Su': d0 + dt.timedelta(days=5)}
    os.makedirs(OUT, exist_ok=True)
    for route, code in CODES.items():
        for day, date in days.items():
            for dirn, tag in (('outbound', 'out'), ('inbound', 'in')):
                h = get('https://www.arrivabus.co.uk/_ajax/lines/timetable/%s?date=%s&direction=%s'
                        % (code, date.isoformat(), dirn))
                with open(os.path.join(OUT, '%s_%s_%s.html' % (code, day, tag)), 'w',
                          encoding='utf-8') as f:
                    f.write(h)
        print(route, code, flush=True)
    with open(os.path.join(OUT, 'dates.txt'), 'w') as f:
        f.write(' '.join('%s=%s' % (k, v.isoformat()) for k, v in days.items()) + '\n')


if __name__ == '__main__':
    main(*sys.argv[1:2])
