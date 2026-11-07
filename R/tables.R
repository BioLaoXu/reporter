#' Interactive data table
#'
#' Build an interactive [reactable::reactable()] with package defaults
#' tuned for bioinformatics result tables (centered cells, striped rows,
#' optional search box, page size selector). This is the raw widget
#' builder; for automatic "Table N" numbering use `ctx$data_table()`.
#'
#' @param data A data frame or matrix.
#' @param searchable logical(1). Show the search box.
#' @param filterable logical(1). Enable per-column filters.
#' @param show_page_sizes logical(1). Show page size selector.
#' @param default_page_size integer(1). Rows per page.
#' @param page_size_options integer vector. Page size choices.
#' @param max_char integer(1). Truncate cell text (with tooltip) beyond
#'   this many characters when `truncate` is a character vector of column
#'   names; `0` disables.
#' @param truncate character vector. Column names to render with the
#'   tippy tooltip cell renderer (migration of the legacy
#'   `renderCols()`); `NULL` disables.
#' @param columns Optional named list of [reactable::colDef()] overrides,
#'   merged on top of computed defaults.
#' @param wrap logical(1). Wrap long text in cells.
#' @param align character(1). Default cell alignment.
#' @param height character(1). Optional fixed height with scroll,
#'   e.g. `"400px"`.
#' @param ... Additional arguments passed to [reactable::reactable()].
#' @return A [reactable::reactable()] htmlwidget.
#' @seealso [table_block()], [render_cols()]
#' @export
#'
#' @examples
#' \dontrun{
#' data_table(head(mtcars), searchable = TRUE, truncate = c("disp", "hp"))
#' }
data_table <- function(data,
                       searchable = TRUE,
                       filterable = FALSE,
                       show_page_sizes = TRUE,
                       default_page_size = 10L,
                       page_size_options = c(10L, 20L, 50L, 100L),
                       truncate = NULL,
                       max_char = 30L,
                       columns = NULL,
                       wrap = TRUE,
                       align = "center",
                       height = NULL,
                       ...) {
  if (inherits(data, "matrix")) data <- as.data.frame(data)
  stopifnot(inherits(data, "data.frame"))

  base_cols <- reactable::colDef(align = align, minWidth = 90L)
  if (!is.null(truncate) && length(truncate) > 0L) {
    cols <- render_cols(truncate, max_char = max_char)
    cols <- cols[vapply(names(cols), function(n) n %in% names(data), logical(1L))]
  } else {
    cols <- list()
  }
  ## merge user colDefs on top (user wins)
  if (!is.null(columns)) cols <- utils::modifyList(cols, columns, keep.null = TRUE)

  reactable::reactable(
    data,
    searchable = searchable,
    filterable = filterable,
    showPageSizeOptions = show_page_sizes,
    pageSizeOptions = page_size_options,
    defaultPageSize = default_page_size,
    highlight = TRUE,
    striped = TRUE,
    wrap = wrap,
    resizable = TRUE,
    defaultColDef = base_cols,
    columns = if (length(cols)) cols else NULL,
    theme = reactable::reactableTheme(
      headerStyle = list(
        background = "var(--rp-tbl-header-bg, #EDF2F5)",
        color = "var(--rp-tbl-header-fg, #084C66)",
        fontWeight = 600,
        `&:hover` = list(background = "var(--rp-tbl-header-hover, #E2EAEF)")
      ),
      searchInputStyle = list(width = "100%")
    ),
    height = height,
    ...
  )
}

#' Truncated cell with native hover tooltip for long values
#'
#' Migration of the legacy `render.reactable.cell.with.tippy()`. Uses a
#' **native HTML `title` attribute** instead of the tippy js widget:
#' works in any offline single-file report with zero JS dependencies
#' (tippy's widget init proved unreliable inside inlined reports).
#'
#' @param text character(1). Cell value.
#' @param tooltip character(1). Tooltip content (defaults to `text`).
#' @return A `htmltools` div.
#' @export
tippy_cell <- function(text, tooltip = text) {
  text <- as.character(text)
  tooltip <- as.character(tooltip)
  htmltools::div(
    class = "rp-tippy-cell",
    title = tooltip,
    text
  )
}

#' Build tooltip renderers for selected columns
#'
#' Migration of the legacy `renderCols()`: returns a named list of
#' [reactable::colDef()] objects for `columns=` in [data_table()], where
#' each listed column renders with a native hover tooltip carrying the
#' full value.
#'
#' @param col_names character vector. Column names present in the data.
#' @param max_char integer(1). Values longer than this are visually
#'   truncated via CSS (tooltip always shows the full value).
#' @return Named list of `colDef` objects.
#' @export
#'
#' @examples
#' \dontrun{
#' cols <- render_cols(c("Gene", "Description"), max_char = 40)
#' reactable::reactable(df, columns = cols)
#' }
render_cols <- function(col_names, max_char = 30L, explain = NULL) {
  stopifnot(is.character(col_names), is.numeric(max_char), length(max_char) == 1L)
  out <- lapply(col_names, function(x) {
    help <- NULL
    if (!is.null(explain) && !is.null(explain[[x]])) {
      tip <- explain[[x]]
      help <- htmltools::tags$span(class = "rp-col-help",
        title = if (tip == "待更新") "列名解释待更新" else tip, "?")
    }
    reactable::colDef(
      html = TRUE,
      header = htmltools::tags$span(class = "rp-col-head", x, help),
      cell = function(value, index, name) {
        as.character(tippy_cell(text = value, tooltip = value))
      }
    )
  })
  names(out) <- col_names
  out
}

#' Column explanation table (bundled TableExplain)
#'
#' Migration of the legacy `addexplain()`: reads the "table column
#' meaning" workbook bundled with the package (originally
#' `lib/TableExplain.xlsx`), restricts it to the report table's actual
#' columns, and renders it as a collapsed [details_block()] with an
#' interactive explanation table.
#'
#' @param sheet Sheet name or number of the explanation workbook.
#' @param colns character vector. Column names to keep (order
#'   preserved); `NULL` shows all rows.
#' @param excel_file character(1). Path to the workbook; defaults to
#'   the copy bundled in `inst/extdata/`.
#' @param show_text character(1). Toggle handle text.
#' @return A [htmltools::tagList()] (details block).
#' @export
#'
#' @examples
#' \donttest{
#' table_explain("QC", c("SampleName", "RawReads"))
#' }
table_explain <- function(sheet, colns = NULL,
                          excel_file = system.file(
                            "extdata", "TableExplain.xlsx",
                            package = "reporter"
                          ),
                          show_text = "点击查看表格解释：") {
  if (!file.exists(excel_file)) return(NULL)
  tbl <- tryCatch(
    as.data.frame(readxl::read_excel(excel_file, sheet = sheet)),
    error = function(e) NULL
  )
  if (is.null(tbl)) return(NULL)
  if (!is.null(colns)) {
    key_col <- names(tbl)[1L]
    hit <- tbl[[key_col]] %in% colns
    tbl <- tbl[hit, , drop = FALSE]
    tbl <- tbl[order(match(tbl[[key_col]], colns)), , drop = FALSE]
  }
  if (nrow(tbl) == 0L) return(NULL)
  details_block(
    content = data_table(tbl, searchable = FALSE,
      default_page_size = 30L, wrap = TRUE, align = "left"),
    summary = show_text
  )
}
