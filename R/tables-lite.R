## ---------------------------------------------------------------------
## lite rendering engine (P1): dependency-free native data grids
## ---------------------------------------------------------------------
## The "lite" engine replaces reactable/Bootstrap runtime with plain
## HTML tables + a small vanilla-JS enhancer (reporter-lite.js):
## search, column sort, CSV export. Selected via
## render_report(engine = "lite"), spec `engine:` or CLI --engine.

## internal: detect numeric columns for right-aligned monospace cells
rp_lite_is_num <- function(x) {
  is.numeric(x) && !inherits(x, c("Date", "POSIXct", "POSIXlt"))
}

## internal: one lite table (server-side full DOM, JS enhances it)
rp_table_lite <- function(data, dom_id = NULL, toolbar = TRUE,
                          max_rows = 500L, explain = NULL) {
  stopifnot(rp_df_usable(data))
  if (nrow(data) > max_rows) {
    data <- data[seq_len(max_rows), , drop = FALSE]
    trunc_note <- paste0("（仅展示前 ", max_rows, " 行，完整数据见交付文件）")
  } else trunc_note <- NULL
  num_cols <- vapply(data, rp_lite_is_num, logical(1L))
  cols <- names(data)

  head_cells <- lapply(seq_along(cols), function(j) {
    help <- NULL
    if (!is.null(explain) && !is.null(explain[[cols[[j]]]])) {
      tip <- explain[[cols[[j]]]]
      help <- tags$span(class = "rp-col-help",
        title = if (tip == "待更新") "列名解释待更新" else tip, "?")
    }
    tags$th(
      class = if (num_cols[[j]]) "num" else NULL,
      title = cols[[j]],
      HTML(rp_inline_md(cols[[j]])),
      help
    )
  })
  body_rows <- lapply(seq_len(nrow(data)), function(i) {
    cells <- lapply(seq_along(cols), function(j) {
      v <- data[[j]][[i]]
      v <- if (is.na(v) || rp_is_empty(v)) "" else as.character(v)
      tags$td(class = if (num_cols[[j]]) "num" else NULL,
        title = if (nzchar(v)) v else NULL, v)
    })
    tags$tr(cells)
  })

  tags$div(
    class = "rp-grid",
    `data-rp-grid` = dom_id,
    if (toolbar) {
      tags$div(
        class = "rp-grid-toolbar",
        tags$input(class = "rp-grid-search", type = "text",
                   placeholder = "搜索…", `aria-label` = "search"),
        tags$button(class = "rp-grid-export", type = "button",
                    `data-rp-grid` = dom_id, "导出 CSV"),
        tags$span(class = "rp-grid-count"),
        tags$span(class = "rp-grid-pager",
          tags$button(class = "rp-grid-page-btn", `data-page` = "prev",
            type = "button", "上一页"),
          tags$span(class = "rp-grid-page-info", "1 / 1"),
          tags$button(class = "rp-grid-page-btn", `data-page` = "next",
            type = "button", "下一页"))
      )
    },
    tags$div(
      class = "rp-table-wrap",
      tags$table(
        class = "rp-table",
        id = dom_id,
        tags$thead(tags$tr(head_cells)),
        tags$tbody(body_rows)
      )
    ),
    if (!is.null(trunc_note)) {
      tags$p(class = "rp-tbl-desc", trunc_note)
    },
  )
}

#' Table block for the lite engine
#'
#' Native-HTML variant of [table_block()] used when the rendering engine
#' is `"lite"`: no reactable/Bootstrap runtime, the grid is enhanced by
#' `reporter-lite.js` (search/sort/CSV export).
#'
#' @param data A data frame.
#' @inheritParams table_block
#' @param dom_id character(1). Wrapper element id (used by the JS grid
#'   and the CSV file name).
#' @param data_attrs named list. Extra attributes for the wrapper div
#'   (data-rp-* anchors).
#' @param max_rows integer(1). Rows rendered server-side; larger tables
#'   are truncated with a note (full data stays in the delivery files).
#' @return A `htmltools` [tagList()].
#' @keywords internal
table_lite_block <- function(data, number = NULL, title = NULL,
                             caption = NULL, description = NULL,
                             dom_id = NULL, data_attrs = NULL,
                             max_rows = 500L, explain = NULL) {
  if (is.null(caption) && !is.null(number)) {
    caption <- paste("Table", number)
  }
  grid <- rp_table_lite(data, dom_id = dom_id, toolbar = TRUE,
                        max_rows = max_rows, explain = explain)
  tbl_div <- tags$div(
    class = "rp-tbl",
    id = dom_id,
    if (!is.null(caption) || !is.null(title) || !is.null(number)) {
      tags$div(
        class = "rp-tbl-caption",
        if (!is.null(caption)) {
          tags$span(class = "rp-badge rp-badge-tbl", caption)
        },
        if (!is.null(title)) tags$span(class = "rp-tbl-title", HTML(title))
      )
    },
    grid,
    if (!is.null(description)) {
      tags$p(class = "rp-tbl-desc", HTML(description))
    }
  )
  if (length(data_attrs)) {
    tbl_div <- do.call(htmltools::tagAppendAttributes,
      c(list(tbl_div), data_attrs))
  }
  tagList(tbl_div)
}
