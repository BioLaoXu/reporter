const { chromium } = require('/data/InHousePackages/reporter/.nodeenv/node_modules/playwright');
(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
  await page.goto('file:///data/InHousePackages/reporter/examples/chip_demo_v2.html',
    { waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(1200);
  await page.locator('#mod-qc').scrollIntoViewIfNeeded();
  await page.waitForTimeout(500);
  await page.screenshot({ path: '/tmp/cmp-v2-qc-kpi.png' });
  await browser.close();
  console.log('ok');
})();
