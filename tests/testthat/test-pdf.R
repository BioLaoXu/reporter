## P3: print-mode rendering + PDF export

test_that("print_mode unfolds details and disables reactable pagination", {
  tmp <- make_chip_fixture()
  ctx <- report_context(tmp, type = "1")
  report <- do.call(add_module,
    c(list(report = create_report(ctx)), chip_report_modules()))
  out <- tempfile(fileext = ".html")
  res <- render_report(report, output = out, print_mode = TRUE,
    theme = reporter_theme(preset = "blank"), quiet = TRUE)
  html <- paste(readLines(res$output, warn = FALSE), collapse = "\n")
  expect_match(html, "<details class=\"rp-details\" open", fixed = TRUE)
  expect_match(html, '"pagination":false', fixed = TRUE)
  ## interactive delivery unchanged when print_mode is off
  out2 <- tempfile(fileext = ".html")
  res2 <- render_report(report, output = out2,
    theme = reporter_theme(preset = "blank"), quiet = TRUE)
  html2 <- paste(readLines(res2$output, warn = FALSE), collapse = "\n")
  expect_false(grepl("<details class=\"rp-details\" open", html2, fixed = TRUE))
})

test_that("export_pdf produces a real PDF (requires a chrome binary)", {
  chrome <- reporter:::rp_find_chrome()
  skip_if(is.null(chrome), "no Chrome/Chromium binary available")
  tmp <- make_chip_fixture()
  ctx <- report_context(tmp, type = "1")
  report <- do.call(add_module,
    c(list(report = create_report(ctx)), chip_report_modules()))
  out <- tempfile(fileext = ".pdf")
  res <- export_pdf(report, output = out,
    theme = reporter_theme(preset = "blank", style = "card"), quiet = TRUE)
  expect_identical(res, out)
  expect_true(file.exists(out))
  expect_gt(file.size(out), 100000)
  head <- paste(readLines(out, n = 1), collapse = "")
  expect_match(head, "%PDF", fixed = TRUE)
})

test_that("export_pdf keeps the print HTML and explains when chrome is absent", {
  ## simulate: no binary anywhere
  real <- reporter:::rp_find_chrome
  original_env <- Sys.getenv("REPORTER_CHROME", "")
  Sys.setenv(REPORTER_CHROME = "")
  assignInNamespace("rp_find_chrome", function() NULL, "reporter")
  on.exit({
    assignInNamespace("rp_find_chrome", real, "reporter")
    if (nzchar(original_env)) Sys.setenv(REPORTER_CHROME = original_env)
  })
  tmp <- make_chip_fixture()
  ctx <- report_context(tmp, type = "1")
  report <- do.call(add_module,
    c(list(report = create_report(ctx)), chip_report_modules()))
  expect_message(
    res <- export_pdf(report, output = tempfile(fileext = ".pdf"),
      theme = reporter_theme(preset = "blank"), quiet = TRUE),
    "no Chrome"
  )
  expect_match(res, "\\.html$")
  expect_true(file.exists(res))
})

test_that("print_html companion + render-state reset keep numbering stable", {
  tmp <- make_chip_fixture()
  ctx <- report_context(tmp, type = "1")
  report <- do.call(add_module,
    c(list(report = create_report(ctx)), chip_report_modules()))
  out <- tempfile(fileext = ".html")
  res <- render_report(report, output = out, print_html = TRUE,
    theme = reporter_theme(preset = "blank"), quiet = TRUE)
  print_out <- sub("\\.html$", "_print.html", out)
  expect_true(file.exists(print_out))
  ## counters were reset before the print re-render: identical numbering
  h1 <- paste(readLines(res$output, warn = FALSE), collapse = "\n")
  h2 <- paste(readLines(print_out, warn = FALSE), collapse = "\n")
  fig1 <- length(gregexpr("rp-badge-fig", h1, fixed = TRUE)[[1]])
  fig2 <- length(gregexpr("rp-badge-fig", h2, fixed = TRUE)[[1]])
  expect_identical(fig1, fig2)
  ## navbar export button + JS hook present
  expect_match(h1, "rp-btn-pdf", fixed = TRUE)
  expect_match(h1, "exportReportToPDF", fixed = TRUE)
})

test_that("repeated renders on a shared ctx keep counters stable", {
  tmp <- make_chip_fixture()
  ctx <- report_context(tmp, type = "1")
  report <- do.call(add_module,
    c(list(report = create_report(ctx)), chip_report_modules()))
  res1 <- render_report(report, output = tempfile(fileext = ".html"),
    theme = reporter_theme(preset = "blank"), quiet = TRUE)
  res2 <- render_report(report, output = tempfile(fileext = ".html"),
    theme = reporter_theme(preset = "blank"), quiet = TRUE)
  expect_identical(res1$counters, res2$counters)
})
