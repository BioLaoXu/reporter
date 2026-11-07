#' Reporter page skeleton (internal builders)
#'
#' Internal functions assembling the final HTML page: fixed top navbar,
#' sidebar table of contents, cover hero, module sections and footer.
#' They are called by [render_report()] and are not part of the module
#' authoring API.
#'
#' @name layout-internal
#' @keywords internal
NULL

#' Package asset dependency
#'
#' The reporter stylesheet and script ship with the package and are
#' attached to every rendered page as a [htmltools::htmlDependency()],
#' which [htmltools::save_html()] copies next to the report and
#' [inline_html()] folds into the single-file output.
#'
#' @return A [htmltools::htmlDependency()].
#' @noRd
rp_dependency <- function() {
  htmltools::htmlDependency(
    name = "reporter-assets",
    version = utils::packageVersion("reporter"),
    src = system.file("assets", package = "reporter"),
    stylesheet = "reporter.css",
    script = c("reporter.js", "reporter-lite.js", "reporter-workbench.js"),
    all_files = FALSE
  )
}

#' sci_v1 template assets (loaded only for style = "sci_v1")
#' @noRd
sci_v1_dependency <- function() {
  htmltools::htmlDependency(
    name = "reporter-sci_v1",
    version = utils::packageVersion("reporter"),
    src = system.file("assets", package = "reporter"),
    stylesheet = "reporter-sci_v1.css",
    all_files = FALSE
  )
}

#' Assemble the full HTML page
#'
#' @param title character(1). Page `<title>`.
#' @param navbar,content toc,footer tag objects produced by the other
#'   builders.
#' @param theme A `reporter_theme` from [reporter_theme()].
#' @return A [htmltools::tagList()] representing a full HTML document.
#' @noRd
rp_page <- function(title, navbar, toc, content, footer, theme,
                    schema_json = NULL, engine = NULL,
                    extra_body_class = NULL) {
  sci_v1 <- identical(theme$style, "sci_v1")
  tagList(
    tags$head(
      tags$meta(charset = "UTF-8"),
      tags$meta(
        name = "viewport",
        content = "width=device-width, initial-scale=1, shrink-to-fit=no"
      ),
      tags$title(title),
      ## lite engine: the bootstrap runtime is dead weight there (its
      ## base styles are replaced by the rp-engine-lite normalize block)
      if (!identical(engine, "lite")) {
        bslib::bs_theme_dependencies(theme$bs_theme)
      },
      rp_dependency(),
      ## user CSS wins the override chain (theme: extra_css)
      if (!is.null(theme$extra_css) && nzchar(theme$extra_css)) {
        tags$style(HTML(theme$extra_css))
      },
      ## machine-readable report schema (index only, never cell data);
      ## LLM/pipeline consumers read this block instead of the whole HTML
      if (!is.null(schema_json) && nzchar(schema_json)) {
        tags$script(HTML(schema_json),
          id = "rp-schema", type = "application/json", class = "rp-schema")
      },
      ## sci_v1 standalone template (loaded only for that style)
      if (identical(theme$style, "sci_v1")) sci_v1_dependency()
    ),
    tags$body(
      class = paste(c("rp-body",
        if (!identical(theme$style %||% "classic", "classic")) {
          paste0("rp-style-", theme$style)
        },
        if (identical(engine, "lite")) "rp-engine-lite",
        extra_body_class),
        collapse = " "),
      `data-rp-caption-lang` = theme$caption_lang,
      navbar,
      if (sci_v1) {
        ## sci_v1 shell owns its own nav/main DOM (no double wrappers)
        tags$div(class = "rp-layout",
          toc,
          tags$main(class = "rp-main",
            tags$div(class = "rp-container", content, footer)))
      } else {
        tags$div(
          class = "rp-layout",
          tags$nav(
            class = "rp-toc", id = "rp-toc",
            `aria-label` = "Table of contents",
            tags$div(class = "rp-toc-inner", toc)
          ),
          tags$main(
            class = "rp-content",
            id = "rp-content",
            content,
            footer
          )
        )
      }
    )
  )
}

