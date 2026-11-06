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
