const { chromium } = require('/data/InHousePackages/reporter/.nodeenv/node_modules/playwright');
(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
  await page.goto('file:///data/InHousePackages/reporter/examples/chip_demo_v2.html',
    { waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(1500);
  const kpis = await page.evaluate(() =>
    Array.from(document.querySelectorAll('.rp-kpi')).map(el => ({
      value: el.querySelector('.rp-kpi-value')?.textContent.trim(),
      label: el.querySelector('.rp-kpi-label')?.textContent.trim(),
      status: el.className.match(/rp-kpi-(\w+)/)?.[1]
    }))
  );
  console.log(JSON.stringify(kpis, null, 1));
  // scroll the first kpi row into view precisely
  const row = page.locator('.rp-kpi-row').first();
  await row.evaluate(el => window.scrollTo(0, el.getBoundingClientRect().top + window.scrollY - 90));
  await page.waitForTimeout(400);
  await page.screenshot({ path: '/tmp/cmp-v2-qc-kpi.png' });
  await browser.close();
  console.log('ok');
})();
