#' =====================================================================
#' Built-in module library
#' =====================================================================
#'
#' This file is the ONLY place where concrete report modules live. It is
#' organised by pipeline; every pipeline exposes a
#' \code{<pipeline>_report_modules()} factory returning a list of
#' [module()] objects built with the same contract:
#'
#' \preformatted{ function(ctx) -> htmltools::tagList }
#'
#' Generic (pipeline-independent) modules come first, then the ChIP
#' exemplar set, then the m6A interface stub. New pipelines append a
#' new section here (or split into R/modules-<pipeline>.R once a set
#' outgrows this file).
#'
#' @name modules-library
#' @keywords internal
NULL

## ---------------------------------------------------------------------
#' Standard first block: project info + experimental design
#'
#' Used with `reporter_theme(cover_mode = "first_block")` (sci_v1): the
#' big cover card is dropped and this standard module renders the
#' project meta grid plus the group design table as block 01.
#' @export
mod_project_block <- function() {
  module(id = "project", title = "项目信息与实验设计",
    required_dirs = character(0),
    render = function(ctx) {
      kv <- list(
        `项目` = ctx$meta$project,
        `项目编号` = ctx$meta$code,
        `物种` = ctx$meta$species,
        `参考基因组` = ctx$meta$ref_version,
        `报告日期` = as.character(ctx$meta$date))
      kv <- kv[!vapply(kv, function(x)
        rp_is_empty(x) || (is.character(x) && is.na(x)), logical(1))]
      g <- file.path(ctx$meta$result_path, "0.SampleInfo", "GroupInfo.txt")
      gdt <- if (file.exists(g)) {
        tryCatch(read_result_table(g, sep = "\t"), error = function(e) NULL)
      } else NULL
      tagList(
        ctx$subsection("项目信息"),
        meta_grid(as.list(kv)),
        if (!is.null(gdt)) {
          tagList(
            ctx$subsection("样本分组设计"),
            ctx$data_table(gdt, title = "实验分组信息"))
        }
      )
    })
}

## References (shared across pipelines)
## ---------------------------------------------------------------------

#' References module
#'
#' Renders a numbered reference list from a BibTeX file. The file is
#' resolved in order: explicit `bib_file` argument -> `references.bib`
#' in the result directory (per-project overrides) -> the bundled
#' `inst/extdata/references.bib`. The module therefore auto-loads with
#' zero configuration and can be added to any pipeline's module set.
#'
#' @param bib_file character(1). Optional path to a `.bib` file.
#' @param title character(1). Module heading in the navbar/TOC.
#' @return A `module()` object — add with [add_module()].
#' @seealso [read_bib()], [reference_list()]
#' @export
#'
#' @examples
#' \dontrun{
#' report <- create_report(ctx) |> add_module(mod_references())
#' }

mod_references <- function(bib_file = NULL, title = "参考文献",
                           only_keys = NULL) {
  module(
    id = "references",
    title = title,
    render = function(ctx) {
      cand <- c(
        bib_file,
        file.path(ctx$meta$result_path, "references.bib"),
        system.file("extdata", "references.bib", package = "reporter")
      )
      f <- cand[!is.na(cand) & nzchar(as.character(cand)) &
                  file.exists(as.character(cand))][1L]
      if (is.na(f)) {
        return(tagList(
          ctx$subsection("Cited References"),
          empty_block("未找到参考文献文件（references.bib）。")
        ))
      }
      ## register the bib path so render_report can rebuild this layer
      ## as a cited-only view after the other modules have rendered
      ctx$.rp_bib_file <- f
      bib <- tryCatch(read_bib(f), error = function(e) NULL)
      ## optionally show only references cited in the narrative
      if (!is.null(bib) && !is.null(only_keys) && length(only_keys)) {
        cited <- bib[bib$key %in% only_keys, , drop = FALSE]
        if (nrow(cited) > 0L) bib <- cited   # none matched -> keep full list
      }
      ## register the rendered key->number map so the assembly pass can
      ## turn [@key] markers in any module's narrative into superscripts
      ## pointing at this list
      ctx$.rp_bib_keymap <- stats::setNames(
        seq_len(nrow(bib)), as.character(bib$key))
      if (is.null(bib) || nrow(bib) == 0L) {
        return(tagList(
          ctx$subsection("Cited References"),
          empty_block("参考文献文件为空或解析失败。")
        ))
      }
      tagList(
        ctx$subsection("Cited References"),
        reference_list(bib),
        file_path_note(f)
      )
    }
  )
}

#' =====================================================================
#' ChIP-seq module set (exemplar pipeline)
#' =====================================================================
#'
#' The exemplar module set migrated from the legacy
#' `Rmds/{1,2,3}.ChIP.Rmd` documents. Each module is small, gated by the
#' presence of its result sub-directory (`required_dirs`), and renders
#' through the standard context primitives, so the legacy
#' `res_tree_dt`-style directory probing is now declarative. The
#' differential/enrichment/motif modules additionally require
#' `--type 1` (biological replicates) and are skipped automatically
#' for single-group projects — one shared template, no more
#' `2.ChIP.oneGroup_20260702.Rmd`-style copies.
#'
#' @details
#' Consumed result layout (sub-directories of the result path):
#'
#' ```
#' 0.SampleInfo/  GroupInfo.txt, CompareInfo.txt
#' 1.QC/         Raw.Reads.txt, Filtered.Summary.txt, Plot/*Quality*.png
#' 2.Mapping/    mapping.stats.txt, genomic.anno.txt
#' 3.Quality/    RegionDis/*Profile*.png, PCA/*PCA*.png, Cor/*cor*.png
#' 3.Quality/IP/ *fingerprints*.png, QCmetrics.csv
#' 4.PeakCalling/GroupComparePeaks/Profile/Annotation/*.peakAnnotation.csv
#' 4.PeakCalling/GroupSamplePeaks/Profile/**/*.png
#' 5.DiffPeaks/  <Compare>/  *All.diffGenes.csv, *_vs_*.png,
#'               Profile/**/*.png, PeakVis/*.PeakCoverage.png,
#'               Enrichment/GO/  *.GOenrich_total.csv, *.png
#'               Enrichment/KEGG/*.KEGGenrich_total.csv, *.png
#'               Motif/knownResults.html
#' 6.Similarity/ ALLPeaks/, DEGPeaks/
#' ```
#'
#' @param show_number integer(1). Max rows shown per result table
#'   (legacy `show_number` global, now an explicit argument).
#' @return A list of [module()] objects.
#' @seealso [module()], [report_context()], [report_cli()]
#' @export
chip_report_modules <- function(show_number = 10L) {
  list(
    mod_chip_overview(show_number = show_number),
    mod_chip_qc(show_number = show_number),
    mod_chip_mapping(show_number = show_number),
    mod_chip_reads_dist(),
    mod_chip_peak(show_number = show_number),
    mod_chip_ip(show_number = show_number),
    mod_chip_similarity(),
    mod_chip_diff_peak(show_number = show_number),
    mod_chip_enrich(show_number = show_number),
    mod_chip_motif(),
    mod_chip_methods(),
    mod_references()
  )
}

