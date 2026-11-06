/* ==========================================================================
 * reporter.js — interactivity for rendered reports (vanilla JS, no deps)
 * 1. Scrollspy: sidebar TOC link highlighting synced with page scroll
 * 2. Sidebar collapse toggle
 * 3. Gallery: prev/next + sample list switching + search filter
 * 4. Lightbox: fullscreen image view with download
 * ========================================================================== */
(function () {
  "use strict";

  var doc = document;

  /* ------------------------------------------------------------------
   * 1. Scrollspy — highlight the TOC entry of the section in view
   * ------------------------------------------------------------------ */
  function scrollspy() {
    var tocLinks = doc.querySelectorAll(
      ".rp-toc-module-link, .rp-toc-link");
    if (!tocLinks.length) return;

    var map = {}; // id -> toc link element
    var targets = [];
    Array.prototype.forEach.call(tocLinks, function (a) {
      var href = a.getAttribute("href") || "";
      if (href.charAt(0) === "#") {
        var el = doc.getElementById(href.slice(1));
        if (el) {
          map[el.id] = a;
          targets.push(el);
        }
      }
    });
    if (!targets.length) return;

    function setActive(id) {
      Array.prototype.forEach.call(tocLinks, function (a) {
        a.classList.remove("active");
      });
      var navLinks = doc.querySelectorAll(".rp-navbar-link");
      Array.prototype.forEach.call(navLinks, function (a) {
        a.classList.remove("active");
      });
      if (id && map[id]) {
        map[id].classList.add("active");
        /* dual-layer: keep the parent module link (and the navbar entry)
         * highlighted while a subsection is in view */
        var el = doc.getElementById(id);
        var mod = el && el.closest ? el.closest("section[id]") : null;
        var modId = mod ? mod.id : null;
        if (modId) {
          Array.prototype.forEach.call(
            doc.querySelectorAll('.rp-toc a[href="#' + modId + '"]'),
            function (a) { a.classList.add("active"); });
          Array.prototype.forEach.call(
            doc.querySelectorAll('.rp-navbar-link[href="#' + modId + '"]'),
            function (a) { a.classList.add("active"); });
        }
        // expand/scroll the sidebar entry into view
        var link = map[id];
        var toc = doc.getElementById("rp-toc");
        if (toc) {
          var top = link.getBoundingClientRect().top -
            toc.getBoundingClientRect().top;
          if (top < 10 || top > toc.clientHeight - 40) {
            toc.scrollTop = top - toc.clientHeight / 3;
          }
        }
      }
    }

    var lastId = null;
    function currentTarget() {
      var line = window.scrollY + (parseInt(
        getComputedStyle(doc.documentElement)
          .getPropertyValue("--rp-navbar-h"), 10) || 58) + 90;
      var cur = null;
      targets.forEach(function (el) {
        if (el.offsetTop <= line) cur = el;
      });
      return cur;
    }
    function update() {
      var cur = currentTarget();
      var id = cur ? cur.id : null;
      if (id !== lastId) {
        lastId = id;
        setActive(id);
      }
    }
    var ticking = false;
    window.addEventListener("scroll", function () {
      if (!ticking) {
        ticking = true;
        requestAnimationFrame(function () {
          update();
          ticking = false;
        });
      }
    }, { passive: true });
    update();
  }

  /* ------------------------------------------------------------------
   * 2. Sidebar toggle
   * ------------------------------------------------------------------ */
  function sidebarToggle() {
    var btn = doc.querySelector(".rp-toc-toggle");
    if (!btn) return;
    var body = doc.body;
    try {
      if (sessionStorage.getItem("rp-toc-hidden") === "1") {
        body.classList.add("rp-toc-hidden");
      }
    } catch (e) { /* private mode etc. */ }
    btn.addEventListener("click", function () {
      body.classList.toggle("rp-toc-hidden");
      try {
        sessionStorage.setItem("rp-toc-hidden",
          body.classList.contains("rp-toc-hidden") ? "1" : "0");
      } catch (e) { /* ignore */ }
    });
  }

  /* ------------------------------------------------------------------
   * 3. Galleries
   * ------------------------------------------------------------------ */
  function galleries() {
    Array.prototype.forEach.call(
      doc.querySelectorAll(".rp-gallery"), function (gal) {
        var panes = gal.querySelectorAll(".rp-gallery-pane");
        var items = gal.querySelectorAll(".rp-gallery-item");
        if (!panes.length) return;
        var n = panes.length;
        var idx = 0;

        function show(i) {
          idx = (i + n) % n;
          var track = gal.querySelector(".rp-gallery-track");
          if (track) {
            track.style.transform = "translateX(-" + (idx * 100) + "%)";
          }
          Array.prototype.forEach.call(panes, function (p, k) {
            p.classList.toggle("active", k === idx);
          });
          Array.prototype.forEach.call(items, function (it, k) {
            it.classList.toggle("active", k === idx);
          });
        }
        Array.prototype.forEach.call(items, function (it, k) {
          it.addEventListener("click", function () { show(k); });
        });
        Array.prototype.forEach.call(
          gal.querySelectorAll(".rp-gallery-prev"),
          function (b) { b.addEventListener("click", function () { show(idx - 1); }); });
        Array.prototype.forEach.call(
          gal.querySelectorAll(".rp-gallery-next"),
          function (b) { b.addEventListener("click", function () { show(idx + 1); }); });

        var search = gal.querySelector(".rp-gallery-search");
        if (search) {
          search.addEventListener("input", function () {
            var q = search.value.trim().toLowerCase();
            var visible = 0;
            Array.prototype.forEach.call(items, function (it) {
              var hit = !q ||
                (it.textContent || "").toLowerCase().indexOf(q) >= 0;
              it.classList.toggle("hidden-item", !hit);
              if (hit) visible++;
            });
            if (visible && q) {
              var first = gal.querySelector(".rp-gallery-item:not(.hidden-item)");
              if (first) show(Array.prototype.indexOf.call(items, first));
            }
          });
        }
        gal.addEventListener("keydown", function (e) {
          if (e.key === "ArrowLeft") { e.preventDefault(); show(idx - 1); }
          if (e.key === "ArrowRight") { e.preventDefault(); show(idx + 1); }
        });
        gal.tabIndex = 0;
      }
    );
  }

  /* ------------------------------------------------------------------
   * 4. Lightbox
   * ------------------------------------------------------------------ */
  function lightbox() {
    var box = null;

    function close() {
      if (box) { box.remove(); box = null; }
    }
    function open(src, name) {
      close();
      box = doc.createElement("div");
      box.className = "rp-lightbox";

      var img = doc.createElement("img");
      img.src = src;
      img.alt = name || "figure";

      var btnClose = doc.createElement("button");
      btnClose.className = "rp-lightbox-close";
      btnClose.setAttribute("aria-label", "Close");
      btnClose.innerHTML =
        '<svg viewBox="0 0 16 16" class="rp-icon" fill="none" stroke="currentColor" stroke-width="1.8"><line x1="3.5" y1="3.5" x2="12.5" y2="12.5"/><line x1="12.5" y1="3.5" x2="3.5" y2="12.5"/></svg>';
      btnClose.addEventListener("click", close);

      var dl = doc.createElement("a");
      dl.className = "rp-lightbox-download";
      dl.href = src;
      dl.download = (name || "figure")
        .replace(/[\\/:*?"<>|\s]+/g, "_") + ".png";
      dl.innerHTML =
        '<svg viewBox="0 0 16 16" class="rp-icon" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M8 2v8"/><polyline points="4.5 7 8 10.5 11.5 7"/><path d="M2.5 13.5h11"/></svg> Download';

      box.addEventListener("click", function (e) {
        if (e.target === box) close();
      });
      box.appendChild(img);
      box.appendChild(dl);
      box.appendChild(btnClose);
      doc.body.appendChild(box);
      btnClose.focus();
    }

    doc.addEventListener("click", function (e) {
      var img = e.target.closest ? e.target.closest("img.rp-fig-img, img.rp-gallery-img") : null;
      if (!img) return;
      var fig = img.closest(".rp-fig, .rp-gallery-pane");
      var name = fig ? (fig.getAttribute("data-rp-download") ||
        (fig.querySelector(".rp-fig-title, .rp-gallery-label") || {})
          .textContent) : "";
      open(img.src, (name || "").trim().slice(0, 60) || null);
    });
    doc.addEventListener("keydown", function (e) {
      if (e.key === "Escape" && box) close();
    });
  }

  /* ------------------------------------------------------------------ */
  function init() {
    scrollspy();
    sidebarToggle();
    galleries();
    lightbox();
  }

  if (doc.readyState === "loading") {
    doc.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();

/* ------------------------------------------------------------------
 * Print / PDF export hooks (P3, per 报告优化.md §7.2)
 * "导出 PDF" button and Ctrl+P: unfold all collapsed details blocks
 * for printing, restore them afterwards.
 * ------------------------------------------------------------------ */
(function () {
  "use strict";
  var closedDetails = [];

  function prepareForPDF() {
    closedDetails = [];
    document.querySelectorAll("details.rp-details:not([open])")
      .forEach(function (d) {
        closedDetails.push(d);
        d.setAttribute("open", "open");
      });
  }
  function restoreAfterPDF() {
    closedDetails.forEach(function (d) { d.removeAttribute("open"); });
    closedDetails = [];
  }
  window.addEventListener("beforeprint", prepareForPDF);
  window.addEventListener("afterprint", restoreAfterPDF);
  window.exportReportToPDF = function () {
    prepareForPDF();
    setTimeout(function () { window.print(); }, 150);
  };
})();
