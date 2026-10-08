# Stop UK2GTFS downloading its packaged data at every package load.
#
# UK2GTFS keeps its large datasets in a separate GitHub repo and refreshes
# them from .onLoad(), which - as the comment in its own zzz.R says - runs in
# every worker process. A 30-worker conversion therefore makes 30 GitHub API
# calls, each preceded by a 5 s sleep, and if any of them fails or is rate
# limited, check_data() takes a fallback path that is actively destructive:
#
#   - it sets the comparison date to Sys.time(), which can never equal the
#     stored date, so the data always looks out of date;
#   - it then downloads a HARDCODED default_tag = "v0.1.2", which is older
#     than the v0.1.6 release this pipeline needs;
#   - it unzips into the shared library folder while other workers are doing
#     the same;
#   - and it stamps date.txt with today, so afterwards everything looks
#     up to date.
#
# On 2026-10-08 that downgraded the installed data mid-conversion and left
# naptan_replace.rda holding a byte-identical copy of naptan_missing, so the
# 503 genuine stop-location corrections silently stopped being applied.
#
# The data is pinned deliberately instead. Refresh it on purpose, in a single
# process with nothing else running, and check the result:
#   Rscript -e 'options(UK2GTFS_opt_updateCachedDataOnLibaryLoad=FALSE);
#               UK2GTFS::update_data()'
# then confirm naptan_replace is 503 rows and is NOT identical to
# naptan_missing before converting anything.
options(UK2GTFS_opt_updateCachedDataOnLibaryLoad = FALSE)
