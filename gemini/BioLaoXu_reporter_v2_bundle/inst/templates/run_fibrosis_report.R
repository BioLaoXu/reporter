# ============================================================================
# BioLaoXu/reporter R Pipeline Script (run_fibrosis_report.R)
# Programmatically builds the upgraded report using create_context() & module()
# ============================================================================
library(reporter)
library(htmltools)

# 1. Initialize Report Context (No cluttered navbar widgets; metadata bound cleanly)
ctx <- create_context(
  result_path  = "Result_SP20260727007/",
  project      = "mRNA-seq 靶向面板 (4 组 × 4 重复)",
  species      = "Mus_musculus (GRCm39)",
  code         = "SP20260727007",
  company      = "NGS 生信分析交付中心",
  phonenum     = "2026-11-04 · reporter v2.0",
  type         = "1",
  caption_lang = "zh",
  explain_file = system.file("extdata", "TableExplain.xlsx", package = "reporter")
)

# 2. Module 01 (First Block): 项目信息、参考基因组与实验样本设计
mod_genome_overview <- module(
  id = "genome-overview",
  title = "01 · 项目信息、参考基因组与实验样本设计",
  required_dirs = character(0),
  render = function(ctx) {
    ref_df <- read_result_table(ctx$find("ref_genome_and_pipeline_params.tsv", dir = "00_Config")[[1]])
    grp_df <- read_result_table(ctx$find("group_design_summary.tsv", dir = "01_QC_Mapping")[[1]])
    qc_df  <- read_result_table(ctx$find("QC_Alignment_Summary_16Samples.tsv", dir = "01_QC_Mapping")[[1]])

    tagList(
      ctx$subsection("参考基因组配置与生物信息学分析基线"),
      ctx$text("本项目针对小鼠肺组织样本开展高通量转录组测序（mRNA-seq）与肺纤维化相关靶向功能面板定量分析。"),
      ctx$data_table(ref_df, title = "项目信息与参考基因组配置表", lite = TRUE),
      ctx$subsection("样本分组设计、比较策略与测序质控明细"),
      ctx$data_table(grp_df, title = "样本实验分组与组内质控均值表", lite = TRUE),
      details_block(
        summary = "点击展开查看全部 16 例样本的测序数据量、Q30 与基因组比对率质控明细表",
        ctx$data_table(qc_df, title = "16 例样本测序与比对质控表", explain = "QC", lite = TRUE)
      )
    )
  }
)

# 3. Module 02: 核心发现与结果摘要
mod_exec_summary <- module(
  id = "exec",
  title = "02 · 核心发现与结果摘要",
  render = function(ctx) {
    tagList(
      ctx$subsection("关键统计指标与核心结论"),
      kpi_row(
        kpi("62 / 62", "四组间差异显著基因 (FDR < 0.05)", status = "ok"),
        kpi("+0.915", "C 组全面板平均 log2 差值峰值", status = "warn"),
        kpi("+2.483", "B 组 M5 炎症模块平均升幅", status = "bad"),
        kpi("5 / 5", "M7 肺泡上皮屏障基因全线下调", status = "neutral")
      ),
      callout_block(
        type = "tip",
        title = "核心生物学发现提炼",
        "62 个靶向基因在四组间全部达到 FDR < 0.05（其中 57 个达 FDR < 0.001）；B 组炎症与趋化因子模块升幅最大（+2.483），C 组细胞外基质沉积达峰（+1.875），M7 肺泡上皮屏障标志物一致下调。"
      ),
      ctx$subsection("靶向面板构成与解读边界声明"),
      callout_block(
        type = "warning",
        title = "靶向面板先验性边界声明",
        "本面板为先验选定的 62 个已知肺纤维化相关基因集合，并非全转录组无偏筛选结果，不可外推为全基因组差异比例。"
      )
    )
  }
)

# 4. Module 03: 核心结果图轮播画廊与交互式热图工作台
mod_heatmap_gallery <- module(
  id = "heatmap",
  title = "03 · 核心结果图轮播画廊与交互式单基因表达工作台",
  required_dirs = "02_Figures",
  render = function(ctx) {
    figs <- ctx$find(".*\\.(png|webp|svg)$", dir = "02_Figures")
    tagList(
      ctx$subsection("2.1 核心结果图集轮播预览（Carousel）"),
      ctx$gallery(
        images = figs,
        labels = c("01 · 标准热图 (Z-score)", "02 · 数值版热图 (log2值)", "03 · 模块轨迹与效应量", "04 · 样本 PCA 与相关性"),
        title  = "肺纤维化靶向分析核心图集"
      )
    )
  }
)

# 5. Assemble & Render Report with Upgraded Card/Console Theme
theme_v2 <- reporter_theme(
  style   = "card",
  primary = "#0D5C75",
  extra_css = "inst/assets/reporter.css"
)

report <- create_report(ctx) |>
  add_module(
    mod_genome_overview,
    mod_exec_summary,
    mod_heatmap_gallery
  )

res <- render_report(
  report,
  output     = "Pulmonary_Fibrosis_Report_v2.html",
  theme      = theme_v2,
  standalone = TRUE
)
