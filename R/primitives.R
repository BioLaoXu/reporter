#' Figure block
#'
#' Low-level building block embedding one image with an optional numbered
#' caption. The module-facing entry point is `ctx$figure()`, which calls
#' this function after advancing the report-wide figure counter. Image
#' files are base64 encoded on creation so the final report can be a
#' single self-contained HTML file.
#'
#' @param src character(1). One of: a path to a local image file, an
#'   existing `data:` URI, or an `http(s)://` URL (not inlined).
#' @param number integer(1). Figure number to display (e.g. from the
#'   context counter); `NULL` omits the number badge.
#' @param title character(1). Figure title shown in the caption.
#' @param caption character(1). Prefix label, e.g. "Figure 3" or "图 3";
#'   `NULL` suppresses the caption row.
#' @param description character(1). Optional explanation rendered below
#'   the title; HTML is allowed.
#' @param width character(1). CSS width for the image, e.g. `"100%"`,
#'   `"640px"`.
#' @param id character(1). Optional anchor id for the block.
#' @param download_name character(1). Optional file name hint shown in
#'   the lightbox save button.
#' @param missing_ok logical(1). When TRUE (default) a missing file
#'   renders a transparent placeholder instead of failing the report.
#' @return A `htmltools` [tagList()] (single `<figure>` element).
#' @seealso [report_context()]
#' @export
#'
#' @examples
#' fig <- figure_block(
#'   src = system.file("img", "Rlogo.png", package = "png"),
#'   number = 1L, title = "Example figure", caption = "Figure 1"
#' )
figure_block <- function(src, number = NULL, title = NULL, caption = NULL,
                         description = NULL, width = NULL, id = NULL,
                         download_name = NULL, missing_ok = TRUE,
                         data_attrs = NULL) {
  stopifnot(is.null(number) || (is.numeric(number) && length(number) == 1L))
  src <- rp_char1(src)
  if (is.null(caption) && !is.null(number)) {
    caption <- paste("Figure", number)
  }

  missing_file <- is.null(src) || (!grepl("^data:", src) &&
    !grepl("^(https?|file)://", src) && !file.exists(src))
  if (missing_file && !isTRUE(missing_ok)) {
    stop("reporter: figure file not found: ", src %||% "<NULL>", call. = FALSE)
  }
  if (missing_file) {
    ## NA/blank/absent source -> transparent placeholder (never breaks
    ## the report); an NA path must not reach file.exists()/grepl()
    uri <- rp_data_uri(NA_character_, placeholder = TRUE)
  } else if (grepl("^data:", src) || grepl("^(https?|file)://", src)) {
    uri <- src
  } else {
    uri <- rp_data_uri(src, placeholder = TRUE)
  }

  caption_row <- NULL
  if (!is.null(caption) || !is.null(title) || !is.null(number)) {
    caption_row <- tags$figcaption(
      class = "rp-figcaption",
      if (!is.null(caption)) {
        tags$span(class = "rp-badge rp-badge-fig", caption)
      },
      if (!is.null(title)) tags$span(class = "rp-fig-title", HTML(title))
    )
  }

  img_tag <- tags$img(
    class = "rp-fig-img", src = uri, alt = title %||% "figure",
    tabindex = 0,
    style = if (!is.null(width)) css(width = width) else NULL,
    `data-rp-lightbox` = if (isTRUE(!is.null(download_name))) "1" else NULL,
    `data-rp-download` = download_name %||% NULL,
    onerror = "this.classList.add('rp-img-broken')"
  )

  fig <- tags$figure(
    class = "rp-fig",
    id = id,
    img_tag,
    caption_row,
    if (!is.null(description)) {
      tags$p(class = "rp-fig-desc", HTML(description))
    }
  )
  ## machine-readable anchors (data-rp-*) for the embedded report schema
  if (length(data_attrs)) {
    fig <- do.call(htmltools::tagAppendAttributes, c(list(fig), data_attrs))
  }
  tagList(fig)
}

