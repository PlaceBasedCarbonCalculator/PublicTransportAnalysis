import sys, urllib.request, re
B = "https://passenger-line-assets.s3.eu-west-1.amazonaws.com/"
for op in sys.argv[1:]:
    tok = None
    while True:
        u = B + "?list-type=2&max-keys=1000&prefix=" + op + "/"
        if tok: u += "&continuation-token=" + urllib.parse.quote(tok)
        x = urllib.request.urlopen(u).read().decode()
        for k in re.findall(r"<Key>([^<]+)</Key>", x):
            if "-timetable-" in k: print(k)
        m = re.search(r"<NextContinuationToken>([^<]+)<", x)
        if not m: break
        tok = m.group(1)
