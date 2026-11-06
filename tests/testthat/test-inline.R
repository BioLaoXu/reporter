test_that("inline_html folds script/link references into one file", {
  d <- file.path(tempdir(), "inline-demo")
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
  page <- htmltools::tagList(
    htmltools::tags$head(htmltools::tags$meta(charset = "UTF-8"),
      htmltools::tags$title("t")),
    htmltools::tags$body(
      htmltools::tags$h2("hello"),
      reactable::reactable(data.frame(a = 1:2))
    )
  )
  f <- file.path(d, "index.html")
  htmltools::save_html(page, f, libdir = "lib")
  single <- file.path(d, "single.html")
  inline_html(f, single, libdir = file.path(d, "lib"))
  html <- paste(readLines(single, warn = FALSE), collapse = "\n")

  expect_false(grepl('src="lib/', html))
  expect_false(grepl('href="lib/', html))
  expect_match(html, "Reactable")          # widget runtime survived
  expect_match(html, "<style>")            # css inlined
  expect_match(html, "charset")            # charset preserved
  expect_gt(file.size(single), file.size(f) - 1) # only grows
})

test_that("inline_html refuses to overwrite when asked not to", {
  d <- file.path(tempdir(), "inline-ow")
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
  f <- file.path(d, "index.html")
  writeLines("<html><body>x</body></html>", f)
  dir.create(file.path(d, "lib"))
  out <- file.path(d, "out.html")
  writeLines("old", out)
  expect_error(inline_html(f, out, file.path(d, "lib"), overwrite = FALSE),
    "exists")
})
