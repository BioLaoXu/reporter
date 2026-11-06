#!/usr/bin/env Rscript
# ---------------------------------------------------------------------------
# reporter — pipeline CLI entry point
#
# Drop-in replacement for the legacy Report.R scripts. Usage:
#
#   Rscript run_report.R --result /path/to/results \
#       --species Homo_sapiens --project "8例ChIPseq检测分析" \
#       --code 72407172801 --outhtml report \
#       --logo smzy --company "ACME Biotech" \
#       --phonenum "000-0000-0000" --type 1 --modules chip
#
# Exit codes: 0 ok | 1 some module(s) failed | 2 fatal error
# ---------------------------------------------------------------------------

local({
  ## Prefer the reporter private library when this script is executed from
  ## a pipeline host whose R session has no private lib configured.
  rp_lib <- Sys.getenv(
    "REPORTER_LIBRARY",
    "/data/InHousePackages/reporter/library"
  )
  if (dir.exists(rp_lib) && !rp_lib %in% .libPaths()) {
    .libPaths(c(rp_lib, .libPaths()))
  }
})

tryCatch(
  {
    if (!requireNamespace("reporter", quietly = TRUE)) {
      stop("reporter package is not available in this R library. ",
           "Install it first (see README) or source env.sh.")
    }
    reporter::report_cli(do_quit = TRUE)
  },
  error = function(e) {
    message("reporter: FATAL - ", conditionMessage(e))
    quit(status = 2L)
  }
)
