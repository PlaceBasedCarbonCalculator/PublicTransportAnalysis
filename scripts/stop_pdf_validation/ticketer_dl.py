"""Download timetables from a Ticketer timetable widget, for dates in the window.

Some small operators' sites (Gatwick Hoppa) embed Ticketer's timetable
widget, `/v4/widget/embeded/timetable?guid=...&serviceName=...&date=...`.
Unlike the big operators' sites it still answers for past dates, so it gives
the timetable as it ran on a day inside the July 2026 window: an edition in
force by construction.

The portal sits behind an AWS WAF. The first request (Tuesday 28 July) was
answered on 13 November 2026; every one after it got HTTP 202 with an empty
body and `x-amzn-waf-action: challenge`, a JavaScript challenge meant for
browsers. Only the weekday is held, so the GH1 is checked on the single day,
not the window. A Saturday and Sunday saved by hand from the operator's page
(with the date picker set inside the window) would complete it.

usage: python -I ticketer_dl.py
Writes data/example_timetables/<operator>/<service>_<MF|Sa|Su>.html.
"""
import os, time, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
EX = os.path.join(HERE, '..', '..', 'data', 'example_timetables')
UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/130.0 Safari/537.36'

# A weekday, Saturday and Sunday inside the window (27 Jul - 9 Aug 2026)
DATES = {'MF': '2026-07-28', 'Sa': '2026-08-01', 'Su': '2026-08-02'}

# (folder, portal host, widget guid, operator code, service): the guid and
# codes are in the widget URL on the operator's timetable page
WIDGETS = [
    ('gatwickhoppa', 'portal.gatwickhoppa.co.uk', '89a4e053-2699-4107-9da6-ab3b10212e3c',
     'GHOP', 'GH1'),
]


def main():
    for folder, host, guid, op, svc in WIDGETS:
        out = os.path.join(EX, folder)
        os.makedirs(out, exist_ok=True)
        for day, date in DATES.items():
            url = ('https://%s/v4/widget/embeded/timetable?guid=%s&serviceName=%s&operatorCode=%s'
                   '&allTimes=True&ticketerCode=%s&forceAllTimes=True&fixedNames=False'
                   '&clearCache=false&date=%s&mergedTimetable=False' % (host, guid, svc, op, svc, date))
            req = urllib.request.Request(url, headers={'User-Agent': UA})
            h = urllib.request.urlopen(req, timeout=60).read().decode('utf-8', 'ignore')
            with open(os.path.join(out, '%s_%s.html' % (svc, day)), 'w', encoding='utf-8') as f:
                f.write(h)
            print(folder, svc, day, date, len(h), flush=True)
            time.sleep(1)
        with open(os.path.join(out, 'dates.txt'), 'w') as f:
            f.write(' '.join('%s=%s' % kv for kv in DATES.items()) + '\n')


if __name__ == '__main__':
    main()
