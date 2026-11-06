## Defensive-programming suite: every user-facing entry point must
## degrade gracefully (placeholder / NULL / empty tagList) on empty or
## malformed input instead of throwing deep inside the package.

test_that("read_result_table tolerates NULL/NA/blank paths", {
  expect_null(read_result_table(NULL))
  expect_null(read_result_table(NA_character_))
  expect_null(read_result_table(""))
  expect_null(read_result_table(c("", NA)))
})

test_that("auto_find tolerates empty search paths and keys", {
  expect_length(auto_find(NULL), 0L)
  expect_length(auto_find(NA_character_), 0L)
  expect_length(auto_find(tempdir(), key = NA), 0L)  # key falls back
})

test_that("table primitives degrade to placeholders on empty data", {
  for (bad in list(NULL, data.frame(), matrix(nrow = 0, ncol = 2),
                   data.frame(a = character(0)))) {
    out <- table_block(bad, title = "t")
    expect_match(as.character(out), "rp-empty", fixed = TRUE)
  }
  ## empty_block text keeps the table title
  expect_match(as.character(table_block(NULL, title = "QC 表")),
    "QC 表", fixed = TRUE)
})

test_that("ctx$data_table does not consume a number for empty data", {
  tmp <- make_chip_fixture()
  ctx <- report_context(tmp, type = "1")
  ctx$.rp_set_module("mod-x")
  b1 <- ctx$data_table(data.frame(a = 1), title = "first")   # Table 1
  e <- ctx$data_table(NULL, title = "hole")                  # no number used
  b2 <- ctx$data_table(data.frame(a = 2), title = "second")  # Table 2
  html <- paste(as.character(as.list(b1)), collapse = "")
  eh <- paste(as.character(as.list(e)), collapse = "")
  h2 <- paste(as.character(as.list(b2)), collapse = "")
  expect_match(eh, "rp-empty", fixed = TRUE)
  expect_match(html, "Table 1", fixed = TRUE)
  expect_match(h2, "Table 2", fixed = TRUE)
})

test_that("figure and gallery tolerate empty/NA sources", {
  f <- figure_block(NA_character_, title = "gone")
  expect_match(as.character(f), "rp-fig", fixed = TRUE)
  expect_error(figure_block("/no/such/file.png", missing_ok = FALSE),
    "figure file not found")
  g <- gallery(list(a = NULL, b = NA_character_, c = ""))
  expect_match(as.character(g), "rp-empty", fixed = TRUE)
  g2 <- gallery(c(NA, "", NA))
  expect_match(as.character(g2), "rp-empty", fixed = TRUE)
})

test_that("callout / text_block / details_block skip empty input", {
  expect_length(as.list(callout()), 0L)
  expect_length(as.list(callout("")), 0L)
  expect_length(as.list(callout(NA_character_)), 0L)
  expect_length(as.list(text_block()), 0L)
  expect_length(as.list(details_block(NULL)), 0L)
  expect_match(as.character(callout("内容")), "rp-callout", fixed = TRUE)
})

test_that("kv_table / kpi handle empty and NA values", {
  expect_match(as.character(kv_table(NULL)), "无数据", fixed = TRUE)
  expect_match(as.character(kv_table(data.frame())), "无数据", fixed = TRUE)
  k <- kpi(NA, NA)
  expect_match(as.character(k), "–", fixed = TRUE)
  expect_false(grepl(">NA<", as.character(k), fixed = TRUE))
})

test_that("bib functions return NULL/empty instead of throwing", {
  expect_null(read_bib(NULL))
  expect_null(read_bib(NA_character_))
  expect_null(read_bib(tempfile("no-such-bib")))
  empty <- tempfile(fileext = ".bib")
  writeLines("   ", empty)
  expect_null(read_bib(empty))
  ## empty input -> valid (but contentless) reference list tag
  expect_s3_class(reference_list(NULL), "shiny.tag")
  expect_false(grepl("<li", as.character(reference_list(NULL)),
    fixed = TRUE))
  expect_false(grepl("<li", as.character(reference_list(data.frame())),
    fixed = TRUE))
})

test_that("render_report validates report/only arguments clearly", {
  expect_error(render_report(NULL), "create_report")
  tmp <- make_chip_fixture()
  ctx <- report_context(tmp, type = "1")
  report <- create_report(ctx) |> add_module(mod_chip_qc())
  expect_error(render_report(report, only = "no-such-module"),
    "no module matched")
  expect_error(render_report(report, output = NULL), "output")
})