## ---------------------------------------------------------------------
## shared helpers
## ---------------------------------------------------------------------

## Internal: compare-group labels shared by the differential modules.
## Reads the first row of 0.SampleInfo/CompareInfo.txt and derives the
## legacy diff_show_group / diff_show_group_all labels.
chip_group_info <- function(ctx, show_number = 10L) {
  compare_file <- file.path(ctx$meta$result_path, "0.SampleInfo", "CompareInfo.txt")
  compare <- NA_character_
  if (file.exists(compare_file)) {
    dt <- read_result_table(compare_file, sep = "\t")
    if (!is.null(dt) && nrow(dt) > 0L) {
      compare <- paste(stats::na.omit(as.character(dt[1L, ])), collapse = "_vs_")
    }
  }
  list(
    compare = compare,
    compare_all = paste0(compare, ".All"),
    show_number = show_number
  )
}

chip_is_diff <- function(ctx) identical(as.character(ctx$meta$type), "1")

## ---------------------------------------------------------------------
## 1. overview: background, pipeline, project info
## ---------------------------------------------------------------------

#' @rdname chip_report_modules
#' @export
mod_chip_overview <- function(show_number = 10L) {
  module(
    id = "overview",
    title = "背景介绍与方法流程",
    required_dirs = "0.SampleInfo",
    render = function(ctx) {
      ctx$meta$ref_version <- ctx$meta$ref_version %||% "Unknow"
      ctx$meta$ref_db <- ctx$meta$ref_db %||% "Unknow"

      tagList(
        ctx$subsection("染色质免疫共沉淀测序"),
        text_block(
          "染色质免疫共沉淀(ChIP)是一种用于表观遗传学研究的技术，可以反映蛋白质与DNA相互作用。",
          "染色质免疫共沉淀测序(ChIP-Seq)是一种在分离纯化得到与目标蛋白结合的基因组DNA片段后，",
          "通过高通量测序与数据分析，在全基因组范围内研究蛋白质与DNA相互作用的技术。"
        ),
        ctx$tip(
          "得到ChIP-seq的分析结果后，可从中挑选感兴趣的基因或Peak区域，",
          "通过ChIP-qPCR等实验方法进行验证。"
        ),
        ctx$subsection("技术方法与流程"),
        text_block(
          "实验处理建库主要包括DNA与蛋白质交联、染色体片段化处理、免疫共沉淀、",
          "DNA解交联及纯化、文库构建与测序五个步骤，详见图示。"
        ),
        ctx$figure(
          path = system.file("images", "chipseqpipeline.png", package = "reporter"),
          title = "ChIP-Seq实验流程说明", width = "72%"
        ),
        text_block(
          "生物信息分析主要包括四部分：(1)质控：使用fastp去除接头与低质量序列；",
          "(2)比对：使用BWA将质控后数据比对到参考基因组并评估IP效率；",
          "(3)Peak鉴定：使用MACS2进行Peak鉴定，ChIPseeker注释，HOMER进行Motif分析；",
          "(4)差异分析：使用DESeq2/edgeR进行差异Peak分析（单分组项目自动跳过该部分）。"
        ),
        ctx$figure(
          path = system.file("images", "bioinfomaticspipeline.png", package = "reporter"),
          title = "ChIP-Seq数据分析流程", width = "70%"
        ),
        ctx$subsection("项目信息"),
        text_block("客户提供的样本名称、分组及差异分析比较组等信息详见下表："),
        chip_project_tables(ctx, show_number)
      )
    }
  )
}

chip_project_tables <- function(ctx, show_number) {
  out <- list()
  group_file <- file.path(ctx$meta$result_path, "0.SampleInfo", "GroupInfo.txt")
  group_dt <- read_result_table(group_file, sep = "\t")
  if (!is.null(group_dt)) {
    if (ncol(group_dt) > 3L) group_dt <- group_dt[, seq_len(3L), drop = FALSE]
    out[[length(out) + 1L]] <- ctx$data_table(
      group_dt, title = "样本信息汇总", searchable = TRUE
    )
  }
  diff_dt <- read_result_table(
    file.path(ctx$meta$result_path, "0.SampleInfo", "CompareInfo.txt"), sep = "\t"
  )
  if (!is.null(diff_dt)) {
    out[[length(out) + 1L]] <- ctx$data_table(
      diff_dt, title = "差异分析比较组", searchable = TRUE
    )
  }
  out[[length(out) + 1L]] <- ctx$data_table(
    data.frame(Species = ctx$meta$species,
               RefGenoVersion = ctx$meta$ref_version %||% "Unknow"),
    title = "参考基因组信息"
  )
  do.call(tagList, out)
}

## ---------------------------------------------------------------------
## 2. QC
## ---------------------------------------------------------------------

## internal: mean of "93.5%" / "0.935"-style columns -> numeric
rp_pct_mean <- function(x) {
  if (is.null(x) || !length(x)) return(NA_real_)
  ## strip percent signs and thousands separators before coercion; a
  ## fully non-numeric column (e.g. free text) yields NA quietly
  v <- suppressWarnings(as.numeric(sub("[[:space:]]*%.*$", "",
    gsub(",", "", as.character(x), fixed = TRUE))))
  if (all(is.na(v))) return(NA_real_)
  mean(v, na.rm = TRUE)
}

## internal: semantic status for a QC metric (higher is better)
rp_status <- function(value, ok_at, warn_at) {
  if (is.na(value)) return("neutral")
  if (value >= ok_at) "ok" else if (value >= warn_at) "warn" else "bad"
}

## internal: headline KPI row for the QC module (10x-style summary)
rp_kpis_from_qc <- function(raw_dt, filt_dt) {
  if (is.null(raw_dt) && is.null(filt_dt)) return(NULL)
  n_samples <- max(nrow(raw_dt %||% data.frame()),
                   nrow(filt_dt %||% data.frame()))
  if (!is.finite(n_samples) || n_samples == 0L) return(NULL)
  q30 <- rp_pct_mean(filt_dt$CleanQ30)
  keep <- rp_pct_mean(filt_dt$CleanRatio)
  kpi_row(
    kpi(as.character(n_samples), "Samples"),
    if (!is.na(q30)) {
      kpi(sprintf("%.1f%%", q30), "Mean clean Q30",
          rp_status(q30, 90, 80))
    },
    if (!is.na(keep)) {
      kpi(sprintf("%.1f%%", keep), "Clean read retention",
          rp_status(keep, 90, 80))
    }
  )
}

