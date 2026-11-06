test_that("module gating: required_dirs and when() control inclusion", {
  tmp <- make_chip_fixture()
  ctx <- report_context(tmp, type = "1")
  m_ok <- module("a", "A", function(ctx) ctx$note("ok"),
    required_dirs = "1.QC")
  m_miss <- module("b", "B", function(ctx) ctx$note("no"),
    required_dirs = c("8.NotThere"))
  m_when <- module("c", "C", function(ctx) ctx$note("no"),
    required_dirs = "1.QC", when = function(ctx) FALSE)
  ## NA means "no skip reason" → module applies
  expect_true(is.na(reporter:::rp_module_skip_reason(m_ok, ctx)))
  expect_match(reporter:::rp_module_skip_reason(m_miss, ctx),
    "missing directories")
  expect_match(reporter:::rp_module_skip_reason(m_when, ctx), "when\\(\\)")
})

test_that("render_report degrades failed modules and records errors", {
  tmp <- make_chip_fixture()
  ctx <- report_context(tmp)
  boom <- module("boom", "Boomer", function(ctx) stop("kaboom"))
  good <- module("good", "Good", function(ctx) ctx$note("fine"))
  report <- create_report(ctx) |> add_module(boom, good)
  out <- tempfile(fileext = ".html")
  res <- render_report(report, output = out, quiet = TRUE)
  html <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_match(html, "Module rendering failed")
  expect_match(html, "kaboom")
  expect_match(html, "fine")
  expect_length(res$errors, 1L)
  expect_equal(res$errors[[1L]]$id, "boom")
  expect_false(is.null(res$modules))
})

test_that("render_report aborts when nothing renders", {
  ctx <- report_context(tempdir())
  report <- create_report(ctx) |>
    add_module(module("x", "X", function(ctx) stop("no"),
      required_dirs = "missing-dir"))
  expect_error(render_report(report, output = tempfile(fileext = ".html"),
    quiet = TRUE), "no module was rendered")
})

test_that("standalone output has no external asset references", {
  tmp <- make_chip_fixture()
  ctx <- report_context(tmp, species = "Homo_sapiens",
    project = "Test", type = "1")
  report <- create_report(ctx)
  report <- do.call(add_module,
    c(list(report = report), chip_report_modules()))
  out <- tempfile(fileext = ".html")
  res <- render_report(report, output = out,
    theme = reporter_theme(preset = "blank"), quiet = TRUE)
  html <- paste(readLines(out, warn = FALSE), collapse = "\n")

  ## single-file guarantees
  expect_false(grepl('src="lib/', html))
  expect_false(grepl('href="lib/', html))
  expect_false(grepl("report_assets", html))
  ## reactable runtime was inlined, not dropped
  expect_match(html, "Reactable")
  ## theme + own assets inlined
  expect_match(html, "--rp-primary")
  expect_match(html, "rp-gallery")
  expect_match(html, "IntersectionObserver|scrollspy", ignore.case = TRUE)
  ## images are data URIs
  expect_match(html, "data:image/png;base64,")
  ## toc skeleton present
  expect_match(html, "id=\"rp-toc\"")
  expect_gte(file.size(out), 100000) # fully inlined runtime is > 100 kB
  expect_false(dir.exists(file.path(tempdir(), "report_assets")))
})

test_that("type=0 (single group) skips diff-only modules", {
  tmp <- make_chip_fixture()
  ctx <- report_context(tmp, type = "0")
  report <- create_report(ctx)
  report <- do.call(add_module,
    c(list(report = report), chip_report_modules()))
  out <- tempfile(fileext = ".html")
  res <- render_report(report, output = out, quiet = TRUE)
  expect_true(all(c("diffpeak", "enrich", "motif") %in%
    vapply(res$skipped, function(s) s$id, character(1L))))
  html <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_false(grepl("id=\"mod-diffpeak\"", html))
  expect_match(html, "id=\"mod-overview\"")
})

test_that("multi-file mode writes html plus assets dir", {
  tmp <- make_chip_fixture()
  ctx <- report_context(tmp, type = "1")
  report <- create_report(ctx)
  report <- do.call(add_module,
    c(list(report = report), chip_report_modules()))
  out <- file.path(tempdir(), "multi", "report.html")
  res <- render_report(report, output = out, standalone = FALSE, quiet = TRUE)
  expect_true(file.exists(out))
  expect_true(dir.exists(file.path(dirname(out), "report_assets")))
})
