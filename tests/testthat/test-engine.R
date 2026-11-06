## dual rendering engine (P1): reactable (default) vs lite (native grid)

test_that("engine=lite renders native grids without reactable runtime", {
  tmp <- make_chip_fixture()
  ctx <- report_context(tmp, type = "1")
  report <- do.call(add_module,
    c(list(report = create_report(ctx)), chip_report_modules()))
  out <- tempfile(fileext = ".html")
  res <- render_report(report, output = out, engine = "lite",
    theme = reporter_theme(preset = "blank"), quiet = TRUE)
  html <- paste(readLines(res$output, warn = FALSE), collapse = "\n")
  expect_match(html, 'class="rp-grid-toolbar"', fixed = TRUE)
  expect_match(html, '<table class="rp-table"', fixed = TRUE)
  expect_false(grepl("reactable html-widget", html, fixed = TRUE))
  ## schema reflects the active engine
  m <- regexpr('<script id="rp-schema"[^>]*>[\\s\\S]*?</script>', html, perl = TRUE)
  js <- sub("^<script[^>]*>", "", sub("</script>$", "",
    regmatches(html, m)[[1]]))
  s <- jsonlite::fromJSON(js, simplifyVector = FALSE)
  expect_identical(s$meta$engine, "lite")
})

test_that("engine=reactable (default) keeps the widget path", {
  tmp <- make_chip_fixture()
  ctx <- report_context(tmp, type = "1")
  report <- do.call(add_module,
    c(list(report = create_report(ctx)), chip_report_modules()))
  out <- tempfile(fileext = ".html")
  res <- render_report(report, output = out,
    theme = reporter_theme(preset = "blank"), quiet = TRUE)
  html <- paste(readLines(res$output, warn = FALSE), collapse = "\n")
  expect_match(html, "reactable html-widget", fixed = TRUE)
  expect_false(grepl('class="rp-grid-toolbar"', html, fixed = TRUE))
  ## schema reports reactable
  m <- regexpr('<script id="rp-schema"[^>]*>[\\s\\S]*?</script>', html, perl = TRUE)
  js <- sub("^<script[^>]*>", "", sub("</script>$", "",
    regmatches(html, m)[[1]]))
  s <- jsonlite::fromJSON(js, simplifyVector = FALSE)
  expect_identical(s$meta$engine, "reactable")
})

test_that("spec YAML engine field reaches the render pipeline", {
  skip_if_not(dir.exists("/data/Report/atac_project_2024/test0706_drosophila"),
              "real ATAC demo dir not available")
  res <- render_spec(system.file("examples", "atac_qc_spec.yaml",
    package = "reporter"),
    result_path = "/data/Report/atac_project_2024/test0706_drosophila",
    output = tempfile(fileext = ".html"), quiet = TRUE)
  html <- paste(readLines(res$output, warn = FALSE), collapse = "\n")
  ## spec has no engine field -> default reactable
  expect_match(html, "reactable html-widget", fixed = TRUE)
})