#' @rdname chip_report_modules
#' @export
mod_chip_qc <- function(show_number = 10L) {
  module(
    id = "qc",
    title = "测序序列统计与质控",
    required_dirs = "1.QC",
    render = function(ctx) {
      raw_dt <- read_result_table(
        file.path(ctx$meta$result_path, "1.QC", "Raw.Reads.txt"), sep = "\t"
      )
      filt_dt <- read_result_table(
        file.path(ctx$meta$result_path, "1.QC", "Filtered.Summary.txt"), sep = "\t"
      )
      total_dt <- NULL
      if (!is.null(raw_dt) && !is.null(filt_dt) &&
          "SampleName" %in% names(raw_dt) && "SampleName" %in% names(filt_dt)) {
        if (ncol(raw_dt) >= 8L) raw_dt <- raw_dt[, -8L, drop = FALSE]
        common <- intersect(names(raw_dt), names(filt_dt))
        total_dt <- merge(raw_dt, filt_dt, by = "SampleName", all = TRUE)
      }
      qc_imgs <- ctx$find(".png", dir = "1.QC/Plot", key = "Quality")

      tagList(
        ctx$subsection("数据质控统计"),
        text_block(
          "数据质量会直接影响后续分析结果。本项目使用fastp[@fastp]进行原始测序数据的质控：",
          "去除带接头的reads、含N碱基数目大于6的reads、低质量reads以及质控后长度过短(<50bp)的序列。"
        ),
        rp_kpis_from_qc(raw_dt, filt_dt),
        if (!is.null(total_dt)) {
          tagList(
            ctx$data_table(total_dt, title = "数据质控统计",
              truncate = names(total_dt), explain_sheet = "QC",
              source = c("1.QC/Raw.Reads.txt", "1.QC/Filtered.Summary.txt")),
            file_path_note("Report/ChIP/1.QC/Raw.Reads.txt | Filtered.Summary.txt")
          )
        } else {
          empty_block("未找到质控统计表，请检查 1.QC 目录。")
        },
        ctx$subsection("质控前后碱基质量与含量分布"),
        if (length(qc_imgs) > 0L) {
          tagList(
            ctx$gallery(qc_imgs, title = "数据质控分布"),
            text_block(
              "图中上两个子图分别为样本原始数据(Raw data)和质控后数据(Clean data)的测序碱基质量分布图；",
              "下两个子图分别为原始和质控后数据的测序碱基含量分布图。"
            ),
            file_path_note("Report/ChIP/1.QC/Plot/*.png|pdf")
          )
        } else {
          empty_block()
        }
      )
    }
  )
}

## ---------------------------------------------------------------------
## 3. mapping + genomic distribution
## ---------------------------------------------------------------------

#' @rdname chip_report_modules
#' @export
mod_chip_mapping <- function(show_number = 10L) {
  module(
    id = "mapping",
    title = "参考基因组比对与reads来源分布",
    required_dirs = "2.Mapping",
    render = function(ctx) {
      map_dt <- read_result_table(
        file.path(ctx$meta$result_path, "2.Mapping", "mapping.stats.txt")
      )
      anno_dt <- read_result_table(
        file.path(ctx$meta$result_path, "2.Mapping", "genomic.anno.txt")
      )
      tagList(
        ctx$subsection("reads比对统计"),
        text_block(
          "使用BWA[@BWA]将质控后数据比对到对应物种参考基因组，提取比对到基因组唯一位置的比对结果。"
        ),
        if (!is.null(map_dt) &&
            all(c("total_map", "unique_map") %in% names(map_dt))) {
          tm <- rp_pct_mean(map_dt$total_map)
          um <- rp_pct_mean(map_dt$unique_map)
          kpi_row(
            kpi(sprintf("%.1f%%", tm), "Total mapping rate",
                rp_status(tm, 70, 60)),
            kpi(sprintf("%.1f%%", um), "Unique mapping rate",
                rp_status(um, 70, 60)),
            kpi(as.character(nrow(map_dt)), "Samples")
          )
        },
        if (!is.null(map_dt)) {
          tagList(
            ctx$data_table(map_dt, title = "reads比对统计",
              truncate = names(map_dt), explain_sheet = "MapState",
              source = "2.Mapping/mapping.stats.txt")
          )
        } else {
          empty_block()
        },
        ctx$note(
          "理想情况下，基因组整体比对率(total_map)应大于70%，唯一比对率(unique_map)应大于70%。",
          "若整体比对率低于70%，可能与物种信息不一致、参考基因组组装不完整或样本污染有关；",
          "若整体比对率大于70%而唯一比对率小于70%，可能受物种/样本类型影响或样本发生降解。"
        ),
        ctx$subsection("reads基因组区域分布"),
        if (!is.null(anno_dt)) {
          tagList(
            ctx$data_table(anno_dt, title = "reads基因组分布统计",
              truncate = names(anno_dt), explain_sheet = "ReadsAnno",
              source = "2.Mapping/genomic.anno.txt")
          )
        } else {
          empty_block()
        }
      )
    }
  )
}

## ---------------------------------------------------------------------
## 4. reads distribution + replicate quality
## ---------------------------------------------------------------------

#' @rdname chip_report_modules
#' @export
mod_chip_reads_dist <- function() {
  module(
    id = "readsdist",
    title = "reads偏好性分布与重复性评估",
    required_dirs = "3.Quality",
    render = function(ctx) {
      profile_imgs <- ctx$find(".png", dir = "3.Quality/RegionDis", key = "Profile")
      pca_imgs <- ctx$find(".png", dir = "3.Quality/PCA", key = "PCA")
      cor_imgs <- ctx$find(".png", dir = "3.Quality/Cor", key = "cor")
      tagList(
        ctx$subsection("reads偏好性分布"),
        if (length(profile_imgs) > 0L) {
          tagList(
            ctx$gallery(profile_imgs, title = "reads基因区域分布图"),
            text_block(
              "横坐标为基因各区域，纵坐标为reads富集强度，ChIP数据通常会在TSS附近出现结合峰。",
              "可使用IGV查看具体基因组区域的reads分布。"
            ),
            file_path_note("Report/ChIP/3.Quality/RegionDis/*png|pdf")
          )
        } else {
          empty_block()
        },
        ctx$subsection("基因组重复性评估"),
        if (length(pca_imgs) > 0L || length(cor_imgs) > 0L) {
          tagList(
            ctx$gallery(c(pca_imgs, cor_imgs), title = "样本相似性图"),
            file_path_note("Report/ChIP/3.Quality/Cor|PCA/*png|pdf")
          )
        } else {
          empty_block()
        }
      )
    }
  )
}

