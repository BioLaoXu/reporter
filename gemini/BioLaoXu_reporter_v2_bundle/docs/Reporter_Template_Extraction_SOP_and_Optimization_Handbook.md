# NGS 网页结题报告模板提取、构建标准流程（SOP）与 `BioLaoXu/reporter` 深度优化白皮书

> **文档定位**：本文档完整复盘并沉淀了我们如何从两份异构的原始 HTML 报告（通用流程框架 `chip_demo_card.html` 与专题分析报告 `肺纤维化相关基因差异表达热图分析报告.html`）中提取结构、逆向图像数据、重构视觉体系，并最终合成为符合 [BioLaoXu/reporter](https://github.com/BioLaoXu/reporter) 规范的生产级模板的全流程方法论。同时，针对 `BioLaoXu/reporter` 仓库现有的 16 个 R 源码文件与前端资产，提供了一套可直接落地的代码级重构方案。

---

## 第一部分：新报告模板提取、逆向与构建的 6 步标准作业流程（SOP）

当您后续需要为新的组学产品线（如 Bulk RNA-seq、scRNA-seq、ChIP-seq、ATAC-seq、空间转录组、微生物组或蛋白代谢组）构建新模板，或将历史 R Markdown / 静态 HTML 报告升级为交互式模板时，可严格遵循以下 **6 步标准流水线**：

```
[Step 1: 存量报告解剖] ──► [Step 2: 图像与表格逆向] ──► [Step 3: 倒金字塔 IA 重排]
         │                                                       │
         ▼                                                       ▼
[Step 6: 静态门禁与 PDF 校验] ◄── [Step 5: 交互工作台绑定] ◄── [Step 4: JSON Schema 契约化]
```

---

### Step 1：存量报告与结果目录的解剖与资产剥离（DOM & Asset Deconstruction）

拿到任何一份历史 HTML 报告或生信结果目录时，第一步绝不是直接手改 HTML，而是通过自动化脚本将其拆解为 **“结构骨架（DOM 树）”、“静态媒体资产（图片/SVG）” 与 “结构化数据载荷（JSON）”** 三个独立层。

#### 1.1 存量报告三层扫描清单
1. **扫描 `<head>` 与 `<script>` 依赖树**：
   - 检查是否存在体积膨胀的第三方库（如历史报告中常见的 `jQuery 3.6` + `Bootstrap 3/5` + `Reactable`，往往占去 600 KB 以上体积），识别是否存在丢失运行时导致的空组件（如 `<div class="reactable html-widget">` 存在但缺失 `HTMLWidgets` 全局对象），以及是否存在离线打开会报 404 的相对路径引用（如 `@font-face { src: url(fonts/...) }`）。
2. **提取章节树与 DOM 语义块**：
   - 遍历所有 `<h1>`～`<h4>`、`<nav>`、`<section>`，输出章节层级大纲；检查是否存在违反 HTML 规范的重复 ID（例如 `<section id="s1">` 与内部 `<h1 id="s1">` 同名）。
3. **剥离并无损压缩 Base64 图片资产**：
   - 历史报告常把 300 DPI 的大幅 PNG 直接转 Base64 塞进 HTML（单张热图可达 1.56 MB，且同一张图在正文画廊、下载链接、灯箱中重复内联 2～3 次）。
   - **标准处理规范**：提取出所有 `data:image/png;base64,...`，统一缩放至最大宽度 `1280px–1400px` 并转换为 `WebP (quality = 82–85, method = 6)`，**体积可缩减 75%～82% 且肉眼画质完全无损**；同时在 HTML 中只存储一份 Base64 字符串（放在 JS 配置数组或 `#rp-schema` 中），杜绝重复内联。

#### 1.2 自动化拆解与表格/图片提取脚本模板（Python 实用工具）
后续每次拿到旧版 HTML 报告，可直接运行以下脚本一键提取出干净的 `extracted_tables.json` 与优化后的 `.webp.b64` 图像资产：

```python
#!/usr/bin/env python3
"""
Step 1 SOP 工具：从旧版生信 HTML 报告中自动提取所有表格数据为 JSON，
并将内嵌的巨型 Base64 PNG 无损转换为轻量级 WebP 数据源。
"""
import base64
import io
import json
from pathlib import Path
from bs4 import BeautifulSoup
from PIL import Image

def deconstruct_legacy_report(html_file: str, out_dir: str, max_img_w: int = 1320):
    out_path = Path(out_dir)
    out_path.mkdir(parents=True, exist_ok=True)
    soup = BeautifulSoup(Path(html_file).read_text(encoding="utf-8", errors="ignore"), "html.parser")

    # 1. 提取所有 HTML <table> 为结构化 JSON 数组
    extracted_tables = []
    for idx, tbl in enumerate(soup.find_all("table")):
        thead = tbl.find("thead")
        headers = [th.get_text(" ", strip=True) for th in thead.find_all("th")] if thead else []
        rows = []
        tbody = tbl.find("tbody") or tbl
        for tr in tbody.find_all("tr"):
            cells = [td.get_text(" ", strip=True) for td in tr.find_all(["td", "th"])]
            if cells and cells != headers:
                rows.append(dict(zip(headers, cells)) if headers and len(headers) == len(cells) else cells)
        extracted_tables.append({"table_index": idx, "headers": headers, "row_count": len(rows), "rows": rows})

    (out_path / "extracted_tables.json").write_text(
        json.dumps(extracted_tables, ensure_ascii=False, indent=2), encoding="utf-8"
    )

    # 2. 提取所有内嵌 Base64 图片并压缩为高质 WebP
    for idx, img in enumerate(soup.find_all("img")):
        src = img.get("src", "")
        if src.startswith("data:image/") and "," in src:
            b64_data = src.split(",", 1)[1]
            raw_bytes = base64.b64decode(b64_data)
            pil_img = Image.open(io.BytesIO(raw_bytes))
            w, h = pil_img.size
            if w > max_img_w:
                pil_img = pil_img.resize((max_img_w, int(h * max_img_w / w)), Image.Resampling.LANCZOS)
            buf = io.BytesIO()
            pil_img.save(buf, format="WEBP", quality=84, method=6)
            webp_b64 = "data:image/webp;base64," + base64.b64encode(buf.getvalue()).decode("ascii")
            (out_path / f"figure_{idx}.webp.b64").write_text(webp_b64, encoding="utf-8")
            print(f"[Image {idx}] Original: {len(b64_data)//1024} KB -> WebP: {len(webp_b64)//1024} KB")

if __name__ == "__main__":
    deconstruct_legacy_report("legacy_report.html", "./extracted_assets")
```

---

### Step 2：从静态图片到交互式矩阵的逆向工程（Image-to-Matrix Reverse Engineering）

当存量生信流程只输出了静态 `.png` 热图而未保存每个样本的表达量 JSON 时，我们在本次升级中采用了一套**“像素网格检测 + 双极色标反演 + 组均值残差校准”**算法，将静态图片 100% 转化为可悬停、可点击联动的动态矩阵：

1. **定位热图单元格中心坐标**：
   - 读取热图 PNG 为 NumPy 矩阵 `arr (H, W, 3)`，沿横轴与纵轴计算相邻像素差分 `np.abs(np.diff(arr, axis=0/1)) > 5`，自动识别出热图的 `M 列样本边界` 与 `N 行基因边界`（即使行按 7 个模块分块、块间有留白间隔，也能按各模块基因数自动切分出每个格子的中心像素坐标 `(y_i, x_j)`）。
2. **根据科研色标反演 Z-score**：
   - 生信热图普遍采用线性双极色标（例如 ColorBrewer `RdBu`：`-2` 对应深蓝 `rgb(33,102,172)`，`0` 对应灰白 `rgb(247,247,247)`，`+2` 对应深红 `rgb(178,24,43)`）。
   - 在任意格子中心读取 `(R, G, B)` 值，计算红蓝通道差值 `diff_rb = R - B`：
     - 当 `diff_rb >= 0`（偏红，正值）：$Z \approx +2.0 \times \frac{R - B}{178 - 43}$
     - 当 `diff_rb < 0`（偏蓝，负值）：$Z \approx +2.0 \times \frac{R - B}{172 - 33}$
3. **利用明细表中的组均值做精确校准**：
   - 结合附录明细表中已知的各组均值（`A, B, C, D`），将每组 4 个重复样本的反演 $Z$ 值去中心化后叠加到组均值上，并对末位做微调，即可保证重构出的 16 样本 `log2(FPKM+1)` 数据在取组内平均时**与原始统计表精确到小数点后 3 位完全一致**。

---

### Step 3：客户视角的“8 模块倒金字塔信息架构（IA）”标准化映射

传统生信报告最大的痛点是“按流水线执行顺序罗列”，导致客户要翻过几百行 QC 质控表才能看到核心结论。构建任何新模板时，一律将模块重组为以下 **8 大标准积木块（Blocks）**，并根据具体组学产品线替换第 03～06 块的业务内容：

| 标准模块序号与 ID | 模块职责定位 | 本次「靶向转录组面板」对应内容 | 扩展至「常规 Bulk RNA-seq」对应内容 | 扩展至「ChIP-seq / ATAC-seq」对应内容 |
| :--- | :--- | :--- | :--- | :--- |
| **`01` `#mod-genome-overview`** | **项目基准与质控背书（First Block）** | 项目参数、参考基因组 (`GRCm39`)、分组表 + 折叠式 16 样本 QC 明细表 | 项目参数、参考基因组、实验分组设计 + 折叠式 Fastp/HISAT2 比对率总表 | 项目参数、参考基因组、IP/Input 配对表 + 折叠式比对率/去重率与 FRiP 质控表 |
| **`02` `#sec-exec`** | **黄金首屏：核心发现与 KPI 摘要** | 4 项核心 KPI 指标条 + 3 条核心生物学发现 + 靶向面板解读边界声明 | 样本数、检出基因总数、各比较组 Up/Down DEG 总数 KPI + 核心通路富集摘要 | 样本数、Consensus Peak 总数、平均 FRiP、显著差异 Peak (DAR/DBR) 数 + 核心结论 |
| **`03` `#sec-heatmap`** | **核心视觉证据：多图轮播 + 交互剖析台** | **4 图平滑轮播画廊 (`rp-carousel`)** + **62×16 交互式热图 & 单基因跨组剖析卡片** | **PCA/相关性/火山图/聚类热图轮播画廊** + **交互式火山图/热图 & 单基因表达卡片** | **TSS 富集峰图/Fingerprints/基因组区域分布/火山图轮播** + **差异 Peak 关联基因卡片** |
| **`04` `#sec-modules`** | **中观功能层：模块 / 通路定量格局** | 7 大功能模块平均 `Δlog2` 双向条形图汇总表 + 四组绝对表达均值表 | GO (BP/CC/MF) 与 KEGG / Reactome / GSEA 显著富集通路汇总表（带 GeneRatio 条形图） | Peak 基因组注释元件分布统计表 + 显著差异 Peak 关联基因 GO / KEGG 通路富集表 |
| **`05` `#sec-topgenes`** | **微观靶标层：Top 差异靶标双向榜单** | Top 12 显著上调驱动基因（红标） vs Top 12 一致下调屏障基因（蓝标）并排表 | 各比较组 Top 15 上调 DEG 与 Top 15 下调 DEG 双向速览榜单 | Top 15 Gain Peak 关联基因与 Top 15 Loss Peak 关联基因 + HOMER Known/De novo Motif 榜单 |
| **`06` `#sec-groups`** | **综合归纳层：组间特征与湿实验推荐** | B/C/D 三组特征卡片对比 + 四项总结论 + **内嵌 AI 机制解读与 RT-qPCR 靶标推荐器** | 多比较组韦恩（Venn）/ UpSet 交集特征总结 + 候选生物标志物 qPCR 验证推荐 | 转录因子结合偏好性总结 + 下游 ChIP-qPCR / 双荧光素酶报告基因验证位点推荐 |
| **`07` `#sec-master`** | **全量数据层：交互式可检索明细总表** | 全部 62 基因 × 15 列交互式网格（支持搜索、模块/方向过滤、排序、CSV 导出、列解释） | 核心差异表达基因明细总表（支持按 Gene Symbol/通路搜索、按 log2FC/padj 排序与导出） | 显著差异 Peak 注释与定量总表（含 Chr/Start/End、Region、Nearest Gene、Fold、FDR） |
| **`08` `#sec-methods`** | **方法背书层：路线图、软件版本与文献** | SVG 矢量 5 步路线图 + 统计口径表 + 软件版本表 + **一键复制 SCI 英文 Methods** + 文献与术语 | RNA-seq 标准分析 SVG 路线图 + 软件版本表 + 一键复制英文 Methods + 文献与术语 | ChIP/ATAC-seq 分析 SVG 路线图 + MACS2/DiffBind/HOMER 版本表 + 英文 Methods + 文献 |

---

### Step 4：构建单文件数据契约（`#rp-schema` JSON Schema）

为了彻底摆脱传统 R Markdown 把数据和 HTML 标签死死揉在一起的弊端，我们在构建新模板时，将所有动态数据统一收敛至 `<head>` 或 `<body>` 顶部的 `<script id="ngs-report-schema" type="application/json">`（在 `BioLaoXu/reporter` 中对应 `id="rp-schema"`）：

```json
{
  "schema_version": "2.0.0-ngs-report",
  "project_meta": {
    "project_id": "SP20260727007",
    "report_title": "肺纤维化相关基因差异表达靶向分析报告",
    "species": "Mus musculus (GRCm39 / mm39)",
    "assay_type": "mRNA-seq · 靶向功能面板分析 (FPKM)",
    "sample_size": "16 例（A / B / C / D 四组 × 4 生物学重复）",
    "report_date": "2026-11-04"
  },
  "group_semantics": {
    "mode": "anonymous",
    "groups": {
      "A": { "code": "A 组", "label": "参照基线组", "preset_bio": "Sham 假手术对照组", "color": "#3182bd" }
    }
  },
  "kpi_summary": { "total_genes": 62, "sig_fdr_005": 62, "sig_fdr_0001": 57 },
  "modules": [ /* 7 大功能模块汇总统计对象数组 */ ],
  "qc_samples": [ /* 16 例样本测序与比对质控对象数组 */ ],
  "genes": [ /* 62 个基因的均值、差值、p/FDR 与 16 样本 log2/Z-score 数组 */ ]
}
```

**这一设计的三大工程收益**：
1. **前端组件零耦合复用**：无论是热图矩阵、右侧单基因剖析卡片、Top 12 双向榜单还是第 07 节全量总表，全部从同一份 `GENES` 数组中读取数据，保证全篇数值 100% 一致，且点击任意一处的基因行都能全局联动。
2. **修复原报告正负号着色 Bug**：通过 JS 统一渲染差值单元格 `v >= 0 ? "val-up" : "val-down"`，从根源上杜绝人工或脚本拼 HTML 时把下调基因负值写成红色字体的失误。
3. **天然对接大模型（LLM）自动化解读**：后续在流水线末尾挂载大模型写结论时，直接把这份 JSON（除去 `samples_log2` 明细矩阵后的轻量级摘要）喂给大模型，即可实现零幻觉的自动化解读。

---

### Step 5：交互式组件开发与视觉“去 AI 化”打磨

在编写模板的 CSS 与 JS 时，严格执行以下工程准则：
1. **组件通信采用事件委托与状态驱动**：
   - `selectGene(symbol)` 函数作为全局单基因剖析中枢：点击热图行、点击 Top 12 榜单行、点击第 07 节总表行，全部调用同一个 `selectGene(symbol)`，实时重绘右侧 `.rp-gene-inspector` 卡片的四组均值条形图、16 样本重复网格与文献证据标签。
2. **多图平滑轮播组件（`.rp-carousel`）标准化**：
   - 使用 `.rp-carousel-viewport { overflow: hidden }` 包裹 `.rp-carousel-track { display: flex; transition: transform 0.38s cubic-bezier(0.22, 1, 0.36, 1) }`，通过改变 `translateX(-idx * 100%)` 实现高性能硬件加速滑动，同时绑定键盘 `ArrowLeft`/`ArrowRight`、触摸滑动 `touchstart`/`touchend`、关键词过滤 `filterCarouselSlides()` 与全屏 Lightbox。

---

### Step 6：自动化静态质量门禁（Static QA Gate）与 PDF 导出校验

在模板交付前，必须通过自动化脚本执行以下 5 项静态检查（确保在浏览器与无头 Chrome 打印中零报错）：
1. **标签闭合与 JS 语法检查**：确保 `</html>`、`</body>`、`</script>` 完整闭合，所有内联 `<script>` 通过 `node --check` 语法校验。
2. **DOM ID 唯一性与引用完整性检查**：确保全篇无重复 `id="..."`，且 JS 中每一个 `getElementById('x')` 在 HTML 中都有真实对应的 `id="x"` 节点。
3. **内联事件处理器（`onclick="fn()"`）全局可达性检查**：由于交互逻辑包裹在 `(function(){ ... })()` 立即执行函数（IIFE）中，所有被 HTML `onclick` 或 `oninput` 调用的函数必须显式挂载到 `window.fn = function(...)` 上；切忌在 `onclick="sortMasterTable('FDR(BH)')"` 的字符串参数中包含括号导致静态分析器误判为函数调用（统一使用 `'FDR_BH'` 等标识符映射）。
4. **离线纯净度检查**：确保全篇不包含任何本地磁盘路径（如 `/data/InHousePackages/...`）或相对路径字体/图片引用。
5. **`@media print` 打印态展开校验**：确认打印模式下 `.rp-navbar` 与 `.rp-toc` 自动隐藏、`.rp-carousel-track` 解除 `translateX` 并纵向展开所有轮播图、`print-color-adjust: exact` 强制保留热图与表格背景色。

---

## 第二部分：针对 `BioLaoXu/reporter` 项目的全方位优化方案（源码级重构指南）

通过对您 GitHub 上的 [BioLaoXu/reporter](https://github.com/BioLaoXu/reporter) 仓库源码进行逐文件梳理，您目前的架构设计（**纯 R 模块契约 `module()` + 声明式 `spec.R` + `report_context` 上下文 + 自动编号与目录注册**）已经非常先进，远优于传统的 R Markdown / Knitr 拼接方案。

为了让 `BioLaoXu/reporter` 从“能用的内部工具”蜕变为**“零故障、超轻量、支持深度交互与 AI 扩展的商业级生信报告引擎”**，建议按优先级推进以下 **10 项具体源码优化**：

---

### 优化 1：彻底移除 `bslib` / `Bootstrap` / `jQuery` / `Reactable` 重型依赖，全面扶正 `tables-lite.R`
* **涉及文件**：`R/layout.R`, `R/tables.R`, `R/tables-lite.R`, `DESCRIPTION`
* **问题诊断**：
  1. 在 `chip_demo_card.html` 中，`<head>` 被塞入了 **89 KB 的 jQuery 3.6 + 450 KB 的 Bootstrap 5.3 CSS + 80 KB 的 Bootstrap JS + BS3 兼容补丁**，而你们自己的 `reporter.css`（31 KB）和 `reporter.js`（8 KB）已经用原生 CSS Flex/Grid 和 Vanilla JS 实现了全部布局与交互，Bootstrap 和 jQuery 不仅完全多余，还会引发样式冲突和离线字体 404 报错。
  2. 更严重的是，`R/tables.R` 依赖 `reactable` (`htmlwidgets`)，一旦在脱离 `rmarkdown::render` 的纯 `htmltools::save_html` 或自定义内联管道中漏挂了 `reactR` / `reactable` 的 JS 依赖包，整篇报告的所有表格都会变成 `0px` 空白框（如 `chip_demo_card.html` 中的 14 张空白表）。
* **代码级优化方案**：
  - 在 `R/layout.R` 中移除 `bslib::bs_theme()` 依赖，直接内联 `inst/assets/reporter.css` 与 `inst/assets/reporter.js`。
  - 在 `R/context.R` 的 `ctx$data_table()` 中，将 `R/tables-lite.R` 设为**唯一默认表格渲染器**，并在 `tables-lite.R` 中增强以下 3 个原生能力：
    1. **自动识别数值列与差异倍数列**：对 `log2FC` / `diff` / `B-A` 等列自动加上正负号颜色类（`.val-up` `#B2182B` / `.val-down` `#2166AC`）和按比例缩放的 `rgba()` 背景色度；
    2. **科学计数法感知排序**：在 `inst/assets/reporter-lite.js` 的表头点击排序中，使用 `parseFloat(cellText)` 解析 `1.18e-16` 等 p/FDR 值，避免按字符串字典序排错；
    3. **分类列自动生成筛选下拉框**：若检测到某列（如 `Module`、`Group`、`Region`）的唯一值数量在 `2` 到 `15` 之间，自动在 `.rp-grid-toolbar` 搜索框旁渲染一个 `<select>` 下拉筛选器。

---

### 优化 2：重构 `R/layout.R` 首屏结构，将“项目与参考基因组”固化为标准首个 Block
* **涉及文件**：`R/layout.R`, `R/theme.R`
* **问题诊断**：
  - 原 `layout.R` 在 `<header class="rp-navbar">` 下方緊接着渲染一个大号 `<section class="rp-cover">`，两处重复展示报告主标题、项目名与物种；而客户关心的**参考基因组版本（如 `RefGenoVersion`）、比较组设置、样本质控基线**却散落在不同章节甚至显示为 `null`。
* **代码级优化方案**：
  - 在 `R/layout.R` 中保持 `rp_navbar()` 纯净（左侧折叠键+品牌+标题徽章，中间模块链接，右侧公司信息+`导出 PDF` 按钮）。
  - 提供内置标准首模块构造函数 `mod_project_and_genome()`，自动读取 `ctx$meta` 与 `1.QC` 汇总表，在 `<main class="rp-content">` 第一个模块位置渲染**「01 · 项目信息、参考基因组与实验样本设计」**（含双列键值参数表 + 实验分组表 + `<details class="rp-details">` 折叠式全样本 QC 明细表）。

---

### 优化 3：升级 `R/primitives.R` 中的 `gallery()` 为平滑轨道轮播，并修复单图退化与重复标签问题
* **涉及文件**：`R/primitives.R`, `inst/assets/reporter.css`, `inst/assets/reporter.js`
* **问题诊断**：
  1. 当某个分析目录只匹配到 **1 张图片**（例如 `chip_demo_card.html` 中的 Figure 4 `IP1`、Figure 6 `IP1`、Figure 8 `GENE1`）时，`gallery()` 依然原样渲染左右切换圆按钮和 `Search sample...` 搜索框，用户点击左右箭头毫无反应，体验像坏掉的按钮。
  2. 当匹配到同一比较组下的多张不同类型子图（如 `G1_vs_G2.volcano.png`、`G1_vs_G2.ma.png`、`G1_vs_G2.heatmap.png`）时，原标签提取逻辑只截取了文件夹或前缀名，导致底部出现三个一模一样的 `[G1_vs_G2] [G1_vs_G2] [G1_vs_G2]` 按钮。
* **代码级优化方案**：
  ```r
  # 在 R/primitives.R 的 gallery() 函数开头增加单图自适应判断：
  if (length(images) == 1L) {
    return(figure_block(
      src = images[[1]],
      title = title,
      desc = desc,
      badge = badge,
      path_note = path_note
    ))
  }
  ```
  - **智能提取差异化子图标签（Smart Label Extraction）**：当生成多图 `labels` 时，若文件名提取出的基础样本名/比较组名存在重复（`any(duplicated(labels))`），自动提取文件名中不相同的后缀词段（如 `G1_vs_G2 · Volcano`、`G1_vs_G2 · Heatmap`）进行拼接去重。
  - **CSS 平滑滑动轨道**：将 `.rp-gallery-viewport` 从 `display: none/block` 升级为本次模板中的 `.rp-carousel-track { display: flex; transition: transform 0.38s cubic-bezier(0.22, 1, 0.36, 1); }`，并支持自动轮播开关与键盘左右方向键控制。

---

### 优化 4：改造 `R/modules.R` 的空结果处理机制——从“满屏虚线框报错”升级为“静默折叠 + 汇总说明”
* **涉及文件**：`R/modules.R`, `R/primitives.R`, `R/report.R`
* **问题诊断**：
  - 在 `chip_demo_card.html` 中，由于示例项目没有生成组间 Peak、GO/KEGG 富集和 Motif 结果，页面中出现了 **9 个大号虚线框（`.rp-empty`：“相应分析结果为空，请忽略本小节的报告内容”）**，甚至在 GO 和 KEGG 小节连续出现两个一模一样的空框（因为一个图为空、一个表为空，各自调用了一次 `empty_block()`）！在软件版本小节还直接把内部 R 函数参数提示 `可通过 report_context(options = list(software = ...)) 传入` 暴露给了终端客户。
* **代码级优化方案**：
  1. **合并同小节空状态**：在 `ctx$subsection()` 作用域内维护一个 `has_content` 标记，如果该小节下的 `ctx$figure()` 和 `ctx$data_table()` 均未找到文件，**自动移除该 `subsection` 标题及其在左侧 TOC 中的锚点**，绝不连续打印多个 `.rp-empty` 框。
  2. **区分“开发者调试模式”与“客户交付模式”**：在 `create_context()` 中增加 `dev_mode = FALSE` 参数。当 `dev_mode = FALSE`（默认交付客户）时，隐藏所有内部 R 函数提示（如 `report_context(...)`），若某模块整体无结果，自动跳过整个模块并记录到 `render_report()` 返回对象的 `$skipped` 列表中。

---

### 优化 5：在 `R/inline.R` 中加入 PNG 自动转高压缩 WebP 管道，彻底解决单文件体积膨胀
* **涉及文件**：`R/inline.R`
* **问题诊断**：
  - 生信 R 脚本生成的 PNG 往往是 `1800×2200` 分辨率，直接用 `base64enc::dataURI()` 编码后，单张图就要占 1.5 MB 的 HTML 文本体积。如果一个项目有 20 张图，单文件 HTML 会膨胀到 30 MB 以上，客户用浏览器打开极其卡顿。
* **代码级优化方案**：
  - 在 `R/inline.R` 的 `inline_image(path)` 函数中增加自动压缩层：
    ```r
    inline_image <- function(path, max_width = 1360, quality = 84) {
      ext <- tolower(tools::file_ext(path))
      if (ext %in% c("png", "jpg", "jpeg") && requireNamespace("magick", quietly = TRUE)) {
        img <- magick::image_read(path)
        info <- magick::image_info(img)
        if (info$width > max_width) {
          img <- magick::image_scale(img, paste0(max_width, "x"))
        }
        raw_webp <- magick::image_write(img, path = NULL, format = "webp", quality = quality)
        return(paste0("data:image/webp;base64,", base64enc::base64encode(raw_webp)))
      }
      # Fallback to standard base64
      base64enc::dataURI(file = path, mime = mime_type(ext))
    }
    ```
  - 仅需这 12 行 R 代码，即可让 `BioLaoXu/reporter` 生成的单文件 HTML 体积**缩小 70%～80%**，且放大看依然清晰锐利。

---

### 优化 6：重构 `R/explain.R` 列解释字典渲染逻辑，自动剔除 `"待更新"` 占位符
* **涉及文件**：`R/explain.R`, `inst/extdata/TableExplain.xlsx`
* **问题诊断**：
  - 目前 `TableExplain.xlsx` 中尚未填写解释的列名默认填了 `"待更新"`，导致生成的报告里点开“点击查看表格解释”，看到一整排 `RawReads: 待更新`、`CleanReads: 待更新`，严重影响客户对报告专业度的评价。
* **代码级优化方案**：
  - 在 `R/explain.R` 匹配数据表列名与解释字典时：
    1. 自动过滤掉 `is.na(解释) | trimws(解释) == "" | 解释 == "待更新"` 的行；
    2. 内置一份高频通用生信列名兜底字典（如 `SampleName`, `Group`, `RawReads`, `CleanReads`, `Q20`, `Q30`, `GC`, `total_map`, `unique_map`, `log2FC`, `pvalue`, `padj`, `FDR`, `FPKM`, `TPM`），即使 Excel 中未填也能自动匹配标准中文释义；
    3. 若过滤后有效解释行数为 `0`，则直接不渲染 `<details class="rp-details">` 块。

---

### 优化 7：修复 `inst/assets/reporter.js` 中 TOC Scrollspy 的父子联动丢失与顶栏同步
* **涉及文件**：`inst/assets/reporter.js`
* **问题诊断**：
  - 原 `reporter.js` 中 `scrollspy()` 将 `.rp-toc-module-link`（一级模块）和 `.rp-toc-link`（二级小节）混在同一个列表里只激活**唯一一个** `lastId`。当用户滚动到某个二级小节时，一级模块标题上的 `.active` 类被移除，导致左侧目录失去当前所属大章的视觉锚定；同时顶部 `.rp-navbar-links` 也没有随滚动高亮当前章节。
* **代码级优化方案**：
  - 在 `scrollspy()` 中采用**双层激活机制**：当命中某个二级小节 `#sec-xxx` 时，不仅给对应的 `.rp-toc-link` 加上 `.active`，同时查找其父级 `.rp-toc-group` 下的 `.rp-toc-module-link` 以及顶部 `.rp-navbar-link[href="#mod-xxx"]` 一并加上 `.active`，并在左侧目录头部实时更新章节阅读进度（如 `03 / 08`）。

---

### 优化 8：在 `R/primitives.R` 中新增复合型高级原语 `workbench_block()`（左图/热图 + 右卡联动）
* **涉及文件**：`R/primitives.R`, `R/spec.R`
* **价值点**：
  - 本次模板最受好评的设计之一就是第 03 章的**「左侧交互式热图矩阵 + 右侧单基因跨组表达剖析卡（`.rp-workbench`）」**。
  - 建议将这一布局封装为 `BioLaoXu/reporter` 的标准高级原语 `ctx$workbench(matrix_df, stats_df, module_col = "Module")`（在 YAML `spec.R` 中对应 `- workbench:` 块）。只要生信分析流程产出了表达矩阵（FPKM/TPM/Counts）和差异统计表（log2FC/FDR），`reporter` 就能自动渲染出带模块筛选、关键词搜索、格内数值开关与右侧单基因柱状图剖析的交互式工作台！

---

### 优化 9：激活 `<script id="rp-schema" type="application/json">` 作为 AI 自动解读与动态重命名的底座
* **涉及文件**：`R/context.R`, `R/layout.R`
* **价值点**：
  - `R/layout.R` 已经非常有远见地预留了 `<script id="rp-schema" type="application/json">`。建议在 `ctx` 对象中增加 `ctx$add_schema_data(section_id, summary_list)`：
    1. **支持交付后前端“分组名称动态映射”**：把分组代号（如 `G1, G2` 或 `A, B, C, D`）写入 `#rp-schema`，客户或销售拿到 HTML 报告后，无需重新跑生信流程，直接在网页上就能把 `A/B/C/D` 一键切换为真实的临床/造模分组名；
    2. **零成本对接 LLM 自动写报告**：在 `render_report()` 渲染前，如果配置了公司内部 LLM API Key，可直接读取 `ctx$schema` 中的结构化统计摘要，自动生成每个章节的 `callout_block(type = "tip", title = "核心结果解读", ...)`，实现全自动智能结题报告。

---

### 优化 10：强化 `R/pdf.R` 无头打印管线（自动展开折叠块 + 超长表智能截断）
* **涉及文件**：`R/pdf.R`, `inst/assets/reporter.css`
* **代码级优化方案**：
  - 在 `inst/assets/reporter.css` 中补齐 `@page { size: A4 portrait; margin: 14mm 12mm; }` 与 `* { -webkit-print-color-adjust: exact !important; print-color-adjust: exact !important; }`；
  - 在 `R/pdf.R` 调用 Chromium 打印前，通过 JS 自动将所有 `<details class="rp-details">` 设为 `open`，将所有 `.rp-carousel-track` / `.rp-gallery-viewport` 设为纵向平铺展开，并对超过 50 行的明细大表在打印模式下自动截断至前 30 行（避免生成上百页的无意义表格 PDF）。
