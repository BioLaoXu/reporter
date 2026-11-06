#' Column-explanation registry (bundled TableExplain workbook)
#'
#' Loads the "table column meaning" workbook (originally
#' `lib/TableExplain.xlsx`, one sheet per result table, two columns:
#' column name and human-readable explanation) into a lookup registry
#' that [report_context()] uses to attach explanations to rendered
#' tables automatically.
#'
#' The registry keeps every (sheet, explanation) pair per column: the
#' same column name may carry different meanings in different tables
#' (e.g. `TotalReads` means raw reads in the QC sheet but clean reads in
#' the mapping sheet). Auto-attaching explanations is therefore
#' unambiguous only when a column has a single explanation; modules can
#' resolve ambiguity explicitly with `explain_sheet =`.
#'
#' @param xlsx character(1). Path to the workbook; defaults to the copy
#'   bundled in `inst/extdata/`. A per-project workbook can be passed to
#'   [report_context()] instead.
#' @return A named list: column name -> data frame with columns `sheet`
#'   and `explanation` (one row per distinct meaning).
#' @seealso [report_context()], [table_explain()]
#' @export
#'
#' @examples
#' \donttest{
#' reg <- load_explanations()
#' reg$SampleName   # one meaning
#' reg$TotalReads   # possibly several sheets
#' }
load_explanations <- function(xlsx = NULL) {
  xlsx <- xlsx %||% system.file(
    "extdata", "TableExplain.xlsx", package = "reporter")
  if (is.null(xlsx) || !file.exists(xlsx)) return(list())
  sheets <- tryCatch(readxl::excel_sheets(xlsx), error = function(e) character())
  reg <- list()
  for (s in sheets) {
    d <- tryCatch(
      as.data.frame(readxl::read_excel(xlsx, sheet = s, col_types = "text")),
      error = function(e) NULL
    )
    if (is.null(d) || ncol(d) < 2L || nrow(d) == 0L) next
    keys <- trimws(as.character(d[[1L]]))
    vals <- trimws(as.character(d[[2L]]))
    ok <- !is.na(keys) & nzchar(keys) & !is.na(vals) & nzchar(vals)
    if (!any(ok)) next
    for (i in which(ok)) {
      row <- data.frame(sheet = s, explanation = vals[i], stringsAsFactors = FALSE)
      if (keys[i] %in% names(reg)) {
        prev <- reg[[keys[i]]]
        if (!any(prev$sheet == s & prev$explanation == vals[i])) {
          reg[[keys[i]]] <- rbind(prev, row)
        }
      } else {
        reg[[keys[i]]] <- row
      }
    }
  }
  reg
}

#' Resolve explanations for a set of table columns
#'
#' @param cols character vector. Column names of the report table.
#' @param registry Named list from [load_explanations()].
#' @param sheet character(1). Optional sheet name; when given, columns
#'   are resolved within that sheet only (authoritative disambiguation).
#' @param fill character(1) or NULL. When non-NULL, unresolved columns
#'   are kept as rows with this placeholder text (e.g. `"待更新"`),
#'   instead of being dropped — used by `ctx$data_table()` so the
#'   explanation table always covers every column of the report table.
#' @return A data frame with columns `表格列名` and `解释` (plus `来源`
#'   in auto mode), or `NULL` when nothing matched.
#' @export
explain_table <- function(cols, registry = load_explanations(),
                          sheet = NULL, fill = NULL) {
  cols <- as.character(cols)
  cols <- cols[nzchar(cols)]
  if (!length(cols) || !length(registry)) return(NULL)
  rows <- list()
  for (col in cols) {
    hit <- registry[[col]]
    if (is.null(hit)) next
    if (!is.null(sheet)) {
      hit <- hit[hit$sheet == sheet, , drop = FALSE]
      if (nrow(hit) == 0L) next
      rows[[length(rows) + 1L]] <- data.frame(
        `表格列名` = col, `解释` = hit$explanation[1L],
        check.names = FALSE, stringsAsFactors = FALSE)
    } else if (nrow(hit) == 1L) {
      ## unambiguous column: safe to auto-attach
      rows[[length(rows) + 1L]] <- data.frame(
        `表格列名` = col, `解释` = hit$explanation[1L],
        check.names = FALSE, stringsAsFactors = FALSE)
    }
    ## ambiguous without an explicit sheet: skipped in auto mode
  }
  if (!length(rows) && is.null(fill)) return(NULL)
  out <- if (length(rows)) do.call(rbind, rows) else
    data.frame(`表格列名` = character(0), `解释` = character(0),
      check.names = FALSE, stringsAsFactors = FALSE)
  ## defensive: columns with no explanation get the placeholder text
  if (!is.null(fill)) {
    missing <- setdiff(cols, out[["表格列名"]])
    if (length(missing)) {
      out <- rbind(out, data.frame(
        `表格列名` = missing, `解释` = fill,
        check.names = FALSE, stringsAsFactors = FALSE))
      out <- out[order(match(out[["表格列名"]], cols)), , drop = FALSE]
    }
  }
  if (nrow(out) == 0L) return(NULL)
  out[!duplicated(out[["表格列名"]]), , drop = FALSE]
}
