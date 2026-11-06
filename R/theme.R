#' Reporter brand/theme configuration
#'
#' Creates the theme object consumed by [render_report()]. The theme
#' controls the visual identity of a report: brand preset, primary
#' color, fonts, navbar/footer branding and caption language. It is
#' built on top of [bslib::bs_theme()] (Bootstrap 5 + sass) plus a set
#' of `--rp-*` CSS variables that the reporter stylesheet consumes, so
#' any skin can also be overridden with plain CSS.
#'
#' @details
#' Brand presets bundle the assets currently shipped with the Rmd-era
#' reports:
#'
#' - `"smzy"` — demo brand preset (placeholder company/phone/logo).
#' - `"jinyu"` — demo brand preset (placeholder company/phone/logo).
#' - `"blank"` — white-label: no logo, no company text.
#' - `"default"` — reporter's own neutral blue, no branding.
#'
#' Explicit arguments (`company`, `phonenum`, `logo_file`, `primary`,
#' ...) always override the preset values.
#'
#' @param preset character(1). One of `smzy`, `jinyu`, `blank`,
#'   `default`.
#' @param primary character(1). Brand primary color (hex), e.g.
#'   `"#0D6E8C"`.
#' @param bslib_preset character(1). Bootstrap base preset forwarded to
#'   [bslib::bs_theme()]; defaults to `"flatly"`.
#' @param base_font,heading_font font specifications forwarded to
#'   [bslib::bs_theme()], e.g. `base_font = bslib::font_google("Noto Sans")`
#'   (offline servers should keep the default system stack).
#' @param company character(1). Company name (navbar right side +
#'   footer).
#' @param phonenum character(1). Service phone (navbar + footer).
#' @param logo_file character(1). Path to a logo image file (png); the
#'   theme resolves `"smzy"`/`"jinyu"`/`"blank"` keywords to bundled
#'   logos.
#' @param caption_lang character(1). `"en"` → "Figure N / Table N";
#'   `"zh"` → "图 N / 表 N". Inherited by the report context unless
#'   [report_context()] was given an explicit value.
#' @param footer_note character(1). Free text rendered in the footer
#'   (e.g. disclaimers).
#' @param extra_css character(1). Extra CSS, either a file path or raw
#'   CSS text; injected into the page head after the theme stylesheet
#'   (wins the override chain).
#' @param style character(1). Visual style family: `"classic"` (carded,
#'   gradient cover, default of v0.1.0) or `"v2"` (flat editorial style:
#'   white cover, hairline rules, plain-text captions, KPI rows, tighter
#'   typography — see `docs/设计调研-网页报告模板.md`) or `"card"`
#'   (Illumina-DRAGEN-style: light gray page, one white card per module,
#'   Inter-ish font stack, warm-gray text).
#' @param extra_variables named list. Additional `--rp-*` (or any
#'   bootstrap) CSS variables for [bslib::bs_theme_add_variables()].
#'
#' @return An object of class `reporter_theme` (a list with elements
#'   `bs_theme`, `brand` and `caption_lang`).
#' @seealso [render_report()]
#' @export
#'
#' @examples
#' reporter_theme(preset = "smzy")
#' reporter_theme(preset = "blank", primary = "#2B6CB0")
#' reporter_theme(style = "v2")
reporter_theme <- function(preset = c("smzy", "jinyu", "blank", "default"),
                           primary = NULL,
                           style = c("classic", "v2", "card", "sci"),
                           bslib_preset = "flatly",
                           base_font = NULL,
                           heading_font = NULL,
                           company = NULL,
                           phonenum = NULL,
                           logo_file = NULL,
                           caption_lang = c("en", "zh"),
                           footer_note = NULL,
                           extra_css = NULL,
                           extra_variables = list()) {
  preset <- match.arg(preset)
  style <- match.arg(style)
  caption_lang <- match.arg(caption_lang)

  brand <- switch(preset,
    smzy = list(
      company = "ACME Biotech",
      phonenum = "000-0000-0000",
      logo_file = system.file("logos", "smzy.png", package = "reporter"),
      primary = "#0D6E8C"
    ),
    jinyu = list(
      company = "Beta Genomics",
      phonenum = "",
      logo_file = system.file("logos", "jinyu.png", package = "reporter"),
      primary = "#B0842A"
    ),
    blank = list(
      company = "", phonenum = "", logo_file = NULL, primary = "#1596B8"
    ),
    default = list(
      company = "", phonenum = "", logo_file = NULL, primary = "#0D6E8C"
    )
  )

  brand$company <- company %||% brand$company
  brand$phonenum <- phonenum %||% brand$phonenum
  if (is.null(logo_file)) {
    brand$logo_file <- brand$logo_file
  } else if (logo_file %in% c("smzy", "jinyu", "blank")) {
    brand$logo_file <- if (logo_file == "blank") NULL else
      system.file("logos", paste0(logo_file, ".png"), package = "reporter")
  } else {
    brand$logo_file <- logo_file
  }
  primary <- primary %||% brand$primary

  rp_vars <- list(
    "rp-primary" = primary,
    "rp-primary-dark" = rp_darken(primary, 0.18),
    "rp-primary-light" = rp_lighten(primary, 0.85),
    "rp-navbar-bg" = "#FFFFFF",
    "rp-toc-bg" = if (style == "card") "#FFFFFF"
                  else if (style == "v2") "#FAFBFC" else "#F6F8FA",
    "rp-content-bg" = "#FFFFFF",
    "rp-page-bg" = if (style == "card") "#F5F5F5"
                   else if (style == "v2") "#FFFFFF" else "#EDF2F5"
  )
  rp_vars <- utils::modifyList(rp_vars, as.list(extra_variables), keep.null = FALSE)

  ## bslib 0.12 deprecated bs_theme_update()/bs_theme_add_variables() in
  ## favour of passing everything through bs_theme() directly, so all
  ## variables (including the custom --rp-* ones) are folded in here.
  theme_args <- c(
    list(
      preset = bslib_preset,
      primary = primary,
      "font-size-base" = "0.95rem"
    ),
    if (!is.null(base_font)) list(base_font = base_font),
    if (!is.null(heading_font)) list(heading_font = heading_font),
    rp_vars
  )
  bs <- do.call(bslib::bs_theme, theme_args)

  ## extra_css: file path(s) -> inline text (raw CSS passes through)
  css_text <- rp_char1(extra_css)
  if (!is.null(css_text) && file.exists(css_text)) {
    css_text <- paste(vapply(css_text, function(f) {
      paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
    }, character(1L)), collapse = "\n")
  }

  structure(
    list(
      bs_theme = bs,
      brand = brand,
      caption_lang = caption_lang,
      footer_note = footer_note,
      preset = preset,
      style = style,
      extra_css = css_text
    ),
    class = "reporter_theme"
  )
}

#' @export
print.reporter_theme <- function(x, ...) {
  cat("<reporter_theme> preset:", x$preset, "\n")
  cat("  company :", x$brand$company, "\n")
  cat("  logo    :", x$brand$logo_file, "\n")
  cat("  captions:", x$caption_lang, "\n")
  invisible(x)
}

#' Darken a hex color (internal)
#'
#' @param hex character(1) `#rrggbb`.
#' @param factor numeric(1) in [0,1]; fraction to darken.
#' @return character(1) darkened hex color.
#' @noRd
rp_darken <- function(hex, factor = 0.2) {
  col <- round(grDevices::col2rgb(hex)[, 1L] * (1 - factor))
  grDevices::rgb(col[1L], col[2L], col[3L], maxColorValue = 255)
}

#' Lighten a hex color toward white (internal)
#'
#' @param hex character(1) `#rrggbb`.
#' @param factor numeric(1) in [0,1]; 0 → unchanged, 1 → white.
#' @return character(1) lightened hex color.
#' @noRd
rp_lighten <- function(hex, factor = 0.85) {
  col <- grDevices::col2rgb(hex)[, 1L]
  col <- col + (255 - col) * factor
  grDevices::rgb(col[1L], col[2L], col[3L], maxColorValue = 255)
}