#' Build the fixed top navbar
#'
#' @param title character(1). Report title.
#' @param meta Named list from the report context.
#' @param brand Brand info from the theme.
#' @param module_links list of module link entries
#'   `list(id, title)` for the anchor menu.
#' @return A [htmltools::tagList()].
#' @noRd
rp_navbar <- function(title, meta, brand, module_links) {
  logo_uri <- if (!is.null(brand$logo_file) && file.exists(brand$logo_file)) {
    rp_data_uri(brand$logo_file)
  } else {
    NULL
  }
  badge <- function(label, cls = "rp-navbar-badge") {
    if (is.null(label) || is.na(label) || !nzchar(label)) return(NULL)
    tags$span(class = cls, HTML(label))
  }
  tagList(
    tags$header(
      class = "rp-navbar",
      tags$div(
        class = "rp-navbar-left",
        if (!is.null(logo_uri)) {
          tags$a(
            href = "#rp-cover", class = "rp-navbar-logo-link",
            tags$img(class = "rp-navbar-logo", src = logo_uri, alt = "logo")
          )
        },
        tags$div(
          class = "rp-navbar-title-block",
          tags$span(class = "rp-navbar-title", HTML(title)),
          tags$div(
            class = "rp-navbar-badges",
            badge(meta$project, "rp-navbar-badge rp-navbar-project"),
            badge(meta$species, "rp-navbar-badge rp-navbar-species"),
            badge(meta$code, "rp-navbar-badge rp-navbar-code")
          )
        )
      ),
      tags$nav(
        class = "rp-navbar-links",
        lapply(module_links, function(l) {
          tags$a(href = paste0("#", l$id), class = "rp-navbar-link", HTML(l$title))
        })
      ),
      tags$div(
        class = "rp-navbar-right",
        if (nzchar(brand$company %||% "")) {
          tags$span(class = "rp-navbar-company", HTML(brand$company))
        },
        if (nzchar(brand$phonenum %||% "")) {
          tags$span(class = "rp-navbar-phone", HTML(brand$phonenum))
        }
      ),
      tags$button(
        class = "rp-btn-top rp-btn-pdf", type = "button",
        title = "打开浏览器打印对话框，另存为 PDF",
        onclick = "exportReportToPDF()",
        "导出 PDF"
      ),
      tags$button(
        class = "rp-toc-toggle", type = "button",
        `aria-label` = "Toggle sidebar", `aria-expanded` = "true",
        rp_icon("chevron-left")
      )
    )
  )
}

#' Build the sidebar table of contents
#'
#' @param toc_groups list of module groups, each a list with `id`,
#'   `title` and `sections` (a list of `list(id, title)` entries).
#' @return A [htmltools::tagList()].
#' @noRd
rp_toc <- function(toc_groups, header = NULL, counter = NULL) {
  tagList(
    if (!is.null(header)) {
      tags$div(
        class = "rp-toc-header",
        tags$span(class = "rp-toc-header-title", HTML(header)),
        if (!is.null(counter)) {
          tags$span(class = "rp-toc-header-count", HTML(counter))
        }
      )
    },
    lapply(toc_groups, function(g) {
      tags$ul(
        class = "rp-toc-group",
        tags$li(
          class = "rp-toc-module",
          tags$a(
            href = paste0("#", g$id), class = "rp-toc-module-link",
            HTML(g$title)
          )
        ),
        if (length(g$sections) > 0L) {
          tags$ul(
            class = "rp-toc-sections",
            lapply(g$sections, function(s) {
              tags$li(
                class = "rp-toc-section",
                tags$a(href = paste0("#", s$id), class = "rp-toc-link", HTML(s$title))
              )
            })
          )
        }
      )
    })
  )
}

