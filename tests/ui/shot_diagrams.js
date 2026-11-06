const { chromium } = require('/data/InHousePackages/reporter/.nodeenv/node_modules/playwright');
(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1280, height: 760 } });
  for (const n of ['reporter-architecture', 'reporter-dataflow']) {
    await page.goto('file:///data/InHousePackages/reporter/docs/' + n + '.html');
    await page.waitForTimeout(600);
    await page.screenshot({ path: '/data/InHousePackages/reporter/docs/' + n + '.preview.png', fullPage: false });
  }
  await browser.close();
  console.log('ok');
})();