## ---------------------------------------------------------------------
## 5. peak calling
## ---------------------------------------------------------------------

#' @rdname chip_report_modules
#' @export
mod_chip_peak <- function(show_number = 10L) {
  module(
    id = "peak",
    title = "Peak鉴定",
    required_dirs = "4.PeakCalling",
    render = function(ctx) {
      info <- chip_group_info(ctx)
      annotation <- ctx$find("peakAnnotation.csv",
        dir = "4.PeakCalling/GroupComparePeaks/Profile/Annotation"
      )
      peak_dt <- NULL
      if (length(annotation) > 0L) {
        peak_dt <- read_result_table(annotation[[1L]], nrows = info$show_number)
      }
      profile_imgs <- ctx$find(".png",
        dir = "4.PeakCalling/GroupSamplePeaks/Profile"
      )
      tagList(
        ctx$subsection("组间Peak鉴定"),
        text_block(
          "基于MACS2[@MACS2]对各组配对的IP-Input样本进行Peak鉴定(qvalue cutoff=0.05)，",
          "使用MSPC、bedtools[@bedtools]等对组内一致性Peak区域进行整合，并对各组IP样本的组间Peak区域进行定量与注释。"
        ),
        if (!is.null(peak_dt)) {
          tagList(
            ctx$data_table(peak_dt, title = "组间Peak鉴定",
              source = annotation[[1L]],
              truncate = names(peak_dt), explain_sheet = "Peak"),
            file_path_note(
              "Report/ChIP/4.PeakCalling/GroupComparePeaks/Profile/Annotation/*.peakAnnotation.csv"
            )
          )
        } else {
          empty_block()
        },
        ctx$subsection("组内Peak特征分布可视化"),
        if (length(profile_imgs) > 0L) {
          tagList(
            ctx$gallery(profile_imgs, title = "组内Peak特征分布可视化"),
            file_path_note("Report/ChIP/4.PeakCalling/GroupSamplePeaks/Profile/*/*.png|pdf")
          )
        } else {
          empty_block()
        }
      )
    }
  )
}

## ---------------------------------------------------------------------
## 6. IP efficiency
## ---------------------------------------------------------------------

#' @rdname chip_report_modules
#' @export
mod_chip_ip <- function(show_number = 10L) {
  module(
    id = "ip",
    title = "IP效率评估",
    required_dirs = "3.Quality/IP",
    render = function(ctx) {
      finger_imgs <- ctx$find(".png", dir = "3.Quality/IP", key = "fingerprints")
      qc_dt <- read_result_table(
        file.path(ctx$meta$result_path, "3.Quality", "IP", "QCmetrics.csv")
      )
      tagList(
        ctx$subsection("reads累积覆盖度分布"),
        if (length(finger_imgs) > 0L) {
          tagList(
            ctx$gallery(finger_imgs, title = "reads累积覆盖度占比分布图"),
            text_block(
              "Input样本的累积覆盖度占比曲线接近对角线；效果好的IP样本曲线陡峭上升，",
              "说明大量reads富集到少数bins中。曲线偏离不明显并不必然意味着实验失败(如H3K27me3)。"
            ),
            file_path_note("Report/ChIP/3.Quality/IP/*fingerprints.png")
          )
        } else {
          empty_block()
        },
        ctx$subsection("IP数据质控统计"),
        if (!is.null(qc_dt)) {
          tagList(
            ctx$data_table(qc_dt, title = "IP数据质控统计表",
              source = "3.Quality/IP/QCmetrics.csv",
              truncate = names(qc_dt), explain_sheet = "IP"),
            file_path_note("Report/ChIP/3.Quality/IP/QCmetrics.csv")
          )
        } else {
          empty_block()
        }
      )
    }
  )
}

## ---------------------------------------------------------------------
## 7. peak expression similarity
## ---------------------------------------------------------------------

#' @rdname chip_report_modules
#' @export
mod_chip_similarity <- function() {
  module(
    id = "similarity",
    title = "Peak表达量相似性",
    required_dirs = "6.Similarity/ALLPeaks",
    render = function(ctx) {
      imgs <- ctx$find(".png", dir = "6.Similarity/ALLPeaks")
      tagList(
        ctx$subsection("组间Peak表达量相似性"),
        text_block(
          "得到IP样本组间Peak表达矩阵后，基于该数据再次进行样本重复性评估，",
          "并对组间Peak表达量分布进行统计，绘制前500高可变Peak的表达量聚类热图。"
        ),
        if (length(imgs) > 0L) {
          tagList(
            ctx$gallery(imgs, title = "组间Peak表达量相似性图"),
            file_path_note("Report/ChIP/6.Similarity/ALLPeaks/Cor|PCA|Heatmap|Expression/*png|pdf")
          )
        } else {
          empty_block()
        }
      )
    }
  )
}

## ---------------------------------------------------------------------
## 8. differential peaks (only when --type 1)
## ---------------------------------------------------------------------

