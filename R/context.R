#' Create a report context
#'
#' A report context (`ctx`) is the single object passed to every report
#' module. It bundles the analysis result directory, project metadata,
#' the automatic figure/table numbering counters and the section
#' registry used to build the sidebar table of contents. Modules must
#' never rely on global variables; everything they need is reachable
#' through the context.
#'
#' @details
#' The returned object is an environment of class `reporter_ctx` with
#' fields and methods:
#'
#' - `meta` — named list with `result_path`, `species`, `project`,
#'   `code`, `company`, `phonenum`, `logo`, `type`, `date`, `caption_lang`
#'   and the entries of `options`.
#' - `figure(path, title, description, width, ...)` — embed a figure
#'   (file path, auto base64 encoded) with an automatic English/Chinese
#'   "Figure N" caption; advances the figure counter.
#' - `data_table(data, title, description, ...)` — embed an interactive
#'   [reactable::reactable()] table with an automatic "Table N" caption;
#'   advances the table counter.
#' - `subsection(title, description)` — render an `<h3>` subsection
#'   heading with a stable anchor id and register it in the TOC.
#' - `find(...)` — shortcut to [auto_find()] scoped to `meta$result_path`.
#' - `note(text)`, `warning(text)`, `tip(text)` — shortcuts for
#'   [callout()].
#' - `counter_fig`, `counter_tbl` — integer-ish counter readouts.
#'
#' @param result_path character(1). Analysis result directory to scan.
#' @param species character(1). Species name, e.g. `"Homo_sapiens"`.
#' @param project character(1). Project / contract name.
#' @param code character(1). Project code (order number).
#' @param company character(1). Company name shown in navbar/footer.
#' @param phonenum character(1). Service phone shown in navbar/footer.
#' @param logo character(1). Brand preset name, e.g. `"smzy"`, `"jinyu"`
#'   or `"blank"`; resolved by [reporter_theme()].
#' @param type character(1). Analysis branch type flag (e.g. `"1"` with
#'   biological replicates / differential groups, `"0"` single group),
#'   mirroring the legacy `--type` option.
#' @param caption_lang character(1). `"en"` (default) renders figure and
#'   table captions as "Figure N / Table N"; `"zh"` renders "图 N / 表 N".
#' @param explain_file character(1). Optional path to a column-explanation
#'   workbook (same format as the bundled `TableExplain.xlsx`); `NULL`
#'   uses the bundled workbook. Consumed by `ctx$data_table()` auto
#'   explanations — see [load_explanations()].
#' @param options named list. Additional pipeline-specific options made
#'   available as `meta$options` (and flattened into `meta` on demand).
#'
#' @return An environment of class `reporter_ctx`.
#' @seealso [create_report()], [module()]
#' @export
#'
#' @examples
#' ctx <- report_context(
#'   result_path = tempdir(),
#'   species = "Homo_sapiens", project = "Demo project"
#' )
#' ctx$meta$result_path
report_context <- function(result_path,
                          species = NA_character_,
                          project = NA_character_,
                          code = NA_character_,
                          company = "",
                          phonenum = "",
                          logo = "blank",
                          type = "1",
                          caption_lang = c("en", "zh"),
                          explain_file = NULL,
                          ref_version = NA_character_,
                          fasta_db = NA_character_,
                          gtf_db = NA_character_,
                          options = list()) {
  result_path <- as.character(result_path)[1L]
  if (!dir.exists(result_path)) {
    stop("reporter: result_path does not exist: ", result_path, call. = FALSE)
  }
  caption_lang <- match.arg(caption_lang)
  options <- if (is.null(options)) list() else as.list(options)
  if (is.null(names(options))) names(options) <- rep("opt", length(options))

  meta <- list(
    result_path = result_path,
    species = species,
    project = project,
    code = code,
    company = company,
    phonenum = phonenum,
    logo = logo,
    type = type,
    date = Sys.Date(),
    caption_lang = caption_lang,
    explain_file = explain_file,
    ref_version = ref_version,
    fasta_db = fasta_db,
    gtf_db = gtf_db,
    options = options
  )

  ## counters and registry live in a private environment
  private <- new.env(parent = emptyenv())
  private$fig <- 0L
  private$tbl <- 0L
  private$toc <- list()
  private$current_module <- NULL

  ctx <- new.env(parent = emptyenv())
  class(ctx) <- "reporter_ctx"

  ## ------------------------------------------------------------------
  ## meta: plain named list; ctx$meta$species etc.; pipeline options
  ## live under ctx$meta$options$<name>
  ## ------------------------------------------------------------------
  ctx$meta <- meta

  ## ------------------------------------------------------------------
  ## internal: next counters
  ## ------------------------------------------------------------------
  next_fig <- function() {
    private$fig <- private$fig + 1L
    private$fig
  }
  next_tbl <- function() {
    private$tbl <- private$tbl + 1L
    private$tbl
  }

  caption_for <- function(kind, n) {
    if (identical(ctx$meta$caption_lang, "zh")) {
      paste0(switch(kind, figure = "图", table = "表"), " ", n)
    } else {
      paste0(switch(kind, figure = "Figure", table = "Table"), " ", n)
    }
  }

  ## ------------------------------------------------------------------
  ## internal: register a toc entry under the current module
  ## ------------------------------------------------------------------
  register_toc <- function(title, id, level = 3L) {
    module <- private$current_module
    private$toc[[length(private$toc) + 1L]] <- list(
      module = module, title = title, id = id, level = level
    )
    invisible(NULL)
  }

  ## ------------------------------------------------------------------
  ## public methods
  ## ------------------------------------------------------------------
  ctx$subsection <- function(title, description = NULL) {
    id <- rp_slug(title, prefix = "sec-")
    register_toc(title, id, level = 3L)
    sub_head(id = id, title = title, description = description)
  }

  ctx$figure <- function(path, title, description = NULL,
                         width = NULL, ...) {
    n <- next_fig()
    caption <- caption_for("figure", n)
    figure_block(
      src = path, number = n, title = title,
      caption = caption, description = description,
      width = width, ...
    )
  }

  ## ---- column-explanation registry (lazy, cached) --------------------
  .explain_reg <- NULL
  ctx$explain_registry <- function() {
    if (is.null(.explain_reg)) {
      .explain_reg <<- load_explanations(meta$explain_file)
    }
    .explain_reg
  }

  ## Resolve column explanations for a rendered table. `sheet` pins the
  ## workbook sheet (authoritative); otherwise only unambiguous columns
  ## are returned. See load_explanations().
  ctx$explain <- function(cols, sheet = NULL) {
    explain_table(cols, ctx$explain_registry(), sheet = sheet)
  }

  ctx$data_table <- function(data, title = NULL, description = NULL,
                             explain = TRUE, explain_sheet = NULL, ...) {
    ## defensive: empty input -> placeholder WITHOUT consuming a table
    ## number (a skipped table must not leave a numbering hole)
    if (!rp_df_usable(data)) {
      data <- tryCatch(as.data.frame(data), error = function(e) NULL)
    }
    if (!rp_df_usable(data)) {
      return(empty_block(paste0(title %||% "该表格", "：无数据")))
    }
    n <- next_tbl()
    caption <- caption_for("table", n)
    block <- table_block(
      data = data, number = n, title = title,
      caption = caption, description = description, ...
    )
    if (!isTRUE(explain)) return(block)
    reg <- tryCatch(ctx$explain_registry(), error = function(e) NULL)
    if (!length(reg)) return(block)
    ## every column gets a row; unmatched ones show 待更新
    ex <- tryCatch(
      explain_table(names(data), reg, sheet = explain_sheet, fill = "待更新"),
      error = function(e) NULL
    )
    ## always attach: every column gets a row, unresolved ones show
    ## 待更新 so missing explanations stay visible (author can fill the
    ## registry workbook to complete them)
    tagList(
      block,
      details_block(
        content = data_table(ex, searchable = FALSE, show_page_sizes = FALSE,
                             default_page_size = 30L, wrap = TRUE,
                             align = "left"),
        summary = "点击查看表格解释："
      )
    )
  }

  ctx$gallery <- function(images, title, description = NULL, ...) {
    n <- next_fig()
    caption <- caption_for("figure", n)
    gallery(
      images = images, title = title, caption = caption,
      description = description, ...
    )
  }

  ctx$find <- function(pattern, dir = NULL, key = "xxx", strict = FALSE,
                       gap = "\\.", in_base = TRUE, in_dirname = FALSE,
                       recursive = TRUE) {
    auto_find(
      search_path = if (is.null(dir)) ctx$meta$result_path else
        file.path(ctx$meta$result_path, dir),
      format_str = pattern, key = key, strict = strict, gap = gap,
      in_base = in_base, in_dirname = in_dirname, recursive = recursive
    )
  }

  ctx$note <- function(...) callout(..., type = "note")
  ctx$warning <- function(...) callout(..., type = "warning")
  ctx$tip <- function(...) callout(..., type = "tip")

  ctx$counter_fig <- function() private$fig
  ctx$counter_tbl <- function() private$tbl

  ## framework-internal hooks (not part of the user contract)
  ctx$.rp_set_module <- function(id) private$current_module <- id
  ctx$.rp_toc_entries <- function() private$toc
  ctx$.rp_counters <- function() c(fig = private$fig, tbl = private$tbl)

  ctx
}

#' @export
print.reporter_ctx <- function(x, ...) {
  cat("<reporter_ctx>\n")
  cat("  result_path :", x$meta$result_path, "\n")
  cat("  species     :", x$meta$species, "\n")
  cat("  project     :", x$meta$project, "\n")
  cat("  figures     :", x$counter_fig(), "\n")
  cat("  tables      :", x$counter_tbl(), "\n")
  invisible(x)
}
