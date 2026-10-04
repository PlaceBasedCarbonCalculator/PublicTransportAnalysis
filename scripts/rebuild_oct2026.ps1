# Rebuild driver for the October 2026 changes (UK2GTFS overlap patch,
# TransXChange 2.5, October 2026 snapshots, 14-day window).
#
# One Rscript per target, in priority order, continuing past failures. Stage 1
# is the validation family, which is what says whether the fixes worked.
param([string]$Only = "")

$ErrorActionPreference = 'Continue'
$log    = "logs\rebuild_oct2026.log"
$status = "logs\rebuild_oct2026_status.csv"
New-Item -ItemType Directory -Force -Path logs\targets | Out-Null
if (-not (Test-Path $status)) {
  Set-Content $status "timestamp,stage,target,status,seconds" -Encoding ascii
}

$stages = [ordered]@{
  '1-validation' = @('tnds_20260726','pdf_validation','pdf_validation_report',
                     'near_duplicates','near_duplicates_report',
                     'val_2026_tnds','val_2026_bods_gtfs',
                     'lsoa_gap','lsoa_gap_report')
  '2-oct2026'    = @('tnds_20261002','bods_coach_2026','rail_rdp_2026',
                     'bods_txc_2026','cmp_2026_tnds','cmp_2026_bods_txc',
                     'cmp_2026_bods_gtfs','comparison_2026','trips_2026')
  '3-comparison' = @('tnds_20221102','tnds_20231101','tnds_20241004','tnds_20251003',
                     'bods_txc_2022','bods_txc_2023','bods_txc_2024','bods_txc_2025',
                     'cmp_2022_tnds','cmp_2022_bods_txc','cmp_2022_bods_gtfs','comparison_2022',
                     'cmp_2023_tnds','cmp_2023_bods_txc','cmp_2023_bods_gtfs','comparison_2023',
                     'cmp_2024_tnds','cmp_2024_bods_txc','cmp_2024_bods_gtfs','comparison_2024',
                     'cmp_2025_tnds','cmp_2025_bods_txc','cmp_2025_bods_gtfs','comparison_2025',
                     'comparison_report')
  '4-series'     = @('tnds_20180515','tnds_20191008','tnds_20200701','tnds_20211012',
                     'trips_2018','trips_2019','trips_2020','trips_2021',
                     'trips_2022','trips_2023','trips_2024','trips_2025',
                     'trips_2004','trips_2005','trips_2006','trips_2007',
                     'trips_2008','trips_2009','trips_2010','trips_2011',
                     'trips_2014','trips_2015','trips_2016','trips_2017',
                     'non_bus','non_bus_report','coverage','coverage_report')
}

function Say($m) {
  $line = "$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')  $m"
  Add-Content $log $line -Encoding ascii
  Write-Output $line
}

Say "=== driver start (pid $PID) ==="
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
    Add-Content $status "$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss'),$stage,$t,$st,$secs" -Encoding ascii
    Say "$t -> $st in $secs s"
  }
}
Say "=== driver done ==="
