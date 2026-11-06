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

test_that("sci skin applies the design-contract tokens", {
  tmp <- make_chip_fixture()
  ctx <- report_context(tmp, type = "1")
  report <- do.call(add_module,
    c(list(report = create_report(ctx)), chip_report_modules()))
  out <- tempfile(fileext = ".html")
  res <- render_report(report, output = out,
    theme = reporter_theme(preset = "blank", style = "sci"), quiet = TRUE)
  html <- paste(readLines(res$output, warn = FALSE), collapse = "\n")
  expect_match(html, "rp-style-sci", fixed = TRUE)
  ## contract tokens present in the inlined stylesheet
  expect_match(html, "--rp-primary: #0D5C75", fixed = TRUE)
  expect_match(html, "--rp-up: #B2182B", fixed = TRUE)
  expect_match(html, "--rp-down: #2166AC", fixed = TRUE)
  ## module numbering counter + mono path capsule
  expect_match(html, "counter-increment: rp-mod", fixed = TRUE)
  expect_match(html, "rp-filepath", fixed = TRUE)
})

test_that("sci_v1 standalone template: cover eyebrow + meta grid + toc header", {
  tmp <- make_chip_fixture()
  ctx <- report_context(tmp, type = "1", project = "P", code = "C",
                        species = "S")
  report <- do.call(add_module,
    c(list(report = create_report(ctx)), chip_report_modules()))
  out <- tempfile(fileext = ".html")
  res <- render_report(report, output = out,
    theme = reporter_theme(preset = "blank", style = "sci_v1"), quiet = TRUE)
  html <- paste(readLines(res$output, warn = FALSE), collapse = "\n")
  ## template stylesheet loaded
  expect_match(html, "reporter-sci_v1.css", fixed = TRUE)
  ## cover_mode defaults to first_block: no cover card, the standard
  ## project-info module renders the meta grid as block 01
  expect_false(grepl('<div class="rp-cover-eyebrow"', html, fixed = TRUE))
  expect_match(html, "rp-meta-grid", fixed = TRUE)
  expect_match(html, "项目信息与实验设计", fixed = TRUE)
  expect_true(length(gregexpr("rp-meta-cell", html, fixed = TRUE)[[1]]) >= 5L)
  ## toc header with counter (project block added -> 13 modules)
  expect_match(html, "报告目录 · CONTENTS", fixed = TRUE)
  expect_match(html, "01 / 13", fixed = TRUE)
  ## template primitives exported
  expect_true(exists("meta_grid") && exists("kpi_strip") && exists("qc_pill"))
})
