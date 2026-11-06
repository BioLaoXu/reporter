/**
 * reporter-workbench.js — interactive heatmap + gene inspector card.
 * Reads the JSON payload embedded by workbench_block() and wires:
 * module chips (row filtering), heatmap row click -> inspector card
 * (group mean bars + replicate strip). Vanilla JS, no deps.
 */
(function () {
  "use strict";
  var PALETTE = ["#377EB8", "#4DAF4A", "#E41A1C", "#984EA3", "#FF7F00",
                 "#00BFC4", "#A65628"];

  function initWorkbench(wb) {
    var dataEl = wb.querySelector("script.rp-workbench-data");
    if (!dataEl) return;
    var d = JSON.parse(dataEl.textContent);
    var rows = wb.querySelectorAll(".rp-wb-row");
    var chips = wb.querySelectorAll(".rp-wb-chip");

    Array.prototype.forEach.call(chips, function (chip) {
      chip.addEventListener("click", function () {
        Array.prototype.forEach.call(chips, function (c) {
          c.classList.remove("active");
        });
        chip.classList.add("active");
        var mod = chip.getAttribute("data-mod");
        Array.prototype.forEach.call(rows, function (r) {
          var show = mod === "__all__" || r.getAttribute("data-module") === mod;
          r.style.display = show ? "" : "none";
        });
      });
    });

    Array.prototype.forEach.call(rows, function (row) {
      row.addEventListener("click", function () {
        Array.prototype.forEach.call(rows, function (r) {
          r.classList.remove("selected");
        });
        row.classList.add("selected");
        fillCard(row.getAttribute("data-gene"));
      });
    });

    function vals(gene) {
      var out = {};
      d.samples.forEach(function (s) {
        out[s] = d.matrix[gene] ? d.matrix[gene][s] : null;
      });
      return out;
    }

    function fillCard(gene) {
      var sym = document.getElementById("wb-symbol");
      var fdrB = document.getElementById("wb-fdr-badge");
      var meanEl = document.getElementById("wb-mean");
      var lfcEl = document.getElementById("wb-lfc");
      var bars = document.getElementById("wb-bars");
      var reps = document.getElementById("wb-reps");
      if (!sym) return;
      var st = null;
      d.stats.forEach(function (s) { if (s.gene === gene) st = s; });
      var mod = d.modules[gene] || "未注释";
      sym.innerHTML = gene;
      if (fdrB) fdrB.textContent = "FDR " + ((st && st.fdr) || "—");
      if (lfcEl) lfcEl.textContent = st && st.lfc != null ? st.lfc : "—";

      var gsum = {}, gcnt = {};
      d.samples.forEach(function (s) {
        var g = d.groups[s], v = vals(gene)[s];
        if (v == null || isNaN(v)) return;
        gsum[g] = (gsum[g] || 0) + v;
        gcnt[g] = (gcnt[g] || 0) + 1;
      });
      var means = d.groupLevels.map(function (g) {
        return { g: g, mean: gcnt[g] ? gsum[g] / gcnt[g] : 0 };
      });
      var maxAbs = Math.max.apply(null, means.map(function (m) {
        return Math.abs(m.mean);
      }).concat([0.001]));
      if (meanEl) {
        meanEl.textContent = means.map(function (m) {
          return m.g + ": " + m.mean.toFixed(2);
        }).join("  ");
      }
      if (bars) {
        bars.innerHTML = means.map(function (m, i) {
          var pct = Math.max(2, Math.round(Math.abs(m.mean) / maxAbs * 100));
          var color = PALETTE[(i - 1 + PALETTE.length) % PALETTE.length];
          var delta = i === 0 ? "" :
            " <span class='rp-wb-delta'>" +
            (m.mean - means[0].mean >= 0 ? "+" : "") +
            (m.mean - means[0].mean).toFixed(2) + "</span>";
          return "<div class='rp-wb-bar-row'>" +
            "<span class='rp-wb-bar-g'>" + m.g + "</span>" +
            "<span class='rp-wb-bar-track'>" +
            "<span class='rp-wb-bar' style='width:" + pct +
            "%;background:" + color + ";'></span></span>" +
            "<span class='rp-wb-bar-v'>" + m.mean.toFixed(2) + delta +
            "</span></div>";
        }).join("");
      }
      if (reps) {
        reps.innerHTML = d.samples.map(function (s) {
          var v = vals(gene)[s];
          return "<div class='rp-wb-rep' title='" + s + "'>" +
            "<span class='rp-wb-rep-s'>" + s + "</span>" +
            "<span class='rp-wb-rep-v'>" +
            (v == null ? "—" : v.toFixed(2)) + "</span></div>";
        }).join("");
      }
    }
  }
  function initAll() {
    document.querySelectorAll(".rp-workbench").forEach(initWorkbench);
  }
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initAll);
  } else {
    initAll();
  }
})();