#' @rdname chip_report_modules
#' @export
mod_chip_diff_peak <- function(show_number = 10L) {
  module(
    id = "diffpeak",
    title = "差异Peak鉴定与可视化",
    required_dirs = "5.DiffPeaks",
    when = chip_is_diff,
    render = function(ctx) {
      info <- chip_group_info(ctx)
      base <- file.path(ctx$meta$result_path, "5.DiffPeaks")

      diff_files <- ctx$find("All.diffGenes.csv", dir = "5.DiffPeaks")
      diff_dt <- NULL
      if (length(diff_files) > 0L) {
        diff_dt <- read_result_table(diff_files[[1L]], nrows = info$show_number)
      }
      volcano <- ctx$find(".png", dir = "5.DiffPeaks", key = "_vs_", recursive = TRUE)
      volcano <- volcano[grepl("_vs_", vapply(volcano, basename, character(1L)))]
      profile_imgs <- ctx$find(".png", dir = "5.DiffPeaks/Profile")
      deg_imgs <- ctx$find(".png", dir = "6.Similarity/DEGPeaks")
      coverage <- ctx$find("PeakCoverage.png", dir = "5.DiffPeaks",
        key = "PeakCoverage")

      tagList(
        ctx$subsection("差异Peak鉴定"),
        text_block(
          "基于组间Peak表达矩阵，针对各组样本有无重复，使用DESeq2或edgeR进行差异分析，",
          "并使用ChIPseeker对显著差异Peak进行注释。"
        ),
        if (!is.null(diff_dt)) {
          tagList(
            ctx$data_table(diff_dt, title = "差异Peak鉴定",
              truncate = names(diff_dt),
              explain_sheet = if (chip_is_diff(ctx)) "DEG" else "unDEG"),
            file_path_note("Report/ChIP/5.DiffPeaks/*/*.csv")
          )
        } else {
          empty_block()
        },
        ctx$subsection("差异Peak火山图"),
        if (length(volcano) > 0L) {
          tagList(
            ctx$gallery(volcano, title = "差异Peak火山图"),
            file_path_note("Report/ChIP/5.DiffPeaks/*/*.png|pdf")
          )
        } else {
          empty_block()
        },
        ctx$subsection("显著差异Peak特征分布可视化"),
        if (length(profile_imgs) > 0L) {
          tagList(
            ctx$gallery(profile_imgs, title = "显著差异Peak特征分布可视化"),
            file_path_note("Report/ChIP/5.DiffPeaks/Profile/*/*.png|pdf")
          )
        } else {
          empty_block()
        },
        ctx$subsection("显著差异Peak表达量相似性"),
        if (length(deg_imgs) > 0L) {
          tagList(
            ctx$gallery(deg_imgs, title = "显著差异Peak表达量相似性图"),
            file_path_note("Report/ChIP/6.Similarity/DiffGenes/Cor|PCA|Heatmap|Expression/*png|pdf")
          )
        } else {
          empty_block()
        },
        ctx$subsection("显著差异Peak可视化"),
        text_block("选取显著性前10的显著差异Peak，展示其reads覆盖情况与Peak所在基因位置信息。"),
        if (length(coverage) > 0L) {
          tagList(
            ctx$gallery(coverage, title = "显著差异Peak可视化"),
            file_path_note("Report/ChIP/5.DiffPeaks/*/PeakVis/*.PeakCoverage.png|pdf")
          )
        } else {
          empty_block()
        }
      )
    }
  )
}

## ---------------------------------------------------------------------
## 9. enrichment (GO/KEGG, only when --type 1)
## ---------------------------------------------------------------------

#' @rdname chip_report_modules
#' @export
mod_chip_enrich <- function(show_number = 10L) {
  module(
    id = "enrich",
    title = "显著差异Peak关联基因功能分析",
    required_dirs = "5.DiffPeaks",
    when = chip_is_diff,
    render = function(ctx) {
      info <- chip_group_info(ctx)
      go_dt <- chip_read_enrich(ctx, "GOenrich_total.csv", info)
      kegg_dt <- chip_read_enrich(ctx, "KEGGenrich_total.csv", info)
      go_imgs <- chip_enrich_images(ctx, "Enrichment/GO")
      kegg_imgs <- chip_enrich_images(ctx, "Enrichment/KEGG")
      kegg_imgs <- kegg_imgs[!grepl(
        "PathWay", vapply(kegg_imgs, basename, character(1L)))]

      tagList(
        ctx$subsection("GO富集分析"),
        text_block(
          "GO是国际标准化的基因功能分类体系，将基因功能分成生物过程(BP)、细胞组分(CC)、分子功能(MF)三类。",
          "显著差异Peak关联基因GO富集分析通过超几何检验找出显著富集(pvalue<0.05)的Term。"
        ),
        if (!is.null(go_dt)) {
          tagList(
            ctx$data_table(go_dt, title = "GO富集分析结果",
              truncate = names(go_dt), explain_sheet = "GO")
          )
        } else {
          empty_block()
        },
        if (length(go_imgs) > 0L) {
          ctx$gallery(go_imgs, title = "GO富集柱状图与气泡图")
        } else {
          empty_block()
        },
        ctx$subsection("KEGG富集分析"),
        text_block(
          "KEGG是整合了基因组、化学和系统功能信息的综合数据库。以Pathway为单位统计映射的",
          "显著差异Peak关联基因数目，应用超几何检验找出显著富集(pvalue<0.05)的Pathway。"
        ),
        if (!is.null(kegg_dt)) {
          tagList(
            ctx$data_table(kegg_dt, title = "KEGG富集分析结果",
              truncate = names(kegg_dt), explain_sheet = "KEGG")
          )
        } else {
          empty_block()
        },
        if (length(kegg_imgs) > 0L) {
          ctx$gallery(kegg_imgs, title = "KEGG富集柱状图与气泡图")
        } else {
          empty_block()
        }
      )
    }
  )
}

chip_read_enrich <- function(ctx, pattern, info) {
  if (is.na(info$compare)) return(NULL)
  files <- ctx$find(pattern, dir = file.path("5.DiffPeaks", info$compare, "Enrichment"))
  if (length(files) == 0L) return(NULL)
  read_result_table(files[[1L]], nrows = info$show_number)
}

chip_enrich_images <- function(ctx, sub) {
  info <- chip_group_info(ctx)
  if (is.na(info$compare)) return(list())
  imgs <- ctx$find(".png", dir = file.path("5.DiffPeaks", info$compare, sub))
  if (length(imgs)) names(imgs) <- basename(imgs)
  imgs
}

## ---------------------------------------------------------------------
## 10. motif (only when --type 1)
## ---------------------------------------------------------------------

#' @rdname chip_report_modules
#' @export
mod_chip_motif <- function() {
  module(
    id = "motif",
    title = "Motif分析",
    required_dirs = "5.DiffPeaks",
    when = chip_is_diff,
    render = function(ctx) {
      info <- chip_group_info(ctx)
      homer <- NULL
      if (!is.na(info$compare)) {
        homer <- ctx$find("knownResults.html",
          dir = file.path("5.DiffPeaks", info$compare, "Motif")
        )
      }
      tagList(
        ctx$subsection("HOMER Motif分析"),
        text_block(
          "为了鉴定显著差异Peak区域的保守序列特征，使用HOMER[@HOMER]对显著差异Peak的",
          "summits上下游各200 bp区域进行8/10/12/14 bp四个长度的Motif分析，",
          "并基于JASPAR CORE 2016数据库进行已知Motif富集分析。"
        ),
        if (length(homer) > 0L && file.exists(homer[[1L]])) {
          tagList(
            details_block(
              content = rp_homer_iframe(homer[[1L]]),
              summary = "点击查看 HOMER knownResults",
              open = TRUE
            ),
            file_path_note("Report/ChIP/5.DiffPeaks/*/Motif/*")
          )
        } else {
          empty_block()
        }
      )
    }
  )
}

