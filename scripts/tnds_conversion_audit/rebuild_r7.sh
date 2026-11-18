#!/bin/bash
# Rebuild the validation snapshots with the round-7 filter (run after installing UK2GTFS).
# usage: bash scripts/tnds_conversion_audit/rebuild_r7.sh [label]   (from the repo root)
# The caches being replaced are moved to gtfs/cache_stale_<label> (default r6b).
set -e
label=${1:-r6b}
stale=gtfs/cache_stale_$label
[ -e "$stale" ] && { echo "$stale exists - choose another label"; exit 1; }
export TMPDIR=F:/tmp_r TMP=F:/tmp_r TEMP=F:/tmp_r
mkdir -p "$stale"
for c in tnds_20260726_v25 tnds_20261111_v25 bods_txc_20261111_full.zip; do
  [ -e "gtfs/cache/$c" ] && mv "gtfs/cache/$c" "$stale"/
done
Rscript -e 'library(targets); tar_invalidate(c("tnds_20260726","tnds_20261111","bods_txc_20261111"))'
nohup Rscript -e 'library(targets); tar_make(names = c("pdf_validation_report","lsoa_gap_report","stop_gap_report","stop_pdf_nov","near_duplicates_report"), callr_function = NULL)' > logs_r7_rebuild.log 2>&1 &
echo "started: tail -f logs_r7_rebuild.log"
