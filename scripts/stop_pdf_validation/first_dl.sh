#!/bin/sh
# Download First Bus timetable PDFs (current edition: the API's date= parameter
# no longer serves editions that have ended) for one operating company.
# usage: first_dl.sh OPCO PREFIX OUTDIR SUFFIX route [route ...]
# Tries each route as given, then with "-SUFFIX", and keeps the first code
# that yields a timetable for at least one day type.
opco=$1; pre=$2; out=$3; suf=$4; shift 4
for r in "$@"; do
  found=""
  for code in "$r" "$r-$suf"; do
    enc=$(printf '%s' "$code" | sed 's#/#%2F#g')
    for day in mf sa su; do
      f="$out/${pre}_$(printf '%s' "$r" | tr '/' '-')_$day.pdf"
      curl -s -m 60 -A "Mozilla/5.0" -o "$f" \
        "https://www.firstbus.co.uk/api/timetables/pdf?opco=$opco&service=$enc&day=$day&print=pdf"
      if pdftotext -l 1 "$f" - 2>/dev/null | grep -q "Can't create"; then rm -f "$f"; else found="$code"; fi
    done
    [ -n "$found" ] && break
  done
  v=$(ls "$out/${pre}_$(printf '%s' "$r" | tr '/' '-')"_*.pdf 2>/dev/null | head -1)
  echo "$r	${found:-NONE}	$( [ -n "$v" ] && pdftotext -l 1 "$v" - | grep -m1 -i 'valid from')"
done