#' Build the cover hero block
#'
#' @param title character(1). Report title.
#' @param meta Context meta list.
#' @param brand Brand info from the theme.
#' @return A [htmltools::tagList()].
#' @noRd
rp_cover <- function(title, meta, brand, style = "classic") {
  ## sci_v1 template: eyebrow badges + meta grid replace the kv table
  sci_v1 <- identical(style, "sci_v1")
  eyebrow <- if (sci_v1) {
    eb <- list("ANALYSIS REPORT",
      if (!is.null(meta$code) && nzchar(meta$code))
        paste0("PROJECT ID · ", meta$code) else NULL,
      paste0("DELIVERY DATE · ", meta$date))
    eb[!vapply(eb, is.null, logical(1L))]
  } else list()
  kv <- list()
  add_kv <- function(label, value) {
    if (!is.null(value) && !is.na(value) && nzchar(as.character(value))) {
      kv <<- c(kv, stats::setNames(list(as.character(value)), label))
    }
  }
  add_kv("Project", meta$project)
  add_kv("Project Code", meta$code)
  add_kv("Species", meta$species)
  add_kv("Reference Version", meta$ref_version)
  add_kv("Sample Type", meta$sample_type)
  add_kv("Report Date", as.character(meta$date))
  add_kv("Result Path", meta$result_path)

  logo_uri <- if (!is.null(brand$logo_file) && file.exists(brand$logo_file)) {
    rp_data_uri(brand$logo_file)
  } else {
    NULL
  }
  tagList(
    tags$section(
      class = "rp-cover", id = "rp-cover",
      tags$div(
        class = "rp-cover-inner",
        if (!is.null(logo_uri)) {
          tags$img(class = "rp-cover-logo", src = logo_uri, alt = "logo")
        },
        if (length(eyebrow)) {
          tags$div(class = "rp-cover-eyebrow",
            lapply(eyebrow, function(b)
              tags$span(class = "rp-cover-eyebrow-item", b))
          )
        },
        tags$h1(class = "rp-cover-title", HTML(title)),
        tags$p(
          class = "rp-cover-subtitle",
          if (nzchar(brand$company %||% "")) HTML(brand$company) else NULL
        ),
        if (sci_v1 && length(kv) > 0L) {
          meta_grid(as.list(kv))
        } else if (length(kv) > 0L) {
          tags$div(class = "rp-cover-kv", kv_table(unlist(kv)))
        }
      )
    )
  )
}

#' Build the module section wrapper
#'
#' @param id character(1). Module anchor id.
#' @param title character(1). Module heading.
#' @param content tag object with the rendered module body.
#' @return A [htmltools::tagList()].
#' @noRd
rp_module_section <- function(id, title, content) {
  tagList(
    tags$section(
      class = "rp-module", id = id,
      tags$h2(class = "rp-module-title", HTML(title)),
      tags$div(class = "rp-module-body", content)
    )
  )
}

#' Build the error placeholder for a failed module
#'
#' Failures never abort the whole report: a failed module is rendered
#' as a danger callout carrying its condition message, and the error is
#' additionally recorded in the render result (see [render_report()]).
#'
#' @param title character(1). Module title.
#' @param message character(1). Condition message.
#' @return A [htmltools::tagList()].
#' @noRd
rp_error_block <- function(title, message) {
  callout(
    paste0("<code>", htmltools::htmlEscape(message), "</code>"),
    type = "danger",
    title = paste0("Module rendering failed: ", title)
  )
}

#' Build the page footer
#'
#' @param meta Context meta list.
#' @param brand Brand info from the theme.
#' @param theme The `reporter_theme` object.
#' @param n_errors integer(1). Count of failed modules, appended as a
#'   subtle status note when positive.
#' @return A [htmltools::tagList()].
#' @noRd
rp_footer <- function(meta, brand, theme, n_errors = 0L) {
  year <- format(Sys.Date(), "%Y")
  tagList(
    tags$footer(
      class = "rp-footer",
      tags$div(
        class = "rp-footer-line",
        tags$span(
          class = "rp-footer-brand",
          paste0("© ", year, " reporter v",
            as.character(utils::packageVersion("reporter")))
        ),
      ),
      if (!is.null(theme$footer_note) && nzchar(theme$footer_note)) {
        tags$p(class = "rp-footer-note", HTML(theme$footer_note))
      }
    )
  )
}

## ---------------------------------------------------------------------
## sci_v1 shell (extracted from sp20260727007.html — DOM 1:1)
## ---------------------------------------------------------------------

