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
    var rows = Array.prototype.slice.call(table.querySelectorAll("tbody tr"));
    var ths = Array.prototype.slice.call(table.querySelectorAll("thead th"));
    var state = {};

    function visibleCount() {
      var n = 0;
      rows.forEach(function (r) { if (r.style.display !== "none") n++; });
      return n;
    }
    function updateCount() {
      if (count) count.textContent = visibleCount() + " / " + rows.length + " 行";
    }

    if (search) {
      search.addEventListener("input", function () {
        var q = this.value.trim().toLowerCase();
        rows.forEach(function (r) {
          var hit = !q || r.textContent.toLowerCase().indexOf(q) >= 0;
          r.style.display = hit ? "" : "none";
        });
        updateCount();
      });
    }

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
        rows.forEach(function (r) {
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
    updateCount();
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
