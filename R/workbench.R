## ---------------------------------------------------------------------
## workbench_block (P5): interactive heatmap + gene inspector card
## ---------------------------------------------------------------------

## internal: RdBu diverging color for a value in [-lim, lim]
rp_rdbu_hex <- function(v, lim) {
  lim <- if (is.finite(lim) && lim > 0) lim else 1
  v <- pmin(pmax(v, -lim), lim) / lim
  neg <- c(0x21, 0x66, 0xAC); mid <- c(0xF7, 0xF7, 0xF7)
  pos <- c(0xB2, 0x18, 0x2B)
  cols <- t(vapply(v, function(x) {
    a <- if (x < 0) mid else pos
    b <- if (x < 0) neg else mid
    round(b + (a - b) * abs(x))
  }, numeric(3)))
  rgb(cols[, 1], cols[, 2], cols[, 3], maxColorValue = 255)
}

#' @export
workbench_block <- function(matrix_df, stats_df = NULL,
                            gene_col = "Gene", module_col = "Module",
                            groups = NULL) {
  if (!rp_df_usable(matrix_df)) return(empty_block("热图矩阵为空。"))
  genes <- as.character(matrix_df[[gene_col]])
  samples <- setdiff(names(matrix_df), gene_col)
  if (length(samples) < 2L) return(empty_block("热图矩阵至少需要两列样本。"))
  mat <- sapply(samples, function(s) {
    suppressWarnings(as.numeric(matrix_df[[s]]))
  })
  if (is.null(dim(mat))) mat <- matrix(mat, nrow = 1L)
  if (is.null(groups)) {
    groups <- stats::setNames(sub("_.*$", "", samples), samples)
  }
  if (is.data.frame(groups)) {
    groups <- stats::setNames(as.character(groups[[2]]),
      as.character(groups[[1]]))
  }
  groups <- groups[samples]
  glev <- unique(groups)

  st <- NULL
  if (rp_df_usable(stats_df)) {
    st <- stats_df
    gcol <- if (gene_col %in% names(st)) gene_col else "gene"
  }
  mod_of <- function(g) {
    if (!is.null(st) && module_col %in% names(st)) {
      i <- match(g, as.character(st[[gcol]]))
      if (!is.na(i) && nzchar(st[[module_col]][i])) {
        return(as.character(st[[module_col]][i]))
      }
    }
    "未注释"
  }
  mods <- vapply(genes, mod_of, character(1L))
  mod_list <- unique(mods)
  mod_palette <- c("#377EB8", "#4DAF4A", "#E41A1C", "#984EA3", "#FF7F00",
                   "#00BFC4", "#A65628")
  mod_color <- stats::setNames(mod_palette[seq_along(mod_list)], mod_list)
  lfc_of <- function(g) {
    if (!is.null(st) && "log2FC" %in% names(st)) {
      v <- suppressWarnings(as.numeric(
        st[["log2FC"]][match(g, as.character(st[[gcol]]))]))
      if (length(v) == 1L && is.finite(v)) return(v)
    }
    NA_real_
  }
  fdr_of <- function(g) {
    if (!is.null(st) && "FDR" %in% names(st)) {
      v <- st[["FDR"]][match(g, as.character(st[[gcol]]))]
      if (length(v) == 1L && !is.na(v)) return(as.character(v))
    }
    ""
  }

  payload <- list(
    genes = genes, samples = samples,
    groups = as.list(stats::setNames(groups, samples)),
    groupLevels = glev,
    modules = as.list(stats::setNames(mods, genes)),
    moduleColors = as.list(mod_color),
    stats = lapply(seq_along(genes), function(i) list(
      gene = genes[i], lfc = lfc_of(genes[i]), fdr = fdr_of(genes[i]))),
    ## matrix keyed by gene: { "Gene1": { "A_1": 0.42, ... }, ... }
    matrix = stats::setNames(lapply(seq_along(genes), function(i) {
      as.list(stats::setNames(round(mat[i, ], 3), samples))
    }), genes)
  )
  payload_json <- jsonlite::toJSON(payload, auto_unbox = TRUE,
    null = "null", na = "null")

  lim <- max(abs(mat), na.rm = TRUE)
  if (!is.finite(lim) || lim == 0) lim <- 1
  colmat <- matrix(rp_rdbu_hex(mat, lim), nrow = length(genes))

  group_strip <- tags$tr(class = "rp-wb-grourow",
    tags$th(class = "rp-wb-corner"),
    lapply(samples, function(s) {
      tags$th(style = paste0("border-top:3px solid ",
        mod_palette[(match(groups[[s]], glev) - 1L) %% length(mod_palette) + 1L], ";"))
    }))
  head_row <- tags$tr(tags$th(class = "rp-wb-corner", "基因"),
    lapply(samples, tags$th))
  rows <- lapply(seq_along(genes), function(i) {
    cells <- lapply(seq_along(samples), function(j) {
      v <- mat[i, j]
      tags$td(class = "rp-wb-cell",
        style = paste0("background:", colmat[i, j], ";"),
        `data-v` = if (is.na(v)) "" else sprintf("%.2f", v))
    })
    tags$tr(class = "rp-wb-row", `data-gene` = genes[i],
      `data-module` = mods[i], cells)
  })

  chips <- tagList(
    tags$button(class = "rp-wb-chip active", `data-mod` = "__all__",
      type = "button", sprintf("全部 %d", length(genes))),
    lapply(mod_list, function(m) {
      tags$button(class = "rp-wb-chip", `data-mod` = m, type = "button",
        tags$span(class = "rp-wb-dot",
          style = paste0("background:", mod_color[[m]])), m)
    })
  )
  card <- tags$div(class = "rp-wb-card",
    tags$div(class = "rp-wb-card-head",
      tags$div(
        tags$div(class = "rp-wb-card-eyebrow",
          "SINGLE-GENE PROFILE · 单基因跨组表达剖析"),
        tags$div(class = "rp-wb-symbol", id = "wb-symbol",
          "点击热图行选择基因")
      ),
      tags$span(class = "rp-pill", id = "wb-fdr-badge", "FDR —")
    ),
    tags$div(class = "rp-wb-stats",
      tags$div(class = "rp-wb-stat",
        tags$div(class = "rp-wb-stat-k", "组均值 (log2)"),
        tags$div(class = "rp-wb-stat-v", id = "wb-mean", "—")),
      tags$div(class = "rp-wb-stat",
        tags$div(class = "rp-wb-stat-k", "log2FC"),
        tags$div(class = "rp-wb-stat-v", id = "wb-lfc", "—"))
    ),
    tags$div(class = "rp-wb-bars-title", "各组平均表达水平及相对对照组差值："),
    tags$div(class = "rp-wb-bars", id = "wb-bars"),
    tags$div(class = "rp-wb-bars-title", "样本实测值分布："),
    tags$div(class = "rp-wb-reps", id = "wb-reps")
  )

  tagList(
    tags$div(class = "rp-workbench", tabindex = "0",
      tags$div(class = "rp-wb-chips", chips),
      tags$div(class = "rp-wb-grid",
        tags$div(class = "rp-wb-heat",
          tags$div(class = "rp-table-wrap",
            style = "max-height:460px;overflow:auto;",
            tags$table(class = "rp-wb-table",
              tags$thead(group_strip, head_row),
              tags$tbody(rows)))),
        card),
      tags$script(HTML(payload_json),
        class = "rp-workbench-data", type = "application/json")
    )
  )
}
