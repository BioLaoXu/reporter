## ---------------------------------------------------------------------
## PDF export (P3, per 报告优化.md §7)
## ---------------------------------------------------------------------
## export_pdf() re-renders the report in print mode (full tables, no
## pagination UI, unfolded details) and prints it with headless Chrome.
## Without Chrome the print-ready HTML is kept for manual Ctrl+P.

#' Locate a usable Chrome/Chromium binary
#'
#' Search order: `REPORTER_CHROME` env var → `pagedown::find_chrome()` →
#' common system names on PATH → Playwright browser caches.
#'
#' @return character(1) path, or `NULL` when nothing was found.
#' @keywords internal
rp_find_chrome <- function() {
  cand <- character(0L)
  env <- Sys.getenv("REPORTER_CHROME", "")
  if (nzchar(env)) cand <- c(cand, env)
  ## playwright caches first: known-good binaries on dev machines
  cand <- c(cand, Sys.glob(file.path(
    "~", ".cache", "ms-playwright", "chromium-*", "chrome-linux", "chrome")))
  if (requireNamespace("pagedown", quietly = TRUE)) {
    cand <- c(cand, tryCatch(pagedown::find_chrome(), error = function(e) NULL))
  }
  cand <- c(cand, unname(Sys.which(c(
    "google-chrome", "google-chrome-stable", "chromium", "chromium-browser",
    "chrome"))))
  for (p in cand) {
    if (length(p) && nzchar(p) && file.exists(p)) {
      p <- normalizePath(p)
      ## a wrapper script may exist but point to a missing binary —
      ## verify the candidate actually runs before trusting it
      ver <- suppressWarnings(tryCatch(
        system2(p, "--version", stdout = TRUE, stderr = TRUE, timeout = 15),
        error = function(e) NULL))
      if (!is.null(ver) && any(grepl("Chrom", ver))) return(p)
    }
  }
  NULL
}

#' Export a report to PDF (print mode + headless Chrome)
#'
#' Re-renders the report in **print mode** — full tables (no pagination),
#' unfolded explanation blocks, galleries expanded to all panes, A4
#' print CSS — and prints it with headless Chrome/Chromium. The
#' interactive HTML delivery is unaffected.
#'
#' If no Chrome binary is found, the print-ready HTML is kept on disk
#' and a message explains how to finish the export manually
#' (open it in a browser → Ctrl+P → save as PDF).
#'
#' @param report A `reporter_report` from [create_report()] +
#'   [add_module()].
#' @param output character(1). PDF file path.
#' @param theme,title,engine,quiet Passed to [render_report()].
#' @return Invisibly, the PDF path on success, or the print-ready HTML
#'   path when Chrome is unavailable.
#' @seealso [render_report()]
#' @export
export_pdf <- function(report, output = "report.pdf", theme = NULL,
                       engine = NULL, title = NULL, quiet = FALSE) {
  output <- rp_char1(output) %||% "report.pdf"
  html_tmp <- tempfile(fileext = ".html")
  render_report(report, output = html_tmp, theme = theme, engine = engine,
                title = title, print_mode = TRUE, quiet = quiet)
  chrome <- rp_find_chrome()
  if (is.null(chrome)) {
    message("reporter: no Chrome/Chromium found — the print-ready HTML is ",
      "kept at:\n  ", html_tmp, "\n",
      "open it in a browser and press Ctrl+P to save as PDF, ",
      "or install Chrome / set REPORTER_CHROME and re-run export_pdf().")
    return(invisible(html_tmp))
  }
  if (!quiet) message("reporter: printing with ", chrome)
  if (requireNamespace("pagedown", quietly = TRUE)) {
    pagedown::chrome_print(html_tmp, output = output, browser = chrome,
      extra_args = c("--no-sandbox", "--disable-gpu"),
      options = list(printBackground = TRUE),
      timeout = 120, watch = FALSE)
  } else {
    out_abs <- normalizePath(output, mustWork = FALSE)
    status <- suppressWarnings(system2(chrome, c(
      "--headless", "--disable-gpu", "--no-sandbox",
      paste0("--print-to-pdf=", shQuote(out_abs)),
      shQuote(normalizePath(html_tmp)))))
    if (!identical(status, 0L) || !file.exists(output)) {
      stop("reporter: Chrome printing failed (exit status ",
        status, ")", call. = FALSE)
    }
  }
  unlink(html_tmp)
  if (!quiet) {
    message("reporter: PDF written: ", normalizePath(output), " (",
      round(file.size(output) / 1024 / 1024, 2), " MB)")
  }
  invisible(output)
}
