/* UI verification for reporter example reports.
 * Loads the rendered single-file HTML, exercises the interactions and
 * captures screenshots as evidence: navbar, sidebar TOC scroll-sync,
 * cover, reactable tables, gallery, lightbox, brand skins.
 */
const { chromium } = require('/data/InHousePackages/reporter/.nodeenv/node_modules/playwright');
const path = require('path');

const ROOT = '/data/InHousePackages/reporter';
const OUT = path.join(ROOT, 'examples', 'screenshots');
const fs = require('fs');
fs.mkdirSync(OUT, { recursive: true });

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
  const consoleErrors = [];
  page.on('console', m => { if (m.type() === 'error') consoleErrors.push(m.text()); });
  page.on('pageerror', e => consoleErrors.push(String(e)));

  const shot = (name, opts) =>
    page.screenshot(Object.assign({
      path: path.join(OUT, name + '.png'),
      fullPage: false
    }, opts || {}));

  /* ---------- report 1: blank skin, diff groups ---------- */
  await page.goto('file://' + path.join(ROOT, 'examples', 'chip_demo_blank.html'));
  await page.waitForTimeout(800);

  // 1. top of page: navbar + cover
  await shot('01-navbar-cover');

  // 2. navbar & toc assertions
  const hasNavbar = await page.locator('.rp-navbar').count();
  const tocLinks = await page.locator('.rp-toc a').count();
  console.log('navbar elements:', hasNavbar, '| toc links:', tocLinks);

  // 3. scroll to the QC module and check TOC sync-highlight
  await page.locator('#mod-qc').scrollIntoViewIfNeeded();
  await page.waitForTimeout(600);
  const activeToc = await page.locator('.rp-toc-module-link.active, .rp-toc-link.active')
    .evaluateAll(els => els.map(e => e.textContent.trim()));
  console.log('active TOC after scroll:', JSON.stringify(activeToc));
  await shot('02-toc-active-qc');

  // 4. scroll deeper into a subsection (h3) inside peak module
  const subs = page.locator('#mod-peak h3.rp-subsection');
  if (await subs.count()) {
    await subs.first().scrollIntoViewIfNeeded();
    await page.waitForTimeout(600);
    const activeSub = await page.locator('.rp-toc-link.active')
      .evaluateAll(els => els.map(e => e.textContent.trim()));
    console.log('active TOC subsection:', JSON.stringify(activeSub));
    await shot('03-subsection-sync');
  }

  // 5. reactable table interaction (search + sort)
  const tables = await page.locator('.ReactTable').count();
  console.log('reactable tables rendered:', tables);
  if (tables) {
    await page.locator('.ReactTable').first().scrollIntoViewIfNeeded();
    await page.waitForTimeout(400);
    await shot('04-reactable-table');
  }

  // 6. gallery: next/prev and sample switching
  const galleries = await page.locator('.rp-gallery').count();
  console.log('galleries:', galleries);
  if (galleries) {
    const g = page.locator('.rp-gallery').first();
    await g.scrollIntoViewIfNeeded();
    await page.waitForTimeout(300);
    await g.locator('.rp-gallery-next').first().click();
    await page.waitForTimeout(350);
    const pane = await g.locator('.rp-gallery-pane.active .rp-gallery-label')
      .evaluateAll(els => els.map(e => e.textContent.trim()));
    console.log('gallery switched to:', JSON.stringify(pane));
    await shot('05-gallery-switch');
    // search filter
    await g.locator('.rp-gallery-search').fill('IP2');
    await page.waitForTimeout(300);
    await shot('06-gallery-search');
    await g.locator('.rp-gallery-search').fill('');
  }

  // 7. lightbox on a figure
  const figImg = page.locator('img.rp-fig-img').first();
  if (await figImg.count()) {
    await figImg.scrollIntoViewIfNeeded();
    await figImg.click();
    await page.waitForTimeout(400);
    const lb = await page.locator('.rp-lightbox').count();
    console.log('lightbox opened:', lb === 1);
    await shot('07-lightbox');
    await page.keyboard.press('Escape');
    await page.waitForTimeout(200);
  }

  // 8. sidebar collapse toggle
  await page.locator('.rp-toc-toggle').click();
  await page.waitForTimeout(400);
  const hidden = await page.evaluate(() =>
    document.body.classList.contains('rp-toc-hidden'));
  console.log('sidebar collapsed:', hidden);
  await shot('08-sidebar-collapsed');
  await page.locator('.rp-toc-toggle').click();
  await page.waitForTimeout(300);

  /* ---------- report 2: smzy brand skin ---------- */
  await page.goto('file://' + path.join(ROOT, 'examples', 'chip_demo_smzy.html'));
  await page.waitForTimeout(800);
  await shot('09-smzy-brand');

  /* ---------- report 3: single group (diff modules skipped) ---------- */
  await page.goto('file://' + path.join(ROOT, 'examples', 'chip_demo_onegroup.html'));
  await page.waitForTimeout(800);
  const hasDiff = await page.locator('#mod-diffpeak').count();
  console.log('diff module present in onegroup report (expect 0):', hasDiff);
  await shot('10-onegroup');

  console.log('console errors:', consoleErrors.length ? consoleErrors : 'none');
  await browser.close();
  console.log('DONE, screenshots in', OUT);
})().catch(e => { console.error(e); process.exit(1); });
