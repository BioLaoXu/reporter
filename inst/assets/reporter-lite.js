/**
 * reporter-lite.js — dependency-free grid enhancer for the "lite" engine
 * (P1). Provides search, column sort and CSV export for native tables.
 * Total runtime < 5 KB; no jQuery/React/Bootstrap.
 */
(function () {
  "use strict";

  function initGrid(grid) {
    var table = grid.querySelector("table.rp-table");
    if (!table) return;
    var search = grid.querySelector(".rp-grid-search");
    var btn = grid.querySelector(".rp-grid-export");
    var count = grid.querySelector(".rp-grid-count");
    var pageInfo = grid.querySelector(".rp-grid-page-info");
    var prevBtn = grid.querySelector('.rp-grid-page-btn[data-page="prev"]');
    var nextBtn = grid.querySelector('.rp-grid-page-btn[data-page="next"]');
    var rows = Array.prototype.slice.call(table.querySelectorAll("tbody tr"));
    var ths = Array.prototype.slice.call(table.querySelectorAll("thead th"));
    var state = {};
    var pageSize =
      parseInt(grid.getAttribute("data-page-size"), 10) || 10;
    var page = 0;
    var visible = rows.slice();

    function renderPage() {
      var totalPages = Math.max(1, Math.ceil(visible.length / pageSize));
      if (page >= totalPages) page = totalPages - 1;
      if (page < 0) page = 0;
      rows.forEach(function (r) { r.style.display = "none"; });
      visible
        .slice(page * pageSize, page * pageSize + pageSize)
        .forEach(function (r) { r.style.display = ""; });
      if (count) count.textContent = visible.length + " / " + rows.length + " 行";
      if (pageInfo) pageInfo.textContent = (page + 1) + " / " + totalPages;
      if (prevBtn) prevBtn.disabled = page === 0;
      if (nextBtn) nextBtn.disabled = page >= totalPages - 1;
    }

    if (search) {
      search.addEventListener("input", function () {
        var q = this.value.trim().toLowerCase();
        visible = rows.filter(function (r) {
          return !q || r.textContent.toLowerCase().indexOf(q) >= 0;
        });
        page = 0;
        renderPage();
      });
    }
    if (prevBtn) prevBtn.addEventListener("click", function () { page--; renderPage(); });
    if (nextBtn) nextBtn.addEventListener("click", function () { page++; renderPage(); });

    ths.forEach(function (th, ci) {
      th.style.cursor = "pointer";
      th.title = "点击排序";
      th.addEventListener("click", function () {
        var dir = state[ci] === "asc" ? "desc" : "asc";
        state = {};
        state[ci] = dir;
        var tbody = table.querySelector("tbody");
        var sorted = rows.slice().sort(function (a, b) {
          var av = (a.children[ci] || {}).textContent || "";
          var bv = (b.children[ci] || {}).textContent || "";
          av = av.trim(); bv = bv.trim();
          var an = parseFloat(av.replace(/,/g, ""));
          var bn = parseFloat(bv.replace(/,/g, ""));
          if (!isNaN(an) && !isNaN(bn)) return dir === "asc" ? an - bn : bn - an;
          return dir === "asc" ? av.localeCompare(bv, "zh") : bv.localeCompare(av, "zh");
        });
        sorted.forEach(function (r) { tbody.appendChild(r); });
        rows = sorted.slice();
        page = 0;
        renderPage();
        ths.forEach(function (t) { t.classList.remove("rp-sort-asc", "rp-sort-desc"); });
        th.classList.add(dir === "asc" ? "rp-sort-asc" : "rp-sort-desc");
      });
    });

    if (btn) {
      btn.addEventListener("click", function () {
        var lines = [];
        lines.push(ths.map(function (t) {
          return '"' + t.textContent.trim().replace(/"/g, '""') + '"';
        }).join(","));
        visible.forEach(function (r) {
          if (r.style.display === "none") return;
          lines.push(Array.prototype.map.call(r.children, function (td) {
            return '"' + td.textContent.trim().replace(/"/g, '""') + '"';
          }).join(","));
        });
        var blob = new Blob(["\\ufeff" + lines.join("\r\n")],
          { type: "text/csv;charset=utf-8" });
        var a = document.createElement("a");
        a.href = URL.createObjectURL(blob);
        a.download = (grid.getAttribute("data-rp-grid") || "table") + ".csv";
        document.body.appendChild(a);
        a.click();
        a.remove();
      });
    }
    renderPage();
  }

  function initAll() {
    document.querySelectorAll(".rp-grid").forEach(initGrid);
  }
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initAll);
  } else {
    initAll();
  }
})();
