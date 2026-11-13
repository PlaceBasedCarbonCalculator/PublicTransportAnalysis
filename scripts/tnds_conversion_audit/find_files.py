"""Find TNDS TransXChange files by operator code and line name.

usage: python -I find_files.py <region zip> NOC line[,line...] [NOC line,...]
Reads every file (NOCs are not always in the header) and prints the files
whose NationalOperatorCode and LineName both match.
"""
import re, sys, zipfile
z = zipfile.ZipFile(sys.argv[1])
want = [(sys.argv[i], set(sys.argv[i + 1].split(','))) for i in range(2, len(sys.argv), 2)]
for n in z.namelist():
    if not n.endswith('.xml'):
        continue
    s = z.read(n).decode('utf-8', 'ignore')
    nocs = set(re.findall(r'<NationalOperatorCode>([^<]+)<', s))
    lines = set(re.findall(r'<LineName>([^<]+)</LineName>', s))
    for noc, ls in want:
        if noc in nocs and lines & ls:
            print(noc, '|', ','.join(sorted(lines & ls)), '|', n)