## Embed a HOMER knownResults.html into the single-file report via
## iframe srcdoc (a local `src` would break self-containment). Strips
## the <html> wrapper and absolute server paths, mirroring the legacy
## addHomerHtml() sanitisation, and never writes back to the source.
rp_homer_iframe <- function(path) {
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  lines[1L] <- sub("^[[:space:]]*<HTML>", "", lines[1L], ignore.case = TRUE)
  lines[length(lines)] <- sub("</HTML>[[:space:]]*$", "", lines[length(lines)],
                              ignore.case = TRUE)
  lines[1L] <- sub("<TITLE>.*Homer", "<TITLE>Homer", lines[1L],
                   ignore.case = TRUE)
  txt <- paste(lines, collapse = "\n")
  tags$iframe(
    srcdoc = txt, width = "100%", height = "560px",
    style = "border:1px solid #d0d7de;border-radius:8px;",
    title = "HOMER knownResults"
  )
}

## ---------------------------------------------------------------------
## 11. methods & tools
## ---------------------------------------------------------------------

#' @rdname chip_report_modules
#' @export
mod_chip_methods <- function() {
  module(
    id = "methods",
    title = "分析方法说明",
    required_dirs = "0.SampleInfo",
    render = function(ctx) {
      ## software/version table comes from the pipeline via
      ## report_context(options = list(software = data.frame(...)))
      tool_dt <- tryCatch(
        as.data.frame(ctx$meta$options$software), error = function(e) NULL
      )
      tagList(
        ctx$subsection("分析软件列表及版本"),
        if (!is.null(tool_dt) && nrow(tool_dt) > 0L) {
          ctx$data_table(tool_dt, title = "分析软件列表及版本",
            searchable = FALSE, default_page_size = 20L, align = "left")
        } else {
          empty_block(if (isTRUE(ctx$meta$dev_mode))
            "未提供软件版本信息（可通过 report_context(options = list(software = ...)) 传入）。"
            else "未提供软件版本信息。")
        },
        ctx$subsection("Methods描述"),
        ctx$note("为了方便客户撰写文章，可向分析人员索取英文版Methods文档作为参考。")
      )
    }
  )
}

## ---------------------------------------------------------------------
## ---------------------------------------------------------------------
## ATAC-seq module set (pipeline: /data/pipeline/ATAC_V3)
## ---------------------------------------------------------------------
## One report layer per pipeline module. Stage directories follow the
## REAL ATAC_V3 output layout (see modules/*/module.yaml exit_outputs):
##
##   QC/                 fastp summaries (Summary/*.txt, Summary/Plot/)
##   Map/                mapping.stats.txt, genomic.anno.txt, *.png
##   ATAC/Quality/       TSS signal matrix + plots            (signal)
##   ATAC/IPEval/        Eval_TSS|Fragment|Complexity|FingerPrint|IP,
##                       PeakAttr/, bamPeak_dt.csv            (qc_bam)
##   ATAC/Peaks/         GroupSamplePeaks/Profile/Feature/*.csv|png,
##                       GroupSamplePeaks/Motif/<group>/      (peakcall/anno/quant/vis/motif)
##   ATAC/DiffPeaks/<cmp>/  *.deg.csv, *.png, PeakVis/, PPI/, Enrichment/ (diff/enrich/net_ppi)
##   ATAC/Similarity/    PCA/cor/heatmap/violin               (similarity)
##   ATAC/Network/       TargetNet/3.TF_Net/*.png, Edges/Nodes (net_reg)
##   *.bw anywhere       bigwig inventory                     (signal)
##
## Every layer is gated on its stage directory: partial runs produce a
## proportionally shorter report.

## internal: gallery of matched figures for an ATAC stage directory
atac_figs_block <- function(ctx, dir, pattern, title, width = "70%") {
  imgs <- ctx$find(pattern, dir = dir, recursive = TRUE, key = "")
  if (!length(imgs)) return(empty_block(paste0("未找到匹配的图：", pattern)))
  names(imgs) <- tools::file_path_sans_ext(basename(unlist(imgs)))
  ctx$gallery(imgs, title = title)
}

## internal: all matched tables of a stage directory as numbered tables
atac_tabs_block <- function(ctx, dir, pattern, sep = ",", show_number = 10L) {
  fs <- ctx$find(pattern, dir = dir, recursive = TRUE, key = "")
  if (!length(fs)) return(empty_block("未找到匹配的统计表"))
  out <- lapply(fs, function(f) {
    dt <- read_result_table(f, sep = sep, nrows = show_number)
    if (is.null(dt)) return(NULL)
    ctx$data_table(dt, title = basename(f),
      truncate = if (ncol(dt) > 6L) names(dt) else NULL)
  })
  out <- out[!vapply(out, is.null, logical(1L))]
  if (!length(out)) return(empty_block("统计表均为空"))
  do.call(tagList, out)
}

#' @rdname chip_report_modules
#' @export
mod_atac_overview <- function(show_number = 10L) {
  module(
    id = "overview",
    title = "项目信息与样本分组",
    render = function(ctx) {
      info_dt <- data.frame(
        Item = c("Project Code", "Species", "Reference", "Analysis Type"),
        Value = c(ctx$meta$code %||% "-", ctx$meta$species %||% "-",
                  ctx$meta$ref_version %||% "Unknow", "ATAC-seq")
      )
      sample_file <- file.path(ctx$meta$result_path, "sample.txt")
      tagList(
        ctx$subsection("项目信息"),
        kv_table(info_dt),
        ctx$subsection("样本与分组信息"),
        if (file.exists(sample_file)) {
          dt <- read_result_table(sample_file, sep = "\t", nrows = show_number)
          if (is.null(dt)) empty_block() else {
            ctx$data_table(dt, title = "sample.txt",
              truncate = if (ncol(dt) > 6L) names(dt) else NULL)
          }
        } else {
          atac_tabs_block(ctx, "0.SampleInfo", ".*\\.txt$", sep = "\t",
            show_number = show_number)
        }
      )
    }
  )
}