#' Table block
#'
#' Low-level building block embedding one result table (a data frame or
#' an existing [reactable::reactable()] htmlwidget) with an optional
#' numbered caption. The module-facing entry point is `ctx$data_table()`.
#'
#' @param data A data frame (converted to a reactable with package
#'   defaults) or an existing htmlwidget.
#' @param number integer(1). Table number displayed in the caption;
#'   `NULL` omits the badge.
#' @param title character(1). Table title shown in the caption.
#' @param caption character(1). Prefix label, e.g. "Table 2" or "表 2".
#' @param description character(1). Optional explanation under the caption.
#' @param ... Passed on to [data_table()] when `data` is a data frame.
#' @return A `htmltools` [tagList()].
#' @seealso [data_table()], [report_context()]
#' @export
table_block <- function(data, number = NULL, title = NULL, caption = NULL,
                        description = NULL, dom_id = NULL,
                        data_attrs = NULL, ...) {
  if (is.null(caption) && !is.null(number)) {
    caption <- paste("Table", number)
  }
  ## defensive: NULL / zero-row / non-table input degrades to an
  ## empty placeholder instead of an obscure error deep in reactable
  if (!rp_df_usable(data) && !inherits(data, "htmlwidget")) {
    return(tagList(
      tags$div(
        class = "rp-tbl",
        tags$div(
          class = "rp-tbl-caption",
          if (!is.null(caption)) {
            tags$span(class = "rp-badge rp-badge-tbl", caption)
          },
          if (!is.null(title)) tags$span(class = "rp-tbl-title", HTML(title))
        ),
        empty_block("表格数据为空或格式不受支持。")
      )
    ))
  }
  if (inherits(data, "data.frame")) {
    widget <- data_table(data, ...)
  } else {
    widget <- data
  }
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
    widget,
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

#' Subsection heading
#'
#' Renders an `<h3>` heading with a stable anchor id. Called by
#' `ctx$subsection()`, which additionally registers the section in the
#' sidebar TOC; this standalone version is for ad-hoc headings.
#'
#' @param title character(1). Heading text (HTML allowed).
#' @param description character(1). Optional lead-in paragraph under the
#'   heading (HTML allowed).
#' @param id character(1). Optional anchor id.
#' @return A `htmltools` [tagList()].
#' @export
subsection <- function(title, description = NULL, id = NULL) {
  sub_head(id = id %||% rp_slug(title, prefix = "sec-"),
           title = title, description = description)
}

#' @noRd
sub_head <- function(id, title, description = NULL) {
  tagList(
    tags$h3(id = id, class = "rp-subsection", HTML(title)),
    if (!is.null(description)) {
      tags$p(class = "rp-lead", HTML(description))
    }
  )
}

#' Callout box
#'
#' Semantic notice box used for QC verdicts, threshold notes and caveats.
#' Migrates and generalises the legacy inline `<div class='expdiv'>`
#' chunks from the Rmd-era utils.
#'
#' @param text character(1). Message body; HTML allowed.
#' @param type character(1). One of `note`, `tip`, `warning`, `danger`.
#' @param title character(1). Optional bold heading inside the box.
#' @return A `htmltools` [tagList()].
#' @export
#'
#' @examples
#' callout("All samples passed the QC threshold.", type = "note")
callout <- function(..., type = c("note", "tip", "warning", "danger",
                                  "key", "guardrail"),
                    title = NULL) {
  type <- match.arg(type)
  parts <- unlist(list(...))
  parts <- parts[!is.na(parts) & nzchar(as.character(parts))]
  text <- paste(parts, collapse = "")
  ## defensive: an entirely empty callout renders nothing at all
  if (!nzchar(text) && is.null(title)) return(tagList())
  icon <- switch(type,
    note = rp_icon("info"),
    tip = rp_icon("bulb"),
    warning = rp_icon("warn"),
    danger = rp_icon("alert")
  )
  tagList(
    tags$div(
      class = paste0("rp-callout rp-callout-", type),
      tags$span(class = "rp-callout-icon", icon),
      tags$div(
        class = "rp-callout-body",
        if (!is.null(title)) {
          tags$strong(class = "rp-callout-title", HTML(title))
        },
        tags$span(HTML(text))
      )
    )
  )
}

#' Single KPI metric (used with [kpi_row()])
#'
#' @param value character(1). Displayed metric value, e.g. `"93.5%"`.
#' @param label character(1). Short metric label.
#' @param status character(1). Semantic quality state: `neutral`, `ok`,
#'   `warn` or `bad` (drives the indicator color).
#' @return A `htmltools` [tagList()].
#' @export
kpi <- function(value, label, status = c("neutral", "ok", "warn", "bad")) {
  status <- match.arg(status)
  ## defensive: NA/empty values render as an en dash instead of "NA"
  value <- rp_char1(value) %||% "–"
  label <- rp_char1(label) %||% "–"
  tags$div(
    class = paste("rp-kpi", paste0("rp-kpi-", status)),
    tags$div(class = "rp-kpi-value", HTML(value)),
    tags$div(class = "rp-kpi-label", HTML(label))
  )
}

#' Horizontal KPI metric row
#'
#' A 10x-Genomics-style row of headline metrics: big tabular numbers with
#' small labels and an optional semantic quality color per metric. Place
#' it at the top of a module to let the reader judge overall quality at a
#' glance (detailed tables follow below).
#'
#' @param ... [kpi()] objects.
#' @return A `htmltools` [tagList()].
#' @seealso [kpi()]
#' @export
kpi_row <- function(...) {
  items <- list(...)
  items <- items[vapply(items, function(x) inherits(x, "shiny.tag"), logical(1L))]
  if (!length(items)) return(tagList())
  tagList(tags$div(class = "rp-kpi-row", tagList(items)))
}

#' Key-value info table
#'
#' Two-column presentation of project metadata (species, reference
#' version, sample count, ...). Accepts a named character vector/list or
#' a two-column data frame.
#'
#' @param data Named list/vector, or a data frame whose first column is
#'   keys and second column values.
#' @param key_title character(1). Header for the key column.
#' @param value_title character(1). Header for the value column.
#' @param id character(1). Optional anchor id.
#' @return A `htmltools` [tagList()].
#' @export
kv_table <- function(data, key_title = "Item", value_title = "Value",
                     id = NULL) {
  ## defensive: NULL / zero-length input -> empty placeholder table
  if (rp_is_empty(data) ||
      (is.data.frame(data) && (nrow(data) == 0L || ncol(data) < 2L))) {
    return(tagList(
      tags$table(
        class = "rp-kv", id = id,
        tags$thead(tags$tr(tags$th(key_title), tags$th(value_title))),
        tags$tbody(tags$tr(
          tags$td(class = "rp-kv-key", colspan = "2", "（无数据）")
        ))
      )
    ))
  }
  if (inherits(data, "data.frame")) {
    kv <- data[, 1L, drop = TRUE]
    vv <- data[, 2L, drop = TRUE]
  } else {
    kv <- names(data)
    vv <- as.character(unlist(data, use.names = FALSE))
  }
  if (is.null(kv)) kv <- rep("", length(vv))
  tagList(
    tags$table(
      class = "rp-kv", id = id,
      tags$thead(tags$tr(
        tags$th(key_title), tags$th(value_title)
      )),
      tags$tbody(
        Map(function(k, v) {
          tags$tr(tags$td(class = "rp-kv-key", HTML(as.character(k))),
                  tags$td(class = "rp-kv-val", HTML(as.character(v))))
        }, kv, vv)
      )
    )
  )
}

#' Empty-result placeholder
#'
#' Migration of the legacy `fillEmpty()`: renders a neutral notice used
#' when an optional analysis produced no output, so readers are told to
#' ignore the section instead of wondering whether something broke.
#'
#' @param text character(1). Notice text.
#' @return A `htmltools` [tagList()].
#' @export
empty_block <- function(text = "相应分析结果为空，请忽略本小节的报告内容") {
  tagList(
    tags$div(
      class = "rp-empty",
      rp_icon("empty"),
      tags$span(HTML(text))
    )
  )
}

#' Collapsible details block
#'
#' Migration and unification of the legacy `addexplain()`, `table2detial()`
#' and `addHtml()`: wraps arbitrary content (widget, tag list, raw HTML
#' or an htmlwidget) in a `<details><summary>` element so long reference
#' tables stay collapsed by default.
#'
#' @param content A tag list, htmlwidget, or character HTML string.
#' @param summary character(1). Text of the toggle handle.
#' @param open logical(1). Whether the block starts expanded.
#' @return A `htmltools` [tagList()].
#' @export
details_block <- function(content, summary = "点击查看详情",
                          open = FALSE) {
  ## defensive: no content -> no collapsed block at all
  if (rp_is_empty(content) && !inherits(content, "htmlwidget")) {
    return(tagList())
  }
  summary <- rp_char1(summary) %||% "点击查看详情"
  content_tag <- if (inherits(content, "shiny.tag") ||
    inherits(content, "shiny.tag.list") ||
    inherits(content, "htmlwidget")) {
    content
  } else {
    HTML(as.character(content))
  }
  tagList(
    tags$details(
      class = "rp-details",
      ## htmltools omits NULL attributes and renders NA as a bare boolean
      open = if (isTRUE(open)) NA else NULL,
      tags$summary(class = "rp-details-summary", HTML(summary)),
      tags$div(class = "rp-details-body", content_tag)
    )
  )
}

#' File path note
#'
#' Migration of the legacy `add_file_path()`: shows the source file
#' directory of the current results in bold so customers can locate the
#' raw output on the delivery disk.
#'
#' @param path character(1). Directory or file path to display.
#' @return A `htmltools` [tagList()].
#' @export
file_path_note <- function(path, link = NULL) {
  body <- if (!is.null(link) && nzchar(link)) {
    tags$a(href = paste0("file://", link), target = "_blank",
      tags$span(rp_icon("folder"), class = "rp-filepath-icon"),
      tags$code(path))
  } else {
    list(tags$span(rp_icon("folder"), class = "rp-filepath-icon"),
      tags$code(path))
  }
  tagList(tags$p(class = "rp-filepath", body))
}

#' Image gallery
#'
#' Migration of the legacy `slick_pics()` / `slickR_Fig()` carousel without
#' jQuery/slick dependencies: per-sample figures are shown one at a time
#' with prev/next buttons and a searchable sample list. Images are base64
#' encoded on creation.
#'
#' @param images Named list (or character vector) of image paths; list
#'   names become the sample tab labels (fallback: file stem).
#' @param title character(1). Optional gallery caption.
#' @param caption character(1). Optional numbered prefix (e.g.
#'   "Figure 2") handled by the caller.
#' @param description character(1). Optional explanation.
#' @param miss_ok logical(1). Keep missing files as placeholders.
#' @return A `htmltools` [tagList()].
#' @export
#'
#' @examples
#' \dontrun{
#' imgs <- auto_find(result_dir, ".png", key = "frip")
#' gallery(imgs, title = "FRiP score plots")
#' }
gallery <- function(images, title = NULL, caption = NULL, description = NULL,
                    miss_ok = TRUE, data_attrs = NULL) {
  ## defensive: drop NULL/NA/blank entries before anything else
  if (!is.null(images) && is.list(images)) {
    images <- images[!vapply(images, rp_is_empty, logical(1L))]
  } else if (!is.null(images) && is.character(images)) {
    images <- images[!is.na(images) & nzchar(images)]
  }
  if (is.null(images) || length(images) == 0L) {
    return(empty_block())
  }
  ## keep only real raster/vector image files: QC/Pipeline dirs usually
  ## ship .png next to .pdf twins, and <img> cannot render a PDF data URI
  images <- images[grepl("\\.(png|jpe?g|webp|svg|gif)$",
    as.character(images), ignore.case = TRUE, perl = TRUE)]
  if (is.null(images) || length(images) == 0L) {
    return(empty_block("目录中未找到可嵌入的图片文件（仅 PDF/其他格式）。"))
  }
  ## single-image graceful degradation: arrows/search/list would be
  ## dead chrome — render a plain (lightbox-enabled) figure instead
  if (length(images) == 1L) {
    return(figure_block(
      src = unlist(images)[[1L]], title = title,
      caption = caption, description = description,
      missing_ok = miss_ok, data_attrs = data_attrs
    ))
  }
  labels <- names(images)
  if (is.null(labels)) {
    labels <- tools::file_path_sans_ext(basename(as.character(images)))
  }
  ## same-prefix labels (G1_vs_G2.volcano/.ma/.heatmap -> same prefix)
  ## get a disambiguating suffix instead of identical buttons
  labels <- make.unique(as.character(labels), sep = "-")
  gid <- paste0("gal-", digest_like(paste(as.character(images), collapse = "|")))
  pane_tags <- Map(function(i, lb) {
    tags$div(
      class = if (i == 1L) "rp-gallery-pane active" else "rp-gallery-pane",
      id = sprintf("%s-pane-%d", gid, i),
      tags$img(
        class = "rp-gallery-img", src = rp_data_uri(images[[i]], placeholder = miss_ok),
        alt = lb, tabindex = 0,
        onerror = "this.classList.add('rp-img-broken')"
      ),
      tags$div(class = "rp-gallery-label", HTML(lb))
    )
  }, seq_along(images), labels)
  list_tags <- Map(function(i, lb) {
    tags$button(
      class = if (i == 1L) "rp-gallery-item active" else "rp-gallery-item",
      id = sprintf("%s-item-%d", gid, i),
      `data-gallery` = gid, `data-index` = i,
      type = "button", HTML(as.character(lb))
    )
  }, seq_along(images), labels)
  gal_div <- tags$div(
    class = "rp-gallery",
    id = sprintf("%s", gid),
      if (!is.null(caption) || !is.null(title)) {
        tags$div(
          class = "rp-gallery-caption",
          if (!is.null(caption)) tags$span(class = "rp-badge rp-badge-fig", caption),
          if (!is.null(title)) tags$span(class = "rp-fig-title", HTML(title))
        )
      },
      tags$div(
        class = "rp-gallery-main",
        tags$button(
          class = "rp-gallery-arrow rp-gallery-prev", `data-gallery` = gid,
          type = "button", "aria-label" = "Previous",
          rp_icon("chevron-left")
        ),
        tags$div(class = "rp-gallery-track", id = paste0(gid, "-track"),
          tagList(pane_tags)),
        tags$button(
          class = "rp-gallery-arrow rp-gallery-next", `data-gallery` = gid,
          type = "button", "aria-label" = "Next",
          rp_icon("chevron-right")
        )
      ),
      tags$input(
        class = "rp-gallery-search", type = "text",
        placeholder = "Search sample ...",
        `data-gallery` = gid
      ),
    tags$div(class = "rp-gallery-list", tagList(list_tags))
  )
  ## machine-readable anchors for the embedded report schema
  if (length(data_attrs)) {
    gal_div <- do.call(htmltools::tagAppendAttributes,
      c(list(gal_div), data_attrs))
  }
  tagList(
    gal_div,
    if (!is.null(description)) tags$p(class = "rp-fig-desc", HTML(description))
  )
}

#' Section divider
#'
#' Migration of the legacy `add_gap_logo()`: a slim horizontal rule with
#' an optional logo and company name, used to visually separate major
#' report modules.
#'
#' @param logo character(1). Path to a logo image (base64 inlined);
#'   `NULL` draws the rule only.
#' @param company character(1). Company name printed on the right.
#' @return A `htmltools` [tagList()].
#' @export
section_divider <- function(logo = NULL, company = NULL) {
  tagList(
    tags$div(
      class = "rp-divider",
      if (!is.null(logo) && file.exists(logo)) {
        tags$img(class = "rp-divider-logo", src = rp_data_uri(logo))
      },
      if (!is.null(company)) tags$span(class = "rp-divider-company", HTML(company)),
      tags$hr(class = "rp-divider-rule")
    )
  )
}

#' Text paragraph block
#'
#' Convenience wrapper for report prose. Accepts any number of character
#' arguments — they are concatenated into paragraphs (blank-line
#' separated) with HTML enabled — or tag objects, which pass through
#' unchanged.
#'
#' @param ... character strings (concatenated) or tag objects.
#' @param class character(1). Extra CSS class.
#' @return A `htmltools` [tagList()].
#' @export
text_block <- function(..., class = "rp-text") {
  parts <- list(...)
  parts <- parts[!vapply(parts, rp_is_empty, logical(1L))]
  if (length(parts) == 0L) return(tagList())
  is_tag <- vapply(parts, function(p) {
    inherits(p, "shiny.tag") || inherits(p, "shiny.tag.list")
  }, logical(1L))
  if (any(is_tag)) return(tagList(parts))
  text <- paste(unlist(parts), collapse = "")
  paras <- strsplit(text, "\n+")[[1L]]
  tagList(lapply(paras, function(p) {
    tags$p(class = class, HTML(p))
  }))
}

#' Inline SVG icon set (internal)
#'
#' A small, dependency-free set of outline icons used by callouts,
#' empty blocks, gallery arrows and the lightbox. Icons inherit
#' `currentColor` so they adapt to any skin.
#'
#' @param name character(1). One of the names in the internal table.
#' @return A `htmltools` [HTML()] string.
#' @noRd
rp_icon <- function(name) {
  icons <- list(
    info = '<svg viewBox="0 0 16 16" class="rp-icon" fill="none" stroke="currentColor" stroke-width="1.5"><circle cx="8" cy="8" r="6.5"/><line x1="8" y1="7.5" x2="8" y2="11.5"/><circle cx="8" cy="5" r="0.5" fill="currentColor"/></svg>',
    tip = '<svg viewBox="0 0 16 16" class="rp-icon" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M9.5 1.5a5.5 5.5 0 0 1 5 7l-1.2 3.2a1 1 0 0 1-.93.65H8.8l-1.6 1.6a1.4 1.4 0 0 1-2-2l1.6-1.6V4.5"/><path d="M9.5 1.5a5.5 5.5 0 0 0-5 7L3 11.7a1 1 0 0 0 .93 1.28"/><circle cx="6.3" cy="8" r="0.6" fill="currentColor" stroke="none"/></svg>',
    warn = '<svg viewBox="0 0 16 16" class="rp-icon" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M8 1.8 15 14H1z"/><line x1="8" y1="6" x2="8" y2="10"/><circle cx="8" cy="12" r="0.5" fill="currentColor"/></svg>',
    alert = '<svg viewBox="0 0 16 16" class="rp-icon" fill="none" stroke="currentColor" stroke-width="1.5"><circle cx="8" cy="8" r="6.5"/><line x1="5.5" y1="5.5" x2="10.5" y2="10.5"/><line x1="10.5" y1="5.5" x2="5.5" y2="10.5"/></svg>',
    empty = '<svg viewBox="0 0 16 16" class="rp-icon" fill="none" stroke="currentColor" stroke-width="1.2"><rect x="2" y="2" width="12" height="12" rx="1.5" stroke-dasharray="2.5 2.5"/><line x1="5.5" y1="8" x2="10.5" y2="8"/><line x1="8" y1="5.5" x2="8" y2="10.5"/></svg>',
    folder = '<svg viewBox="0 0 16 16" class="rp-icon" fill="none" stroke="currentColor" stroke-width="1.3"><path d="M1.8 4.2c0-.7.5-1.2 1.2-1.2h3l1.4 1.6h5.6c.7 0 1.2.5 1.2 1.2v6.8c0 .7-.5 1.2-1.2 1.2H3c-.7 0-1.2-.5-1.2-1.2z"/></svg>',
    `chevron-left` = '<svg viewBox="0 0 16 16" class="rp-icon" fill="none" stroke="currentColor" stroke-width="1.8"><polyline points="10 3 5 8 10 13"/></svg>',
    `chevron-right` = '<svg viewBox="0 0 16 16" class="rp-icon" fill="none" stroke="currentColor" stroke-width="1.8"><polyline points="6 3 11 8 6 13"/></svg>',
    close = '<svg viewBox="0 0 16 16" class="rp-icon" fill="none" stroke="currentColor" stroke-width="1.8"><line x1="3.5" y1="3.5" x2="12.5" y2="12.5"/><line x1="12.5" y1="3.5" x2="3.5" y2="12.5"/></svg>',
    download = '<svg viewBox="0 0 16 16" class="rp-icon" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M8 2v8"/><polyline points="4.5 7 8 10.5 11.5 7"/><path d="M2.5 13.5h11"/></svg>'
  )
  HTML(icons[[name]] %||% icons$info)
}

## ---------------------------------------------------------------------
## sci_v1 template components (extracted from sp20260727007.html)
## ---------------------------------------------------------------------

#' Meta grid (sci_v1 cover six-cell block)
#'
#' Compact grid of labelled facts for the report cover: renders as a
#' bordered grid with 1px gaps (grid collapses to 3 columns on narrow
#' screens via the sci_v1 stylesheet).
#'
#' @param ... Named arguments: name = value (value may be HTML).
#' @return A `htmltools` [tagList()].
#' @export
meta_grid <- function(items) {
  items <- as.list(items)
  cells <- lapply(names(items), function(nm) {
    tags$div(class = "rp-meta-cell",
      tags$div(class = "rp-meta-key", HTML(nm)),
      tags$div(class = "rp-meta-val", HTML(as.character(items[[nm]])))
    )
  })
  tags$div(class = "rp-meta-grid", tagList(cells))
}

#' KPI strip (sci_v1 headline metrics)
#'
#' 4-column grid of metric cards with a 3px semantic top bar
#' (`kpi-up`/`kpi-down`/`kpi-ok`), a big tabular number, a label and an
#' optional sub-caption (e.g. delta explanation). Companion to [kpi()]
#' (which is the flex-row variant used by other skins).
#'
#' @param ... [kpi_strip_item()] objects.
#' @return A `htmltools` [tagList()].
#' @export
kpi_strip <- function(...) {
  tags$div(class = "rp-kpi-strip", tagList(list(...)))
}

#' Single sci_v1 KPI card
#'
#' @param value character(1). Headline number (HTML allowed).
#' @param label character(1). Metric name.
#' @param sub character(1). Optional sub-caption under the number.
#' @param status character(1). Top-bar semantics: `ok`, `up`, `down` or
#'   `none`.
#' @return A `htmltools` [tagList()].
#' @export
kpi_strip_item <- function(value, label, sub = NULL,
                           status = c("none", "ok", "up", "down")) {
  status <- match.arg(status)
  cls <- if (status == "none") "rp-kpi-card" else
    paste("rp-kpi-card", paste0("kpi-", status))
  tags$div(class = cls,
    tags$div(class = "rp-kpi-num", HTML(as.character(value))),
    tags$div(class = "rp-kpi-label", HTML(as.character(label))),
    if (!is.null(sub)) tags$div(class = "rp-kpi-sub", HTML(as.character(sub)))
  )
}

#' QC status pill (sci_v1 navbar)
#'
#' @param text character(1). Pill text, e.g. `"16/16 PASS"`.
#' @param status character(1). `ok` (green), `warn` (amber) or `bad`
#'   (red).
#' @return A `htmltools` [tagList()].
#' @export
qc_pill <- function(text, status = c("ok", "warn", "bad")) {
  status <- match.arg(status)
  tags$span(class = paste("rp-qc-pill", paste0("rp-qc-pill-", status)),
    tags$span(class = "rp-qc-dot"),
    HTML(as.character(text))
  )
}
