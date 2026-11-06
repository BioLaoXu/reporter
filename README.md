# reporter

**Modular Automated HTML Reporting for Bioinformatics Pipelines**

`reporter` 用**纯 R**（htmltools + bslib + reactable）替代传统 R Markdown 报告：
一个结果目录 + 一组项目参数 → 一份**单文件自包含 HTML 报告**。
模块是普通 R 函数，可单独开发、单独调试、单独测试；图/表自动编号；
顶部导航栏、侧边栏目录（滚动同步高亮）、品牌皮肤全部可配置。

架构图与数据流图见 `docs/reporter-architecture.html`
与 `docs/reporter-dataflow.html`（内置主题切换与 PNG/SVG 导出）。

## 文档索引

| 文档 | 定位 |
|---|---|
| [docs/功能速查.md](docs/功能速查.md) | **全部函数/参数/底层逻辑速查表**（数据加载、内容原语、模块库、CLI、渲染管线） |
| [docs/技术路线.md](docs/技术路线.md) | 技术选型对比与决策、分阶段路线图、风险清单（决策/汇报用） |
| [docs/reporter-roadmap.html](docs/reporter-roadmap.html) | Phase 0–4 技术路线图（archify 交互图，英文） |
| [docs/reporter-architecture.html](docs/reporter-architecture.html) | 分层架构图（archify 交互图，英文） |
| [docs/reporter-dataflow.html](docs/reporter-dataflow.html) | 渲染数据流图（archify 交互图，英文） |
| [docs/技术文档.md](docs/技术文档.md) | 内部实现：渲染管线、内联细节、模块开发规范 |
| [README.md](README.md) | 使用手册：安装、快速上手、模块契约、主题定制、迁移对照表 |

---

## 为什么不用 Rmd / Quarto

| 痛点（旧方案） | reporter 的解法 |
|---|---|
| 单文件 1000+ 行巨型 Rmd | 模块 = `function(ctx) -> tagList`，每个模块几十行 |
| 按物种/分支整份复制 Rmd（ChIP 13 份、m6A 9 份变体） | `required_dirs` + `when()` 声明式启用，一份模板跑所有分支 |
| 全局计数器 `tablenum/fignum`，child 顺序敏感 | 编号器在 ctx 内，与模块顺序解耦 |
| 参数靠 globalenv 传递 | 一切经 `report_context()`，模块无全局状态 |
| utils.R 多副本漂移 | 收编为正式导出函数 + roxygen 文档 + testthat 测试 |
| 渲染失败被 tryCatch 吞掉仍报成功 | 失败模块降级为报告内错误占位，CLI 退出码非 0 |
| 依赖 Quarto/Node/外部渲染器 | 零外部运行时，装包即用 |

## 安装

```bash
# 方式一：激活项目私有库（推荐）
source /data/InHousePackages/reporter/env.sh

# 方式二：安装到私有库
R CMD INSTALL --library=/data/InHousePackages/reporter/library /data/InHousePackages/reporter
```

依赖均为服务器已装包：htmltools、bslib、reactable、data.table、openxlsx、readxl、xfun、optparse、rlang、tippy。**不需要** Quarto、Node、pandoc。

## 快速上手

### R API

```r
library(reporter)

## 1. 上下文：结果目录 + 项目参数
ctx <- report_context(
  result_path = "/data/Report/chip_project/xxx/Report/ChIP",
  species     = "Homo_sapiens",
  project     = "8例ChIPseq检测分析",
  code        = "72407172801",
  logo        = "smzy",          # 品牌预设：smzy / jinyu / blank / default
  type        = "1"              # 1=有重复/差异组，0=单分组
)

## 2. 组装模块（ChIP 示范模块集按结果目录自动启用）
report <- create_report(ctx)
report <- do.call(add_module, c(list(report = report), chip_report_modules()))

## 3. 渲染：单文件自包含 HTML
res <- render_report(report,
  output     = "report.html",
  standalone = TRUE)
res$errors    # 失败模块列表（渲染不中断，报告内有错误占位）
```

### 命令行（流水线无缝替换旧 Report.R）

```bash
Rscript inst/templates/run_report.R \
  --result /path/to/results \
  --species Homo_sapiens \
  --project "8例ChIPseq检测分析" \
  --code 72407172801 \
  --logo smzy --company "重庆生命知源科技有限公司" --phonenum "023-63258086" \
  --type 1 --modules chip --outhtml report
# 退出码：0 成功 | 1 有模块失败 | 2 致命错误
```

示例成品报告**不入库**（避免大文件与真实项目数据），用以下脚本在本地生成：

```r
Rscript inst/templates/make_example_report.R   # 生成到 examples/
```

关键交互截图见 `examples/screenshots/`（本地生成后可用）。

## 模块契约

```r
mod_my <- module(
  id            = "mysec",           # 锚点 id：#mod-mysec
  title         = "我的章节",         # 导航栏 + 侧栏目录标题
  required_dirs = "4.PeakCalling",   # 相对 result_path，全部存在才启用
  when = function(ctx) ctx$meta$type == "1",   # 额外开关（可选）
  render = function(ctx) {
    peaks <- ctx$find("peakAnnotation.csv",
                      dir = "4.PeakCalling/GroupComparePeaks/Profile/Annotation")
    dt <- read_result_table(peaks[[1]], nrows = 10)
    tagList(
      ctx$subsection("Peak 注释结果"),
      ctx$data_table(dt, title = "Peak annotation"),
      ctx$figure(peaks[[1]], title = "example", width = "70%"),
      ctx$note("结果解读写在这里。")
    )
  }
)
```