#' @rdname chip_report_modules
#' @export
mod_atac_qc <- function(show_number = 10L) {
  module(
    id = "qc",
    title = "测序数据质控（QC）",
    required_dirs = "QC",
    render = function(ctx) {
      sum_dir <- file.path(ctx$meta$result_path, "QC", "Summary")
      filt <- read_result_table(file.path(sum_dir, "Filtered.Summary.txt"),
        sep = "\t")
      raw <- read_result_table(file.path(sum_dir, "Raw.Reads.txt"),
        sep = "\t")
      tagList(
        ctx$subsection("测序质量概览"),
        atac_figs_block(ctx, "QC/Summary/Plot",
          ".*(QC|Reads|Quality|Content).*", "碱基质量与碱基含量分布"),
        ctx$subsection("质控统计"),
        rp_kpis_from_qc(raw, filt),
        if (!is.null(filt)) {
          ctx$data_table(filt, title = "质控统计表",
            source = c("QC/Summary/Filtered.Summary.txt", "QC/Summary/Raw.Reads.txt"),
            truncate = names(filt), explain_sheet = "QC")
        } else {
          empty_block("未找到质控统计表（QC/Summary/）。")
        },
        file_path_note("Report/ATAC/QC/Summary/")
      )
    }
  )
}

#' @rdname chip_report_modules
#' @export
mod_atac_mapping <- function(show_number = 10L) {
  module(
    id = "mapping",
    title = "比对分析（Mapping）",
    required_dirs = "Map",
    render = function(ctx) {
      map_dir <- file.path(ctx$meta$result_path, "Map", "Summary")
      map_dt <- read_result_table(file.path(map_dir, "mapping.stats.txt"),
        sep = ",")
      anno_dt <- read_result_table(file.path(map_dir, "genomic.anno.txt"),
        sep = ",")
      base_dt <- read_result_table(file.path(map_dir, "MappedBase.txt"),
        sep = ",")
      kpis <- if (!is.null(map_dt) &&
                  all(c("TotalReads", "MappedReads") %in% names(map_dt))) {
        mr <- rp_pct_mean(sub("\\(.*", "", map_dt$MappedReads))
        kpi_row(
          kpi(as.character(nrow(map_dt)), "Samples"),
          kpi(sprintf("%.1f%%", mr), "Mean mapping rate",
              rp_status(mr, 70, 50))
        )
      }
      tagList(
        ctx$subsection("比对统计"),
        kpis,
        if (!is.null(map_dt)) {
          ctx$data_table(map_dt, title = "reads比对统计",
            truncate = names(map_dt))
        } else {
          empty_block("未找到 Map/Summary/mapping.stats.txt。")
        },
        file_path_note("Report/ATAC/Map/Summary/mapping.stats.txt"),
        ctx$subsection("基因组区域分布"),
        if (!is.null(anno_dt)) {
          ctx$data_table(anno_dt, title = "reads基因组分布统计",
            truncate = names(anno_dt))
        } else {
          empty_block()
        },
        if (!is.null(base_dt)) {
          ctx$data_table(base_dt, title = "比对碱基统计",
            source = "Map/Summary/MappedBase.txt",
            truncate = names(base_dt))
        },
        ctx$subsection("比对结果汇总图"),
        atac_figs_block(ctx, "Map/Summary", ".*\\.png$",
          "样本比对结果汇总", width = "60%")
      )
    }
  )
}

#' @rdname chip_report_modules
#' @export
mod_atac_quality <- function(show_number = 10L) {
  module(
    id = "quality",
    title = "测序质量深度评估（Quality）",
    required_dirs = file.path("ATAC", "Quality"),
    render = function(ctx) {
      tagList(
        ctx$subsection("TSS 信号热图与富集曲线"),
        atac_figs_block(ctx, file.path("ATAC", "Quality"),
          ".*(Heatmap|profile|enrichment).*", "TSS 信号", width = "85%"),
        ctx$subsection("样本相关性"),
        atac_figs_block(ctx, file.path("ATAC", "Quality"),
          ".*(cor|Cor).*", "样本相关性", width = "60%"),
        ctx$subsection("主成分分析（PCA）"),
        atac_figs_block(ctx, file.path("ATAC", "Quality"),
          ".*(PCA|pca).*", "PCA", width = "60%")
      )
    }
  )
}

#' @rdname chip_report_modules
#' @export
mod_atac_peak <- function(show_number = 10L) {
  module(
    id = "peak",
    title = "Peak calling 与注释",
    required_dirs = file.path("ATAC", "Peaks"),
    render = function(ctx) {
      tagList(
        ctx$subsection("Peak 基因组元件分布"),
        atac_figs_block(ctx, file.path("ATAC", "Peaks", "GroupSamplePeaks"),
          ".*pie.*", "Peak 元件分布", width = "55%"),
        ctx$subsection("Peak 功能区域统计"),
        atac_figs_block(ctx, file.path("ATAC", "Peaks", "GroupSamplePeaks"),
          ".*(Feature|bar).*", "Peak 功能区域", width = "75%"),
        ctx$subsection("Peak 数量与注释统计"),
        atac_tabs_block(ctx, file.path("ATAC", "Peaks"),
          ".*(GenoFeature|count|attr).*\\.csv$", sep = ",",
          show_number = show_number)
      )
    }
  )
}

#' @rdname chip_report_modules
#' @export
mod_atac_diff <- function(show_number = 10L) {
  module(
    id = "diff",
    title = "差异分析与功能富集",
    required_dirs = file.path("ATAC", "DiffPeaks"),
    when = function(ctx) identical(ctx$meta$type, "1"),
    render = function(ctx) {
      tagList(
        ctx$subsection("差异 Peak 可视化"),
        atac_figs_block(ctx, file.path("ATAC", "DiffPeaks"),
          ".*\\.png$", "差异 Peak", width = "60%"),
        ctx$subsection("差异 Peak 统计表"),
        atac_tabs_block(ctx, file.path("ATAC", "DiffPeaks"),
          ".*\\.deg\\.csv$", sep = ",", show_number = show_number),
        ctx$subsection("功能富集分析"),
        atac_figs_block(ctx, file.path("ATAC", "DiffPeaks"),
          ".*(bar|dot|Bar|Dot).*", "GO/KEGG 富集", width = "80%"),
        atac_tabs_block(ctx, file.path("ATAC", "DiffPeaks"),
          ".*_total\\.csv$", sep = ",", show_number = show_number)
      )
    }
  )
}

#' @rdname chip_report_modules
#' @export
mod_atac_similarity <- function(show_number = 10L) {
  module(
    id = "similarity",
    title = "相似性与聚类",
    required_dirs = file.path("ATAC", "Similarity"),
    render = function(ctx) {
      tagList(
        ctx$subsection("Peak 表达聚类"),
        atac_figs_block(ctx, file.path("ATAC", "Similarity"),
          ".*(heatmap|Heatmap).*", "Peak 表达聚类", width = "70%"),
        ctx$subsection("PCA 与相关性"),
        atac_figs_block(ctx, file.path("ATAC", "Similarity"),
          ".*(PCA|cor).*", "PCA/相关性", width = "55%"),
        ctx$subsection("Peak 表达分布与组内变异"),
        atac_figs_block(ctx, file.path("ATAC", "Similarity"),
          ".*(violin|CV).*", "表达分布/CV", width = "60%")
      )
    }
  )
}

