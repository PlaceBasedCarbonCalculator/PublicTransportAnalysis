# Rebuild driver for the day-type filter fix (UK2GTFS txc_filter_files rule 1
# keyed on the operating day set, plus the rule 4 disjointness skip).
#
# Every TransXChange conversion is affected and nothing else is:
# txc_filter_files() is reachable only from transxchange2gtfs(), so the NPTDR
# ATCO-CIF years and the rail CIF/RDP feeds are untouched and trips_2004 to
# trips_2011 stay as they are. naptan, txc_cal and noc stay pinned.
#
# The conversion caches for the affected feeds were deleted first, which is
# the only way a package change reaches a feed: post_convert() applies
# patch_naptan() BEFORE the cache is written, and convert_txc_cached() skips
# conversion entirely when the cache exists.
#
# One Rscript per target, in dependency order, continuing past failures.
# Stage 1 is the validation family, because the July 2026 snapshot is the one
# with published-timetable checks attached and so is what says whether the fix
# worked before thirty hours of series conversion go in behind it.
param([string]$Only = "")

$ErrorActionPreference = 'Continue'
$log    = "logs\rebuild_daytype.log"
$status = "logs\rebuild_daytype_status.csv"
New-Item -ItemType Directory -Force -Path logs\targets | Out-Null
if (-not (Test-Path $status)) {
  Set-Content $status "timestamp,stage,target,status,seconds" -Encoding ascii
}

$stages = [ordered]@{
  # the fix, measured where there is independent evidence to measure it against
  '1-validation' = @('tnds_20260726','pdf_validation','pdf_validation_report',
                     'near_duplicates','near_duplicates_report',
                     'val_2026_tnds','lsoa_gap','lsoa_gap_report')
  # the three-source comparison, 2022-2025 (2026 is already on the fix)
  '2-comparison' = @('tnds_20221102','tnds_20231101','tnds_20241004',
                     'tnds_20251003',
                     'bods_txc_2022','bods_txc_2023','bods_txc_2024',
                     'bods_txc_2025',
                     'cmp_2022_tnds','cmp_2022_bods_txc','comparison_2022',
                     'cmp_2023_tnds','cmp_2023_bods_txc','comparison_2023',
                     'cmp_2024_tnds','cmp_2024_bods_txc','comparison_2024',
                     'cmp_2025_tnds','cmp_2025_bods_txc','comparison_2025',
                     'comparison_report')
  # the published per-year outputs ../build consumes
  '3-series'     = @('bods_coach_2024','bods_coach_2025','bods_coach_2026',
                     'tnds_20180515','tnds_20191008','tnds_20200701',
                     'tnds_20211012',
                     'busarchive_2014','busarchive_2015','busarchive_2016',
                     'busarchive_2017',
                     'trips_2014','trips_2015','trips_2016','trips_2017',
                     'trips_2018','trips_2019','trips_2020','trips_2021',
                     'trips_2022','trips_2023','trips_2024','trips_2025',
                     'trips_2026')
  # audits that take every feed as a dependency, so they go last
  '4-audits'     = @('non_bus','non_bus_report','coverage','coverage_report')
}

function Say($m) {
  $line = "$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')  $m"
  Add-Content $log $line -Encoding ascii
  Write-Output $line
}

# UK2GTFS refreshes its packaged data from .onLoad(), in every worker, and on
# an API failure downloads a hardcoded older release over the top of the good
# one - see .Rprofile. That happened four minutes into the first attempt at
# this rebuild and left patch_naptan() correcting nothing. So the data is
# asserted before anything is converted, and again after every target, which
# costs a couple of seconds and bounds the damage to one target.
function Check-Data($when) {
  & Rscript scripts\check_uk2gtfs_data.R 1> "logs\targets\_datacheck.out.log" 2>&1
  if ($LASTEXITCODE -ne 0) {
    Say "ABORT: UK2GTFS packaged data check failed $when"
    Get-Content "logs\targets\_datacheck.out.log" | ForEach-Object { Say "    $_" }
    return $false
  }
  return $true
}

Say "=== driver start (pid $PID) ==="
if (-not (Check-Data "before starting")) { Say "=== driver aborted ==="; exit 1 }
Say "packaged data check passed"
$built = 0; $failed = 0
foreach ($stage in $stages.Keys) {
  if ($Only -and $stage -ne $Only) { continue }
  Say "--- stage $stage ---"
  foreach ($t in $stages[$stage]) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    Say "building $t"
    $r = "library(targets); tar_make(names = all_of('$t'), reporter = 'verbose')"
    Set-Content "$env:TEMP\drv_$t.R" -Value $r -Encoding ascii
    & Rscript "$env:TEMP\drv_$t.R" `
        1> "logs\targets\$t.out.log" 2> "logs\targets\$t.err.log"
    $code = $LASTEXITCODE
    $sw.Stop()
    $secs = [int]$sw.Elapsed.TotalSeconds
    $st = if ($code -eq 0) { 'ok' } else { "fail($code)" }
    if ($code -eq 0) { $built++ } else { $failed++ }
    Add-Content $status "$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss'),$stage,$t,$st,$secs" -Encoding ascii
    Say "$t -> $st in $secs s"
    if (-not (Check-Data "after $t")) {
      Say "=== driver aborted after ${t}: $built ok, $failed failed ==="
      exit 1
    }
  }
}
Say "=== driver done: $built ok, $failed failed ==="
