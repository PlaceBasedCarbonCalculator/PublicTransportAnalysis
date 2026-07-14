# Run the full pipeline. From a shell:
#   "C:\Program Files\R\R-4.3.3\bin\Rscript.exe" run.R
# or interactively: targets::tar_make()
#
# The pipeline is resumable: every completed target is cached in _targets/
# and only outdated targets re-run.

targets::tar_make()