#' @rdname chip_report_modules
#' @export
mod_atac_atacqc <- function(show_number = 10L) {
  module(
    id = "atacqc",
    title = "ATAC 专项质控（IPEval）",
    required_dirs = file.path("ATAC", "IPEval"),
    render = function(ctx) {
      ip_dir <- file.path("ATAC", "IPEval")
      ip_dt <- read_result_table(
        file.path(ctx$meta$result_path, ip_dir, "bamPeak_dt.csv"), sep = ",")
      tagList(
        ctx$subsection("ATAC 专项质控指标"),
        if (!is.null(ip_dt)) {
          ctx$data_table(ip_dt, title = "bam/Peak 质控指标汇总",
            source = file.path("ATAC", "IPEval", "bamPeak_dt.csv"),
            truncate = names(ip_dt))
        },
        ctx$subsection("FRiP（峰内 reads 比例）"),
        atac_figs_block(ctx, ip_dir, ".*FRiP.*", "FRiP", width = "60%"),
        ctx$subsection("片段大小分布"),
        atac_figs_block(ctx, ip_dir, ".*(frag|Frag).*", "片段大小分布",
          width = "60%"),
        ctx$subsection("文库复杂度（PBC/NRF）"),
        atac_figs_block(ctx, ip_dir, ".*(Complexity|PBC|NRF).*",
          "文库复杂度", width = "55%"),
        ctx$subsection("Fingerprint 与 TSS 富集分数"),
        atac_figs_block(ctx, ip_dir, ".*(fingerprint|Fingerprint).*",
          "Fingerprint", width = "55%"),
        atac_figs_block(ctx, ip_dir, ".*(TSS|tss).*", "TSS 富集", width = "60%")
      )
    }
  )
}

#' @rdname chip_report_modules
#' @export
mod_atac_network <- function(show_number = 10L) {
  module(
    id = "network",
    title = "调控网络",
    required_dirs = file.path("ATAC", "Network"),
    render = function(ctx) {
      tagList(
        ctx$subsection("TF-靶基因调控网络（TOBIAS footprint）"),
        atac_figs_block(ctx, file.path("ATAC", "Network"),
          ".*(Network|network).*", "调控网络", width = "80%"),
        ctx$subsection("网络边表与节点表"),
        atac_tabs_block(ctx, file.path("ATAC", "Network"),
          "(Edges|Nodes).*", sep = "\t", show_number = show_number)
      )
    }
  )
}

#' @rdname chip_report_modules
#' @export
mod_atac_motif <- function(show_number = 10L) {
  module(
    id = "motif",
    title = "Motif 分析",
    required_dirs = file.path("ATAC", "Peaks"),
    render = function(ctx) {
      motif_root <- file.path(ctx$meta$result_path,
        "ATAC", "Peaks", "GroupSamplePeaks")
      dirs <- list.dirs(motif_root, recursive = TRUE)
      dirs <- dirs[grepl("Motif$", dirs)]
      if (!length(dirs)) return(empty_block("未找到 Motif 结果目录。"))
      out <- lapply(dirs, function(md) {
        known <- list.files(file.path(md, "knownResults"),
          "knownResults.txt", full.names = TRUE)
        logos <- list.files(file.path(md, "knownResults"),
          "logo.*\\.png$", full.names = TRUE)
        tagList(
          ctx$subsection(paste0("known motif（",
            basename(dirname(md)), "）")),
          if (length(known)) {
            dt <- read_result_table(known[1L], sep = "\t",
              nrows = show_number)
            if (is.null(dt)) empty_block() else {
              ctx$data_table(dt, title = "known motif 统计",
                source = known[1L],
                truncate = names(dt))
            }
          } else empty_block(),
          if (length(logos)) {
            ctx$gallery(logos[seq_len(min(6L, length(logos)))],
              title = "top motif 序列 logo")
          } else empty_block()
        )
      })
      do.call(tagList, out)
    }
  )
}

#' @rdname chip_report_modules
#' @export
mod_atac_signal <- function(show_number = 10L) {
  module(
    id = "signal",
    title = "附录：Bigwig/Signal 文件清单",
    render = function(ctx) {
      ## bigwig may live under <out>/Signal or <out>/ATAC/... — scan
      ## recursively so the inventory never depends on the exact dir
      bws <- list.files(ctx$meta$result_path, "\\.bw$",
        full.names = FALSE, recursive = TRUE, ignore.case = TRUE)
      if (!length(bws)) {
        return(empty_block("未找到 bigwig 文件（*.bw）。"))
      }
      ctx$data_table(
        data.frame(File = basename(bws), Path = file.path("Report/ATAC", bws)),
        title = "Bigwig 文件清单", searchable = FALSE,
        default_page_size = 50L, align = "left")
    }
  )
}

#' @rdname chip_report_modules
#' @export
atac_report_modules <- function(show_number = 10L) {
  list(
    mod_atac_overview(show_number = show_number),
    mod_atac_qc(show_number = show_number),
    mod_atac_mapping(show_number = show_number),
    mod_atac_quality(show_number = show_number),
    mod_atac_peak(show_number = show_number),
    mod_atac_diff(show_number = show_number),
    mod_atac_similarity(show_number = show_number),
    mod_atac_atacqc(show_number = show_number),
    mod_atac_network(show_number = show_number),
    mod_atac_motif(show_number = show_number),
    mod_atac_signal(show_number = show_number),
    mod_references()
  )
}

#' The m6A pipeline (legacy `/data/pipeline/m6A/Report/m6A.Rmd`, ~1170
#' lines, single file) follows the same module contract as the ChIP
#' exemplar. This release ships the interface plus an overview module so
#' the set can be assembled iteratively, one module at a time, without
#' ever duplicating whole documents again. Module authors migrate
#' sections from the legacy Rmd into `function(ctx)` bodies using the
#' `ctx$find()` / `ctx$figure()` / `ctx$data_table()` primitives.
#'
#' @return A list of [module()] objects.
#' @seealso [chip_report_modules()]
#' @export
m6a_report_modules <- function() {
  list(
    module(
      id = "overview",
      title = "Project Overview",
      required_dirs = "0.SampleInfo",
      render = function(ctx) {
        ctx$subsection("项目信息")
        kv_table(list(
          "项目名称" = ctx$meta$project,
          "分析类型" = "m6A-seq",
          "物种" = ctx$meta$species,
          "报告日期" = as.character(ctx$meta$date)
        ))
      }
    )
  )
}
