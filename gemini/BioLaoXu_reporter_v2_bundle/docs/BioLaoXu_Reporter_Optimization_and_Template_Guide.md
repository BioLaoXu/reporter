# NGS 结题报告前端 UI 设计规范与 `reporter` 自动复刻模板指南 (v2.0)

> **文档用途**：本规范专为自研 R 报告生成工具（`reporter`）的升级与自动化复刻而编写。您可以将本文档直接作为设计契约（Design Spec）放入 `reporter` 项目的 `docs/` 目录，或直接喂给代码生成工具/Agent，用于一对一复刻升级后的\*\*「去 AI 化科研刊物风（Editorial v2）+ DRAGEN 工业卡片风（Card）」\*\*双模报告体系。

## 一、全局设计原则（“去 AI 化”五条铁律）

为了让最终渲染出的 HTML 报告兼具 **Nature / NEJM 学术出版级质感** 与 [**Illumina DRAGEN**](https://help.connected.illumina.com/dragen/dragen-v4.6/product-guides/dragen-v4.6/dragen-reports) **/ [10x Genomics Cell Ranger](https://www.10xgenomics.com/support/software/cell-ranger/latest/analysis/outputs/cr-outputs-web-summary-count) 工业级生信工具感**，所有组件必须遵守以下视觉约束：

1. **零廉价渐变与零悬浮动画**：严禁使用大面积斜向蓝紫渐变（`linear-gradient(135deg, ...)`）、大圆角（`> 6px`）以及卡片悬停上浮阴影（`transform: translateY(-4px)`）。统一采用 `1px solid #DCE3EA` 发丝细线边框、`3px` 顶部结构色条与 `2px–4px` 克制微圆角。

2. **严格隔离“生物学数据色标”与“系统状态色标”**：

   * **表达量 / 差异倍数（Z-score / log2FC）**：全局唯一锁定 ColorBrewer `RdBu` 双极科研色阶——正向上调固定为深绯红 `#B2182B`，负向下调固定为科研冷蓝 `#2166AC`，零值固定为 `#F7F7F7`。严禁在表格中用红色标注负值或超链接。

   * **质控状态与告警（QC & Guardrails）**：深翠绿 `#1F7A4C`（PASS）、琥珀金 `#9A6700`（方法学边界/注意）、深砖红 `#B91C1C`（FAIL）仅用于质控胶囊与提示框左侧边线。

3. **零 Emoji 装饰**：严禁在标题、按钮、提示框中使用任何 Emoji（如 `🧬`、`📊`、`💡`）。统一采用等宽章节编号（`01`～`07`）与 `1.5px` 线宽的单色 SVG 矢量图标。

4. **全局等宽数字对齐（Tabular Numerals）**：在 `body` 与所有表格数值列强制开启 `font-variant-numeric: tabular-nums`，确保小数点、正负号、科学计数法（`1.18e-16`）在垂直方向严格对齐。

5. **零重型第三方前端依赖**：彻底移除 `jQuery`、`Bootstrap 3/5`、`htmlwidgets/Reactable` 运行时（立减 620 KB+ 体积，杜绝离线字体 404 与 Reactable 空白崩溃 Bug），所有交互（目录联动、画廊切换、表格检索排序、CSV 导出、灯箱缩放）均由单文件原生 Vanilla JS（`< 15 KB`）驱动。

## 二、色彩系统（CSS Custom Properties / Design Tokens）

在 `reporter` 的基础样式表（`inst/assets/reporter.css`）中，使用以下标准 CSS 变量覆盖原有的 `--rp-*` 变量：

```
:root {
  /* 1. 品牌与主结构色 (深青石板蓝，替代高饱和度亮蓝) */
  --rp-primary: #0D5C75;
  --rp-primary-dark: #073B4C;
  --rp-primary-light: #EBF4F7;

  /* 2. 生物学差异表达双极色标 (ColorBrewer RdBu 科学色标) */
  --rp-up: #B2182B;                  /* 上调 / 正向差值文字与色条 */
  --rp-up-bg: rgba(178, 24, 43, 0.12);
  --rp-zero: #F7F7F7;                /* 均值零点 */
  --rp-down: #2166AC;                /* 下调 / 负向差值文字与色条 */
  --rp-down-bg: rgba(33, 102, 172, 0.12);

  /* 3. 功能模块分类色盘 (7-8 分类高辨识度学术色盘) */
  --rp-mod-1: #377EB8;               /* M1: 蓝 */
  --rp-mod-2: #4DAF4A;               /* M2: 绿 */
  --rp-mod-3: #E41A1C;               /* M3: 红 */
  --rp-mod-4: #984EA3;               /* M4: 紫 */
  --rp-mod-5: #FF7F00;               /* M5: 橙 */
  --rp-mod-6: #00BFC4;               /* M6: 青 */
  --rp-mod-7: #A65628;               /* M7: 棕 */

  /* 4. 质控与语义状态色 (仅用于 QC 徽章与 Callout 边线) */
  --rp-ok: #1F7A4C;
  --rp-ok-bg: #EAF6F0;
  --rp-ok-border: #B7DFC9;
  --rp-warn: #9A6700;
  --rp-warn-bg: #FDF9F0;
  --rp-warn-border: #EBD5AE;
  --rp-bad: #B91C1C;
  --rp-bad-bg: #FBEAE7;

  /* 5. 中性灰阶与边框系统 (冷石板色系，保证长时间阅读舒适度) */
  --rp-ink: #18222C;                 /* 一级标题、正文主文字、核心数值 */
  --rp-ink-mid: #425262;             /* 二级正文、图注说明、表格次要列 */
  --rp-ink-dim: #6C7C8C;             /* 辅助说明、文件路径、英文副标题 */
  --rp-line: #DCE3EA;                /* 模块与表格外框主分割线 */
  --rp-line-light: #EDF1F5;          /* 表格行内细分割线 */
  --rp-bg-page: #FFFFFF;             /* Editorial 刊物模式默认纯白底 */
  --rp-bg-panel: #F7F9FB;            /* 侧边目录栏、抽屉、表头浅灰底 */
  --rp-bg-subtle: #FBFDFF;           /* 偶偶行斑马纹或流程图底色 */

  /* 6. 尺寸与圆角栅格 */
  --rp-navbar-h: 56px;               /* 顶部固定栏高度 */
  --rp-toc-w: 256px;                 /* 左侧目录栏宽度 */
  --rp-container-max: 1220px;        /* 主内容区最大宽度（适配宽表与双栏工作台） */
  --rp-radius: 3px;                  /* 全局微圆角 */
}


```

## 三、字体与排版层级规范（Typography Scale）

为确保离线交付给客户时**不发起任何外部 Google Fonts 请求且不出现本地 `.woff2` 404 报错**，统一使用跨平台系统级学术字体栈：

```
:root {
  /* 西文优先使用 Inter / 系统无衬线，中文优先使用思源黑体 / 苹方 / 微软雅黑 */
  --rp-font-sans: "Inter", -apple-system, BlinkMacSystemFont, "Segoe UI",
                  "Source Han Sans SC", "Noto Sans CJK SC", "PingFang SC",
                  "Hiragino Sans GB", "Microsoft YaHei", sans-serif;

  /* 基因名、样本编号、路径、统计数值、p/FDR 值统一使用等宽字体 */
  --rp-font-mono: "JetBrains Mono", "SFMono-Regular", Consolas,
                  "Liberation Mono", Menlo, monospace;

  /* 英文 SCI Methods 段落专用衬线体 */
  --rp-font-serif: Georgia, "Times New Roman", Times, serif;
}


```

| 排版元素 | CSS 选择器 | 字号 (`font-size`) | 字重 (`font-weight`) | 行高 (`line-height`) | 颜色与附加属性 | 
| ----- | ----- | ----- | ----- | ----- | ----- | 
| **报告主标题** | `.rp-cover-title` | `26px` | `700` | `1.3` | `var(--rp-ink)`，`letter-spacing: -0.2px` | 
| **封面眉题 (Eyebrow)** | `.rp-cover-eyebrow` | `11.5px` | `600` | `1.2` | `var(--rp-primary)`，等宽字体，全大写，`letter-spacing: 0.8px` | 
| **一级模块标题 (H2)** | `.rp-module-title` | `20px` | `700` | `1.35` | `var(--rp-ink)`，左侧配 `.rp-module-num` 编号块 | 
| **二级小节标题 (H3)** | `.rp-subsection` | `15.5px` | `700` | `1.4` | `var(--rp-ink)`，左侧 `3px solid var(--rp-primary)` 竖线 | 
| **正文段落** | `p`, `.rp-text` | `14px` | `400` | `1.68` | `var(--rp-ink)`，段间距 `10px` | 
| **KPI 核心大数字** | `.rp-kpi-num` | `24px` | `700` | `1.2` | `var(--rp-ink)`，`tabular-nums` | 
| **常规数据表格** | `.rp-table` | `12.8px` | `400` (表头 `600`) | `1.45` | 数值列加 `.num`（右对齐 + 等宽字体） | 
| **紧凑型明细宽表** | `.rp-table.compact` | `12px` | `400` (表头 `600`) | `1.35` | `white-space: nowrap`，单行高密度展示 | 
| **图注与方法说明** | `.rp-caption`, `.rp-callout` | `12.8px–13.5px` | `400` | `1.6` | `var(--rp-ink-mid)` | 
| **交付包路径胶囊** | `.rp-filepath` | `11.5px` | `500` | `1.3` | `var(--rp-font-mono)`，`var(--rp-ink-dim)` | 

## 四、客户视角的信息架构（IA）标准章节顺序

在 `reporter` 中定义报告模板 YAML 或 R 组装函数时，将传统的“生信流水线顺序”调整为以下 **7 步倒金字塔结构**：

1. **顶部常驻命令栏（`.rp-navbar`）+ 顶部隐藏式抽屉（`.rp-drawer`）**

   * 顶栏左侧：侧栏折叠按钮 + 报告名称 + 项目编号/物种/规模元信息。

   * 顶栏右侧：**`QC 质控基线: N/N PASS` 绿色状态胶囊**（点击展开上游 FastQC/fastp 与比对率汇总抽屉）+ **分组语义映射器** + **皮肤切换（刊物风 / DRAGEN 卡片风）** + **AI 解读抽屉按钮**。

2. **抬头封面与元信息六宫格（`.rp-cover`）**

   * 紧凑型学术抬头（高度控制在 `160px` 以内），展示项目编号、物种与定量单位、样本规模、面板/基因规模、统计检验方法、报告日期。

3. **`01` 核心发现与执行摘要（Executive Summary）**

   * 4 列 KPI 核心指标条（`.rp-kpi-strip`）+ 核心生物学发现提炼框（`.rp-callout-key`）+ 样本分组设计表 + 研究口径与解读边界声明框（`.rp-callout-guardrail`）。

4. **`02` 核心可视化与单基因交互剖析工作台（Core Visual Workbench）**

   * 采用双 Tab 设计：Tab 1（交互探索）为左侧动态矩阵/火山图/热图 + 右侧单基因跨组表达剖析卡（`.rp-gene-inspector`）；Tab 2（出版级原图画廊）为 R 导出的高分辨率静态图画廊（支持全屏灯箱与原图下载）。

5. **`03` 功能模块 / 通路富集定量格局（Module / Pathway Landscape）**

   * 模块级汇总表（带表内红蓝双向微条形图 `.div-bar`），支持点击任意模块联动筛选下方基因总表。

6. **`04` 关键差异基因双向榜单（Top Up / Down Signature Genes）**

   * 左右双栏并排展示 Top 12 显著上调基因（红标 `#B2182B`）与 Top 12 一致下调基因（蓝标 `#2166AC`）。

7. **`05–06` 组间差异特征总结 & 全量交互式结果明细总表（Master Interactive Grid）**

   * 替代 `Reactable` 的原生 JS 数据网格：支持关键词搜索、模块下拉过滤、变化方向过滤、点击表头排序、列口径折叠说明（`<details class="rp-details">`）及一键导出 CSV。

8. **`07` 统计方法路线图、软件版本、SCI 英文 Methods 与参考文献（Methodology & References）**

   * 内嵌 SVG 矢量技术路线图 + 软件与数据库版本表 + 一键复制英文 Methods 卡片 + 带 DOI 链接的编号参考文献 + 术语缩写表。

## 五、`reporter` 核心组件 HTML DOM 与 CSS 复刻模板

以下提供可直接粘贴到 `reporter` R 包模板目录（`inst/templates/`）中的完整 CSS 样式表与标准 HTML 结构。

### 5.1 完整生产级样式表（`reporter-v2.css`）

```
/* ==========================================================================
   reporter-v2.css — Scientific Editorial (Default) & DRAGEN Card Skin
   Zero external dependencies. Drop-in replacement for reporter.css.
   ========================================================================== */
:root {
  --rp-primary: #0D5C75;
  --rp-primary-dark: #073B4C;
  --rp-primary-light: #EBF4F7;
  --rp-up: #B2182B;
  --rp-up-bg: rgba(178, 24, 43, 0.12);
  --rp-down: #2166AC;
  --rp-down-bg: rgba(33, 102, 172, 0.12);
  --rp-ok: #1F7A4C;
  --rp-ok-bg: #EAF6F0;
  --rp-warn: #9A6700;
  --rp-warn-bg: #FFF8E6;
  --rp-ink: #18222C;
  --rp-ink-mid: #425262;
  --rp-ink-dim: #6C7C8C;
  --rp-line: #DCE3EA;
  --rp-line-light: #EDF1F5;
  --rp-bg-page: #FFFFFF;
  --rp-bg-panel: #F7F9FB;
  --rp-navbar-h: 56px;
  --rp-toc-w: 256px;
  --rp-radius: 3px;
  --rp-font-sans: "Inter", -apple-system, BlinkMacSystemFont, "Segoe UI", "PingFang SC", "Hiragino Sans GB", "Microsoft YaHei", sans-serif;
  --rp-font-mono: "JetBrains Mono", "SFMono-Regular", Consolas, "Liberation Mono", Menlo, monospace;
}

* { box-sizing: border-box; }
html { scroll-behavior: smooth; }
body {
  margin: 0;
  font-family: var(--rp-font-sans);
  font-size: 14px;
  line-height: 1.68;
  color: var(--rp-ink);
  background: var(--rp-bg-page);
  font-variant-numeric: tabular-nums;
  -webkit-font-smoothing: antialiased;
}

/* Optional Skin: DRAGEN Industrial Card Mode (toggle class `skin-card` on body) */
body.skin-card {
  --rp-bg-page: #F2F4F7;
  --rp-radius: 5px;
}
body.skin-card .rp-navbar {
  background: var(--rp-primary-dark);
  border-bottom-color: #052936;
  color: #fff;
}
body.skin-card .rp-navbar-title,
body.skin-card .rp-navbar-meta-item { color: #fff; }
body.skin-card .rp-navbar-meta-item span { color: rgba(255,255,255,0.72); }
body.skin-card .rp-toc-toggle,
body.skin-card .rp-btn-top {
  background: rgba(255,255,255,0.1);
  color: #fff;
  border-color: rgba(255,255,255,0.24);
}
body.skin-card .rp-module {
  background: #FFFFFF;
  border: 1px solid #D5DCE2;
  border-radius: 5px;
  box-shadow: 0 1px 3px rgba(15, 32, 48, 0.06);
  padding: 24px 28px;
  margin-bottom: 22px;
}

/* 1. Top Command Bar */
.rp-navbar {
  position: fixed; top: 0; left: 0; right: 0;
  height: var(--rp-navbar-h); z-index: 1000;
  background: #FFFFFF; border-bottom: 1px solid var(--rp-line);
  display: flex; align-items: center; justify-content: space-between;
  padding: 0 18px; gap: 12px;
}
.rp-navbar-left, .rp-navbar-actions { display: flex; align-items: center; gap: 10px; }
.rp-brand-tag {
  font-family: var(--rp-font-mono); font-size: 11px; font-weight: 700;
  padding: 2px 7px; background: var(--rp-primary); color: #fff; border-radius: 2px;
}
.rp-navbar-title { font-size: 15px; font-weight: 700; color: var(--rp-ink); }
.rp-qc-pill {
  display: inline-flex; align-items: center; gap: 6px;
  font-size: 12px; font-weight: 600; padding: 4px 10px; border-radius: 2px;
  background: var(--rp-ok-bg); color: var(--rp-ok); border: 1px solid #B7DFC9; cursor: pointer;
}
.rp-qc-dot { width: 7px; height: 7px; border-radius: 50%; background: var(--rp-ok); }
.rp-btn-top {
  font-family: inherit; font-size: 12px; font-weight: 600;
  padding: 5px 11px; border-radius: var(--rp-radius);
  border: 1px solid var(--rp-line); background: #fff; color: var(--rp-ink-mid); cursor: pointer;
}
.rp-btn-top:hover { border-color: var(--rp-primary); color: var(--rp-primary); }

/* 2. Sidebar TOC & Main Container */
.rp-layout { display: flex; padding-top: var(--rp-navbar-h); min-height: 100vh; }
.rp-toc {
  position: fixed; top: var(--rp-navbar-h); bottom: 0; left: 0;
  width: var(--rp-toc-w); background: var(--rp-bg-panel);
  border-right: 1px solid var(--rp-line); overflow-y: auto;
  padding: 16px 12px 36px; transition: transform 0.22s ease;
}
body.toc-collapsed .rp-toc { transform: translateX(-100%); }
.rp-toc-link {
  display: flex; align-items: center; justify-content: space-between;
  padding: 6px 8px; font-size: 12.8px; font-weight: 600; color: var(--rp-ink-mid);
  text-decoration: none; border-left: 3px solid transparent; border-radius: 3px;
}
.rp-toc-link.active {
  background: #FFFFFF; color: var(--rp-primary); border-left-color: var(--rp-primary);
}
.rp-main {
  flex: 1; min-width: 0; margin-left: var(--rp-toc-w);
  padding: 28px 40px 80px; transition: margin-left 0.22s ease;
}
body.toc-collapsed .rp-main { margin-left: 0; }
.rp-container { max-width: 1220px; margin: 0 auto; }

/* 3. Cover & KPI Strip */
.rp-cover {
  border-top: 3px solid var(--rp-primary); border-bottom: 1px solid var(--rp-line);
  padding: 22px 0 20px; margin-bottom: 28px;
}
.rp-meta-grid {
  display: grid; grid-template-columns: repeat(6, 1fr);
  gap: 1px; background: var(--rp-line); border: 1px solid var(--rp-line);
}
.rp-meta-cell { background: #fff; padding: 8px 12px; }
.rp-kpi-strip {
  display: grid; grid-template-columns: repeat(4, 1fr);
  border: 1px solid var(--rp-line); background: var(--rp-line); gap: 1px; margin: 16px 0;
}
.rp-kpi-card { background: #fff; padding: 14px 16px; position: relative; }
.rp-kpi-card::before {
  content: ""; position: absolute; top: 0; left: 0; right: 0; height: 3px; background: var(--rp-primary);
}
.rp-kpi-card.kpi-up::before { background: var(--rp-up); }
.rp-kpi-card.kpi-down::before { background: var(--rp-down); }
.rp-kpi-card.kpi-ok::before { background: var(--rp-ok); }

/* 4. Callouts & Filepath Badge */
.rp-callout {
  border-left: 3px solid var(--rp-primary); background: var(--rp-bg-panel);
  padding: 12px 16px; margin: 14px 0; font-size: 13.5px;
}
.rp-callout-key { border-left-color: var(--rp-ok); background: #F4FAF7; }
.rp-callout-guardrail { border-left-color: #C48A1D; background: #FDF9F0; }
.rp-filepath {
  display: inline-flex; align-items: center; gap: 8px;
  font-family: var(--rp-font-mono); font-size: 11.5px; color: var(--rp-ink-dim);
  background: var(--rp-bg-panel); border: 1px solid var(--rp-line);
  padding: 3px 10px; border-radius: 2px;
}

/* 5. Scientific Data Tables */
.rp-table-wrap { overflow-x: auto; border: 1px solid var(--rp-line); background: #fff; }
.rp-table { width: 100%; border-collapse: collapse; font-size: 12.8px; }
.rp-table thead th {
  background: #F4F7FA; color: var(--rp-ink); font-weight: 600;
  padding: 8px 10px; border-bottom: 2px solid #CBD5E1; text-align: left; white-space: nowrap;
}
.rp-table tbody td { padding: 6.5px 10px; border-bottom: 1px solid var(--rp-line-light); }
.num { text-align: right !important; font-family: var(--rp-font-mono); font-variant-numeric: tabular-nums; }
.val-up { color: var(--rp-up); font-weight: 600; }
.val-down { color: var(--rp-down); font-weight: 600; }


```

## 六、针对“存量流程只产出 PNG 图片、未保存 JSON”的工程落地与转化方案

在实际生产管线中，历史脚本往往直接调用 `ggsave()` 或 `png()` 输出图片而未保留 JSON。为实现平滑演进，建议按以下**三阶段架构**在 `reporter` 工具与 Scale 层面解决：

### 6.1 方案一：在 R 绘图/报告层注入“伴生元数据拦截器（Sidecar Hook）”（零业务脚本侵入）

不需要修改上百个历史分析脚本的计算逻辑，只需在 `reporter` 包收录图片或保存图片的函数中增加一层轻量级包装（Wrapper）：

* **自动关联同目录结果表**：正如 `chip_demo_card.html` 中已经记录了 `Report/ChIP/3.Quality/IP/QCmetrics.csv` 或 `Raw.Reads.txt`，`reporter` 在编译 HTML 时，只要检测到某个图组件绑定了 `.rp-filepath` 中的 `.csv/.tsv/.txt` 路径，立即由 R 读取该表的前 N 行与汇总统计量（均值、极值、显著基因数），自动写入 HTML 顶部的 `<script id="ngs-report-schema" type="application/json">`。

* **ggplot2 / ComplexHeatmap 对象自动脱敏导出**：如果在 R 内部渲染，对 `gg` 对象直接提取 ` layer_data(p)` 或 `p$data` 的汇总分位数，生成同名 `.meta.json` 伴生文件。

### 6.2 方案二：针对“纯 PNG / PDF 图像产物”的自动化结构提取流水线（Scale / Skill 层）

当上游只交付了静态图片目录时，可通过一个前置 Python 预处理 Skill 将图像转化为结构化 JSON：

1. **优先解析同源矢量 PDF / SVG（100% 精确、零大模型成本）**：

   * 生信流程（如 `chip_demo_card.html` 标注的 `*.png|pdf`）通常会同时输出 PNG 和矢量 PDF。使用 Python `pymupdf` (fitz) 或 `pdfplumber` 直接提取 PDF 内的文本块与矩形色块 RGB 值，即可 100% 还原图中所有坐标轴标签、基因名、p 值文本。

2. **规则网格图像的像素色彩逆向矩阵还原（适用于热图 / 相关性矩阵）**：

   * 针对纯 PNG 热图，已知色标映射（如 `-2` 为 `rgb(33,102,172)`、`0` 为 `rgb(247,247,247)`、`+2` 为 `rgb(178,24,43)`），通过 `Pillow` + `NumPy` 定位网格行列中心像素的 `R - B` 通道差值，可在 0.1 秒内逆向还原出完整的 `N 基因 × M 样本` Z-score 数值矩阵（本次为您生成的右侧交互式热图即采用该算法从图 4-1 PNG 中实测提取）。

3. **多模态大模型（VLM）+ JSON Schema 强约束提取（适用于复杂散点图 / 火山图 / 富集图）**：

   * 在自动化解读流水线中，将 `PNG 图像` 连同**固定 JSON Schema 模板**输入多模态模型，禁止模型自由发挥，仅要求其填充：`{"chart_type": "...", "key_outliers": [...], "top_labeled_genes": [...], "pattern_direction": "..."}`，经校验后合入报告 JSON 数据层。

### 6.3 方案三：`reporter` 模板的“自适应双态渲染（Graceful Degradation）”

在 `reporter` 前端模板中，将图表容器设计为自适应模式：

* **状态 A（仅传入 PNG 路径）**：自动将该 PNG 转为高质 WebP（体积缩小 75%+）内嵌至「出版级高清原图画廊（`.rp-gallery-box`）」，自动隐藏单图无意义的左右切换箭头与搜索框，并展示规范图注与全屏灯箱下载。

* **状态 B（同时传入 PNG + 伴生 JSON/TSV 矩阵）**：自动解锁「视图一：交互式动态热图/火山图 + 单基因剖析卡片」与「视图二：出版级静态原图画廊」双 Tab 切换。

## 七、交互式 HTML 报告导出为出版级 PDF 的完整实现方案

生信交互式 HTML 报告包含大量折叠抽屉、多标签切换画廊（Gallery / Slider）、带滚动条的宽表以及单元格背景色（热图色块与差异倍数底色）。如果直接按 `Ctrl + P` 或用普通工具导出，会出现**背景色丢失、滚动表格被截断、隐藏 Tab 图片未打印、固定顶栏遮挡每一页顶部**四大问题。

建议在 `reporter` 中采用「前端 `@media print` 自动展开样式 + 后端 Headless Chromium 无头渲染」的双层闭环方案：

### 7.1 第一层：前端 CSS 打印预处理规范（粘贴至 `reporter-v2.css` 末尾）

```
/* ==========================================================================
   Print & PDF Export Media Rules (@media print)
   Ensures heatmap colors, scrollable tables, hidden gallery slides, and
   collapsed details unfold cleanly into A4 pages.
   ========================================================================== */
@page {
  size: A4 portrait;
  margin: 14mm 12mm 16mm 12mm;
}

@media print {
  /* 1. 强制保留所有热图格、KPI 顶条、表格底色与状态徽章背景色 */
  *, *::before, *::after {
    -webkit-print-color-adjust: exact !important;
    print-color-adjust: exact !important;
  }

  /* 2. 隐藏非打印交互外壳（固定顶栏、左侧目录、搜索框、切换按钮、灯箱） */
  .rp-navbar,
  .rp-toc,
  .rp-toc-toggle,
  .rp-hm-controls,
  .rp-tabs-bar,
  .rp-gallery-arrow,
  .rp-gallery-search,
  .rp-gallery-list,
  .rp-lightbox {
    display: none !important;
  }

  /* 3. 释放主内容区边距与最大宽度，填满 A4 版心 */
  body, body.skin-card {
    background: #FFFFFF !important;
    font-size: 11.5px !important;
  }
  .rp-layout {
    display: block !important;
    padding-top: 0 !important;
  }
  .rp-main {
    margin-left: 0 !important;
    padding: 0 !important;
  }
  .rp-container, .rp-module {
    max-width: none !important;
    box-shadow: none !important;
    border-color: #CBD5E1 !important;
  }

  /* 4. 自动解除所有滚动容器的高度限制，完整打印全部表格行 */
  .rp-table-wrap,
  .rp-hm-scroll {
    max-height: none !important;
    overflow: visible !important;
  }

  /* 5. 自动展开多图画廊（.rp-gallery）中的所有隐藏子图（或按配置仅展开前 N 张） */
  .rp-gallery-main {
    display: block !important;
  }
  .rp-gallery-pane {
    display: block !important;
    page-break-inside: avoid;
    break-inside: avoid;
    margin-bottom: 14px;
  }

  /* 6. 分页防截断控制：防止标题孤行、防止图片与核心小卡片被拦腰截断 */
  h1, h2, h3, .rp-module-header, .rp-subsection {
    page-break-after: avoid;
    break-after: avoid;
  }
  .rp-kpi-strip,
  .rp-callout,
  .rp-fig,
  .rp-gene-inspector,
  tr {
    page-break-inside: avoid;
    break-inside: avoid;
  }
  thead {
    display: table-header-group; /* 跨页长表在每一页顶部自动重复表头 */
  }
}

```

### 7.2 第二层：前端 JS 打印生命周期钩子（`beforeprint` / `afterprint`）

在 `reporter.js` 中加入以下 25 行代码，即可实现当客户点击页面上的「导出 PDF」按钮（或按 `Ctrl/Cmd + P`）时，**自动展开所有 `<details>` 表格解释框与双视图面板，打印完成后自动恢复原状**：

```
(function initPrintHooks() {
  let closedDetails = [];

  function prepareForPDF() {
    // 1. 记录并自动展开所有折叠的 <details> 说明框与 QC 抽屉
    closedDetails = [];
    document.querySelectorAll("details.rp-details:not([open])").forEach(d => {
      closedDetails.push(d);
      d.setAttribute("open", "open");
    });
    const qcDrawer = document.getElementById("drawer-qc");
    if (qcDrawer) qcDrawer.classList.add("open");

    // 2. 重置总表筛选条件，确保 PDF 包含完整基因记录
    if (typeof window.resetMasterTableFilters === "function") {
      window.resetMasterTableFilters();
    }
  }

  function restoreAfterPDF() {
    closedDetails.forEach(d => d.removeAttribute("open"));
    closedDetails = [];
  }

  window.addEventListener("beforeprint", prepareForPDF);
  window.addEventListener("afterprint", restoreAfterPDF);

  // 供顶栏「导出 PDF」按钮直接绑定调用
  window.exportReportToPDF = function() {
    prepareForPDF();
    setTimeout(() => {
      window.print();
    }, 150);
  };
})();

```

### 7.3 第三层：生信服务端（Linux / R / Python）批量自动转 PDF 方案

在生产交付流水线中，推荐同时产出 `report.html`（供交互探索）和 `report.pdf`（供归档、发邮件或审稿附件）：

1. **R 原生方案（直接集成进 `reporter` 包）：`pagedown::chrome_print()`**

   ```
   # 在 reporter::render_report() 结尾追加：
   if (export_pdf) {
     pagedown::chrome_print(
       input = html_output_path,
       output = sub("\\.html$", ".pdf", html_output_path),
       extra_args = c("--no-sandbox", "--disable-gpu"),
       options = list(
         printBackground = TRUE,
         displayHeaderFooter = TRUE,
         headerTemplate = '<div style="font-size:8px;color:#6C7C8C;width:100%;padding:0 12mm;display:flex;justify-content:space-between;"><span>NGS Bioinformatics Analysis Report</span><span class="title"></span></div>',
         footerTemplate = '<div style="font-size:8px;color:#6C7C8C;width:100%;padding:0 12mm;display:flex;justify-content:space-between;"><span>Confidential · For Research Use Only</span><span>Page <span class="pageNumber"></span> of <span class="totalPages"></span></span></div>'
       )
     )
   }
   
   ```

2. **Python 自动化流水线方案：Playwright Headless Chromium (`page.pdf()`)**

   * 在生成 PDF 前，可通过 `page.evaluate("window.prepareForPDF()")` 主动展开需要归档的折叠面板、将动态 Canvas/SVG 图表定格为高分状态，随后调用 `page.pdf(path="report.pdf", format="A4", print_background=True, display_header_footer=True)` 输出出版级矢量 PDF。


## 八、专业级报告顶部（Top Header & Masthead）三大设计范式与代码实现

传统生信报告顶部最容易出现的三大审美缺陷是：**① 双头重复（固定顶栏写一遍标题与项目号，紧接着下方封面又重复写一遍）**、**② 发票格堆砌（用生硬的 6 宫格黑框表格罗列物种与样本数）**、**③ 按钮杂乱无章**。

为彻底解决上述问题，建议在 `reporter` 中提供以下 **三种专业级顶部 UI 范式**（已在交互式 HTML 原型顶栏右侧提供实时切换按钮）：

| 顶部范式名称 | 激活类名 (`body`) | 视觉标杆与适用场景 | 核心设计特征 |
| :--- | :--- | :--- | :--- |
| **范式 A：期刊动态感知型（Editorial Smart-Header，推荐默认）** | `body.header-editorial` | 对标 **Nature / NEJM 在线文献抬头**：适合深度专题分析、转录组/表观组机制研究报告 | **消除双头重复**：位于页面顶端时，顶栏中间仅展示轻量项目面包屑；当向下滚动超过 `130px` 越过主标题后，顶栏中间平滑浮现**「当前章节徽章 + 报告主标题」**及顶部 `2px` 实时阅读进度条；下方抬头采用无外框的**竖向发丝分割元数据横梁（Hairline Metadata Ribbon）** |
| **范式 B：双层仪器控制台型（Instrument Console Header）** | `body.header-console` | 对标 **[10x Genomics Cell Ranger](https://www.10xgenomics.com/support/software/cell-ranger/latest/analysis/outputs/cr-outputs-web-summary-count) / [Illumina DRAGEN](https://help.connected.illumina.com/dragen/dragen-v4.6/product-guides/dragen-v4.6/dragen-reports)**：适合标准流程批量交付、QC 密集型报告 | **零封面直奔主题**：取消独立大封面（节省首屏 45% 垂直空间），采用「深海石板黑（`#0B192C`）工具顶栏 + 浅冷灰（`#F1F5F9`）高密度参数横梁」双层结构，打开页面第一眼直接聚焦第 01 章 KPI 与核心结论 |
| **范式 C：CRO 结题签发档案型（Executive Dossier + QC Stamp）** | `body.header-dossier` | 对标 **第三方临床检验/高端科研 CRO 签发报告单**：适合给医院 PI、药企客户正式结题交付 | **强化质量背书**：抬头采用左右黄金比例（`68% : 32%`）双栏布局，左侧为项目身份与 2×3 实验参数矩阵，右侧内嵌一张带防伪微底纹与绿章的**「独立质控签发印鉴卡（`QUALITY CONTROL PASSED` + Q30/比对率/检出率三项进度条）」** |

### 8.1 顶部滚动感知与范式切换核心 JS 逻辑（合入 `reporter.js`）

```javascript
// 1. 切换三种顶部 UI 范式 (editorial | console | dossier)
window.switchHeaderParadigm = function(mode) {
  document.body.classList.remove("header-editorial", "header-console", "header-dossier");
  document.body.classList.add("header-" + mode);
  ["editorial", "console", "dossier"].forEach(m => {
    const btn = document.getElementById("btn-hdr-" + m);
    if (btn) btn.classList.toggle("active", m === mode);
  });
};

// 2. 滚动感知顶栏：越过主标题 (scrollY > 130px) 时自动切换顶栏中心内容并更新顶部 2px 进度条
window.addEventListener("scroll", () => {
  const scrollTop = window.scrollY;
  const docHeight = Math.max(1, document.documentElement.scrollHeight - window.innerHeight);
  const progEl = document.getElementById("rp-scroll-progress");
  if (progEl) progEl.style.width = Math.min(100, (scrollTop / docHeight) * 100) + "%";

  // 切换 body.is-scrolled 状态，触发顶栏面包屑与当前章节标题的上下平滑过渡
  document.body.classList.toggle("is-scrolled", scrollTop > 130);
}, { passive: true });
```


## 九、定稿版 `66px + 38px` 生产级双层顶栏与 `.rp-carousel` 多图轮播组件模板

根据最终视觉定稿，去除顶栏中所有用于演示切换的冗余按钮，采用**「66px 深海石板主顶栏（品牌 + 标题与元信息 + 全局基因快搜 + 质控/导出工具）+ 38px 实验参数与分组语义次顶栏」**的黄金比例结构，并在正文中内置完整的**平滑滑动多图轮播画廊组件（`.rp-carousel`）**。

### 9.1 定稿版 `66px + 38px` 生产级双层顶栏 HTML 结构

```html
<header class="rp-navbar">
  <!-- 左侧：折叠键 + 品牌标识 + 报告主标题与项目元信息双行排版 -->
  <div class="rp-nav-brand">
    <button class="rp-toc-toggle" id="btn-toc-toggle" type="button">...</button>
    <div class="rp-logo-box">
      <span class="rp-logo-mark"><!-- 公司 SVG Logo --></span>
      <div class="rp-logo-text">
        <span class="rp-logo-name">NGS BIOINFORMATICS</span>
        <span class="rp-logo-sub">OMICS REPORT ENGINE</span>
      </div>
    </div>
    <div class="rp-header-title-block">
      <div class="rp-header-main-title">
        <span>肺纤维化相关基因差异表达靶向分析报告</span>
        <span class="rp-nav-active-sec" id="nav-active-sec-badge">01 · 核心发现与摘要</span>
      </div>
      <div class="rp-header-sub-meta">
        <span>项目编号: <code>SP20260727007</code></span> ·
        <span>小鼠肺组织 mRNA-seq (16 例 · 4 组 × 4 重复)</span> ·
        <span>交付日期: 2026-11-04</span>
      </div>
    </div>
  </div>

  <!-- 右侧：全局基因/模块瞬时检索框 + 质控合格状态签 + 导出 CSV + 导出 PDF -->
  <div class="rp-nav-right">
    <div class="rp-global-search-wrap">
      <input type="text" id="global-gene-search" class="rp-global-search-input"
             placeholder="快速定位基因或模块 (如 Il1b, Col3a1)..." autocomplete="off"/>
      <div class="rp-search-dropdown" id="global-search-dropdown"></div>
    </div>
    <button class="rp-util-btn rp-util-qc" id="btn-qc-drawer" type="button">
      <span class="rp-qc-dot"></span><span>质控基线: 16/16 合格</span>
    </button>
    <button class="rp-util-btn" onclick="exportMasterCSV()" type="button">导出表格 (CSV)</button>
    <button class="rp-util-btn" onclick="window.print()" type="button">导出 PDF</button>
  </div>
</header>
```

### 9.2 多图平滑轮播画廊组件（`.rp-carousel`）HTML 与 JS 模板

该组件融合了 `肺纤维化` 报告的平滑轨道滑动动画（`transform: translateX(-i * 100%)`）与 `chip_demo_card.html` 的样本/图集关键词过滤能力，同时支持键盘 `←` `→` 方向键、移动端触摸滑动、自动轮播开关以及全屏灯箱（Lightbox）高清原图下载，打印或导出 PDF 时自动纵向展开所有子图：

```html
<div class="rp-carousel" id="main-report-carousel" tabindex="0">
  <!-- 1. 轮播顶栏：图号徽章 + 当前图标题 + 计数器 + 关键词过滤 + 自动轮播 + 灯箱与下载 -->
  <div class="rp-carousel-header">
    <div class="rp-carousel-title-wrap">
      <span class="rp-carousel-badge" id="car-fig-badge">Figure 2-1</span>
      <span class="rp-carousel-title" id="car-fig-title">图表标题</span>
      <span class="rp-carousel-counter" id="car-fig-counter">1 / 4</span>
    </div>
    <div class="rp-carousel-tools">
      <input type="text" class="rp-input-search" placeholder="过滤图集 (如 热图 / PCA)..."
             oninput="filterCarouselSlides(this.value)"/>
      <button class="rp-pill" id="btn-car-autoplay" onclick="toggleCarouselAutoplay()" type="button">自动轮播: 关</button>
      <button class="rp-pill" onclick="openLightboxCurrent()" type="button">全屏放大 (Lightbox)</button>
      <a class="rp-pill" id="link-dl-static" href="#" download="Figure.png">下载当前原图</a>
    </div>
  </div>

  <!-- 2. 轮播滑动视口与轨道 -->
  <div class="rp-carousel-viewport">
    <button class="rp-carousel-nav rp-carousel-prev" onclick="stepCarousel(-1)" type="button">‹</button>
    <div class="rp-carousel-track" id="car-track">
      <div class="rp-carousel-slide">
        <img src="data:image/webp;base64,..." alt="Slide 1" onclick="openLightboxCurrent()"/>
        <div class="rp-carousel-caption"><b>图 2-1 标题。</b>详细图注说明文字...</div>
      </div>
      <!-- 更多 .rp-carousel-slide 子项 -->
    </div>
    <button class="rp-carousel-nav rp-carousel-next" onclick="stepCarousel(1)" type="button">›</button>
  </div>

  <!-- 3. 底部快速切换胶囊导航栏 -->
  <div class="rp-carousel-footer">
    <div class="rp-carousel-dots" id="car-dots">
      <button class="rp-carousel-dot active" onclick="goCarouselSlide(0)" type="button">01 · 标准热图</button>
      <button class="rp-carousel-dot" onclick="goCarouselSlide(1)" type="button">02 · 数值版热图</button>
    </div>
  </div>
</div>
```

---

## 十、针对 `BioLaoXu/reporter` 仓库源码的深度架构优化方案（按 R 源码文件逐项拆解）

基于对 [BioLaoXu/reporter](https://github.com/BioLaoXu/reporter) 仓库现有目录结构（`R/layout.R`, `R/tables.R`, `R/tables-lite.R`, `R/primitives.R`, `R/inline.R`, `R/explain.R`, `R/spec.R`, `R/pdf.R` 及 `inst/assets/`）的全面审阅，提出以下 **8 项可直接落地的工程优化建议**：

| 序号 | 对应源码文件 | 现存问题诊断 | 具体优化重构方案 |
| :--- | :--- | :--- | :--- |
| **1** | `R/layout.R` & `R/theme.R` | **封面块（`rp_cover`）与顶栏（`rp_navbar`）信息重复，且缺少“无封面紧凑模式”**：`rp_navbar` 已经展示了 `title`, `project`, `species`, `code`，而 `<main>` 第一块 `rp_cover` 又重复渲染一遍大标题和 KV 表；同时参考基因组等关键参数原本被埋在 `mod-overview` 底部。 | 在 `reporter_theme()` 或 `create_context()` 中新增 `cover_mode = c("first_block", "banner", "none")` 参数。当设为 `"first_block"`（即本次复刻模板默认模式）时，取消冗余的大封面，直接将**「01 · 项目信息、参考基因组与实验样本设计」**作为 `<main class="rp-content">` 的第一个标准 `.rp-module` 块渲染；顶栏右侧仅保留公司信息与 `导出 PDF` 按钮。 |
| **2** | `R/tables.R` vs `R/tables-lite.R` | **`Reactable` 依赖丢失风险与包体积膨胀**：在 `chip_demo_card.html` 中，由于 `bslib` / `htmltools` 渲染管道未正确挂载 `htmlwidgets` 依赖，导致 14 个 `Reactable` 表格全部变成 `0px` 空白标签；且 `jQuery + Bootstrap + React + Reactable` 注入了超过 620 KB 的冗余 JS/CSS。 | **将 `R/tables-lite.R` 扶正为默认表格引擎（`default_table_engine = "lite"`）**！在 `tables-lite.R` 中扩展 3 个属性：① 正负向数值自动着色（`val-up` `#B2182B` / `val-down` `#2166AC`）与表内微条形图（`.div-bar`）；② 多列点击排序（支持科学计数法如 `1.18e-16` 正确按浮点数排序）；③ 分类列自动生成下拉筛选框（如按 `M1–M7` 模块过滤）。 |
| **3** | `R/primitives.R` & `inst/assets/reporter.js` | **画廊组件（`.rp-gallery`）单图退化与切换生硬**：① 当 `length(images) == 1` 时，依然渲染左右箭头和 `Search sample...` 输入框，点击无反应；② 多图切换采用简单的 `display: none/block` 跳变，缺乏平滑轨道感；③ 导出 PDF 时隐藏的 `.rp-gallery-pane` 未展开。 | ① 在 `R/primitives.R` 的 `gallery()` 中增加判断：若 `length(images) == 1`，自动降级为带灯箱放大的 `figure_block()`，隐藏左右箭头、搜索框和底部胶囊列表；② 在 `reporter.css` 中将 `.rp-gallery-viewport` 升级为 `display: flex; transition: transform 0.38s cubic-bezier(0.22, 1, 0.36, 1)` 平滑轮播轨道（即本包中的 `.rp-carousel`）；③ 在 `@media print` 下设置 `.rp-gallery-track { display: block !important; transform: none !important; }` 自动展开子图。 |
| **4** | `R/modules.R` & `R/report.R` | **空结果模块直接渲染破损虚线框（`.rp-empty`）**：当某个模块的 `required_dirs` 存在但子分析结果为空（如无显著富集通路或未跑 Motif）时，页面连续渲染多个 `.rp-empty` 虚线框（“相应分析结果为空，请忽略本小节”），甚至直接暴露 R 函数调用提示。 | 在 `R/modules.R` 中引入**“空模块自动静默折叠机制（Auto-Collapse Empty Subsections）”**：当 `ctx$find()` 未找到目标文件时，不要在正文中插入大面积 `.rp-empty` 虚线框，而是将该子小节从主视图隐藏，仅在该章末尾生成一行紧凑的状态说明（如 `<div class="rp-skipped-note">注：本项目中比较组未检出达到阈值 (FDR < 0.05) 的显著富集条目。</div>`）。 |
| **5** | `R/inline.R` | **高分辨率 PNG 直接 Base64 内联导致单文件 HTML 体积暴增，且离线字体 404**：两张 300 DPI 热图 PNG 直接转 Base64 会占掉 2 MB+ 空间；同时 `bslib` 注入的 `@font-face` 含有本地相对路径 `url(fonts/...)`，离线打开报 404。 | ① 在 `R/inline.R` 的图片内联函数中，若检测到系统中安装了 `magick` 或 `webp` R 包（或命令行 `cwebp`），自动将内联 PNG 转换为 `quality = 85, max_width = 1400px` 的 **WebP Base64**（体积立减 75%～80%，画质肉眼无损）；② 移除 `bslib` 外链 Google Font，统一采用本规范第三章的跨平台本地学术字体栈。 |
| **6** | `R/explain.R` & `inst/extdata/TableExplain.xlsx` | **列解释字典大量显示“待更新”且为双层嵌套表格**：当 `TableExplain.xlsx` 中某列尚未填写解释时，页面直接向客户展示 `"待更新"`；且 `<details>` 内部又套了一层复杂的 Reactable 组件。 | ① 在 `R/explain.R` 读取字典时过滤掉 `is.na(explain) | explain == "待更新"` 的行，若整张表均无有效解释则自动隐藏 `<details class="rp-details">` 折叠框，绝不向客户暴露 `"待更新"` 字样；② `<details>` 内部统一使用轻量级 `<table class="rp-table compact">` 渲染。 |
| **7** | `R/context.R` & `R/layout.R` | **内置 `<script id="rp-schema" type="application/json">` 尚未承载业务统计数据**：目前 `layout.R` 已预留了 `id="rp-schema"` 标签，但尚未将各模块的关键 KPI、分组映射字典与核心表达矩阵汇总写入其中。 | 在 `report_context` 中增加 `ctx$register_schema(key, payload)` 方法：当各模块读取 QC 表、模块汇总表和差异基因表时，自动将核心统计量和 Top 基因矩阵注册进 `rp-schema`。这不仅能直接驱动前端的**「交互式热图 + 单基因跨组剖析卡片」**和**「分组语义一键映射」**，还能作为后续接入大模型自动撰写解读的唯一事实数据源（Single Source of Truth）。 |
| **8** | `R/pdf.R` | **PDF 导出缺少前端展开预处理与超长表截断保护**：直接调用无头浏览器打印 HTML 时，未展开的 `<details>` 和滚动条内的表格行会被截断；而若有上千行基因全部展开又会导致 PDF 页数失控。 | 在 `R/pdf.R` 调用无头 Chrome / `pagedown::chrome_print()` 前，注入 `beforeprint` 钩子自动展开质控表与列说明，并对 `.rp-table tbody tr:nth-child(n+31)` 在 `@media print` 下自动隐藏并追加一行表尾提示（“PDF 归档版仅展示前 30 条核心记录，完整交互式数据请查阅同名 HTML 报告”）。 |
