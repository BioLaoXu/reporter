const { chromium } = require('/data/InHousePackages/reporter/.nodeenv/node_modules/playwright');
(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1180, height: 900 } });
  await page.goto('file:///data/InHousePackages/reporter/docs/reporter-roadmap.html',
    { waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(600);
  await page.screenshot({ path: '/tmp/rp-roadmap-light.png' });
  // toggle to dark theme via the built-in button
  await page.locator('.toolbar button, .toolbar .theme-toggle').first().click().catch(() => {});
  await page.waitForTimeout(400);
  await page.screenshot({ path: '/tmp/rp-roadmap-dark.png' });
  await browser.close();
  console.log('ok');
})();