### ctx 可用方法

| 方法 | 作用 |
|---|---|
| `ctx$subsection(title, desc)` | 三级标题，自动注册进侧栏目录（滚动同步高亮） |
| `ctx$figure(path, title, ...)` | 插图，自动 base64 内联 + "Figure N" 编号 |
| `ctx$gallery(images, title)` | 多图画廊（前后切换 + 样本搜索 + 灯箱） |
| `ctx$data_table(df, title, ...)` | reactable 交互表 + "Table N" 编号；**自动挂载表格解释**（按列名查 TableExplain 注册表，`explain=FALSE` 关闭，`explain_sheet="QC"` 指定 sheet 消歧义） |
| `ctx$explain(cols, sheet)` | 手动查询列解释注册表（[load_explanations()]） |
| `ctx$find(pattern, dir, key)` | 在结果目录中按模式找文件（继承 AutoFind） |
| `ctx$meta$ref_version` 等 | 参考基因组元信息：`report_context(..., ref_version=, fasta_db=, gtf_db=)` 显式传入（替代旧定制 xlsx 查表） |
| `ctx$note/warning/tip(...)` | 语义提示框 |
| `mod_references(bib_file, title)` | **参考文献模块**（通用）：自动加载 .bib 渲染编号文献列表——优先项目结果目录 `references.bib`，否则用包内置库（90 条）；纯 R 解析，无需 pandoc |
| `ctx$meta` | 项目参数（species/project/code/options...） |

## 主题与页面定制

```r
reporter_theme(
  preset       = "smzy",             # 品牌预设（logo/公司/电话/主色）
  primary      = "#0D6E8C",          # 覆盖主色
  style        = "v2",               # 视觉风格："classic"（默认卡片风）| "v2"（编辑排版风）
  company      = "...", phonenum = "...",
  caption_lang = "en"                # Figure/Table 或 图/表
)
```

**两种风格**：`classic`（v0.1.0 默认，卡片化+渐变封面）与 `v2`（去 AI 化的编辑排版风——白底扉页封面、细规则线分区、纯文本编号前缀、10x 式 KPI 指标行、更紧凑的排版；设计依据见 [docs/设计调研-网页报告模板.md](docs/设计调研-网页报告模板.md)）。v2 成品由 `make_example_report.R` 本地生成（同脚本可产出 card 皮肤版本）。

页面全部语义化 class（`rp-navbar` `rp-toc` `rp-module` `rp-fig` `rp-callout`…），
配色暴露为 `--rp-*` CSS 变量。**加一份自定义 CSS 即可整体换肤**：

```r
render_report(report, output = "report.html",
  theme = reporter_theme(preset = "blank",
                         extra_variables = list("rp-primary" = "#2B6CB0")))
```

## 从旧 Rmd 迁移（对照表）

| 旧 utils.R | reporter |
|---|---|
| `loadTable` / `fastLoad` | `read_result_table()` |
| `loadTopTable` / `loadRawCount` | `load_top_table()` / `load_raw_count()` |
| `loadGenoVersion` | `load_genome_version()` |
| `AutoFind` | `auto_find()` 或 `ctx$find()` |
| `AutoLoadRDS` | `load_plot_objects()` |
| `renderCols` / `render.reactable.cell.with.tippy` | `render_cols()` / `tippy_cell()` |
| `addTableTab` | `ctx$data_table()` |
| `addPlotTab` / `addFigTab` / `slick_pics` / `slickR_Fig` | `ctx$figure()` / `ctx$gallery()` |
| `addexplain` | `table_explain()` |
| `addHtml` / `table2detial` | `details_block()` |
| `fillEmpty` | `empty_block()` |
| `add_file_path` | `file_path_note()` |
| `add_gap_logo` | `section_divider()` |
| `addRmd` / `loadRmd` / `loadRmd2` / `custom_knit_child` | **废弃** —— 由 `module()` + `add_module()` 取代 |

详细迁移指南与内部实现见 `docs/技术文档.md`。

## 测试

```bash
cd /data/InHousePackages/reporter
Rscript -e '.libPaths(c("library","/data/softwares/R/library")); library(testthat); library(reporter); test_dir("tests/testthat")'
```

覆盖：上下文/编号器、内容原语、数据读取、内联管线（断言无外链）、
ChIP 模块集端到端（type=0 自动跳过差异模块）、多文件模式。

## 目录结构

```
reporter/
├── R/                    # 包源码（context / primitives / tables / data-io /
│                         #   theme / layout / report / inline / modules /
│                         #   cli / utils）
├── inst/assets/          # reporter.css + reporter.js（零 jQuery）
├── inst/extdata/         # TableExplain.xlsx · references.bib
├── inst/examples/        # 合成结果目录生成器（示例与测试共用）
├── inst/images|logos/    # 流程图与品牌 logo
├── inst/templates/       # run_report.R（流水线入口）+ 示例再生成脚本
├── tests/testthat/       # 单测（fixture 包装器引用 inst/examples）
├── tests/ui/             # Playwright UI 验证脚本（node）
├── examples/             # 本地生成的示例报告（不入库）
├── docs/                 # 技术文档 + 架构/数据流图（archify HTML+JSON）
└── library/              # 包私有 R 库（不入库）
```