#' @noRd
rp_navbar_sci_v1 <- function(title, meta, brand, qc_text = NULL,
                             nav_title = NULL) {
  svg_toggle <- tags$svg(width = "15", height = "15", viewBox = "0 0 16 16",
    fill = "none", stroke = "currentColor", `stroke-width` = "1.6",
    tags$path(d = "M2.5 4h11M2.5 8h7.5M2.5 12h11"))
  svg_mark <- tags$svg(width = "14", height = "14", viewBox = "0 0 16 16",
    fill = "none", stroke = "currentColor", `stroke-width` = "1.7",
    tags$path(d = "M3 2.5c3.5 0 6.5 11 10 11M13 2.5c-3.5 0-6.5 11-10 11M4.5 5h7M4.5 11h7"))
  ## centered report title (short name passed via nav_title/report_title)
  crumb <- tags$div(class = "rp-nav-state-top",
    tags$span(class = "rp-nav-report-title",
      HTML(nav_title %||% meta$title %||% title)))
  tagList(
    tags$header(class = "rp-navbar",
      tags$div(class = "rp-nav-brand",
        tags$button(class = "rp-toc-toggle", id = "btn-toc-toggle",
          title = "折叠/展开左侧章节导航 (快捷键 [ )", type = "button",
          svg_toggle),
        tags$div(class = "rp-logo-box",
          tags$span(class = "rp-logo-mark", svg_mark),
          tags$div(class = "rp-logo-text",
            tags$span(class = "rp-logo-name",
              c(brand$company, meta$company, "NGS-REPORTER")[
                which(nzchar(c(brand$company %||% "", meta$company %||% "", "x")))[1L]]),
            if (nzchar(brand$phonenum %||% "")) {
              tags$span(class = "rp-logo-sub", brand$phonenum)
            }
          )
        )
      ),
      tags$div(class = "rp-nav-center", crumb),
      tags$div(class = "rp-nav-right",
        tags$button(class = "rp-util-btn", type = "button",
          title = "导出 PDF",
          `aria-label` = "导出 PDF",
          onclick = "exportReportToPDF()",
          tags$svg(width = "14", height = "14", viewBox = "0 0 16 16",
            fill = "none", stroke = "currentColor", `stroke-width` = "1.5",
            tags$path(d = "M8 2v8"),
            tags$polyline(points = "4.5 7 8 10.5 11.5 7"),
            tags$path(d = "M2.5 13.5h11")))
      )
    )
  )
}

#' @noRd
rp_toc_sci_v1 <- function(toc_groups) {
  n <- length(toc_groups)
  items <- lapply(seq_along(toc_groups), function(i) {
    g <- toc_groups[[i]]
    tags$li(class = "rp-toc-item",
      tags$a(class = "rp-toc-link", href = paste0("#", g$id),
        sprintf("%02d · %s", i, g$title)),
      if (length(g$sections)) {
        tags$ul(class = "rp-toc-sublist",
          lapply(g$sections, function(s) {
            tags$li(tags$a(class = "rp-toc-sublink", href = paste0("#", s$id),
              HTML(s$title)))
          }))
      }
    )
  })
  tags$nav(class = "rp-toc", id = "rp-toc", `aria-label` = "报告章节导航",
    tags$div(class = "rp-toc-header",
      tags$span("报告目录 · CONTENTS"),
      tags$span(id = "toc-progress", sprintf("%02d / %02d", 1L, n))
    ),
    tags$ul(class = "rp-toc-list", items)
  )
}

#' @noRd
rp_module_section_sci_v1 <- function(id, title, number, content,
                                     path_note = NULL, link_path = NULL) {
  pill <- NULL
  if (!is.null(path_note) && nzchar(path_note)) {
    ## icon-only pill: full path on hover, click opens the RELATIVE
    ## folder (report html usually ships next to the Report/ directory).
    ## If the browser cannot open it, the report and Report/ are not
    ## siblings — the tooltip says so.
    tip <- paste0(path_note,
      " — 若无法打开，说明报告 HTML 与 Report 目录不在同一层级")
    pill <- tags$span(class = "rp-filepath rp-module-path",
      tags$a(href = path_note, target = "_blank", title = tip,
        `aria-label` = path_note,
        tags$span(rp_icon("folder"), class = "rp-filepath-icon")
      )
    )
  }
  tags$section(class = "rp-module", id = id,
    tags$div(class = "rp-module-header",
      tags$span(class = "rp-module-num", sprintf("%02d", number)),
      tags$h2(class = "rp-module-title", HTML(title)),
      pill
    ),
    tags$div(class = "rp-module-body", content)
  )
}

