const { chromium } = require('/data/InHousePackages/reporter/.nodeenv/node_modules/playwright');
(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
  const shots = [
    ['v1-cover', 'chip_demo_blank.html', 0],
    ['v2-cover', 'chip_demo_v2.html', 0],
    ['v2-kpi', 'chip_demo_v2.html', 900],
    ['v2-fig', 'chip_demo_v2.html', 1900],
  ];
  for (const [name, file, scrollY] of shots) {
    await page.goto('file:///data/InHousePackages/reporter/examples/' + file,
      { waitUntil: 'domcontentloaded' });
    await page.waitForTimeout(1200);
    if (scrollY) {
      await page.evaluate(y => window.scrollTo(0, y), scrollY);
      await page.waitForTimeout(500);
    }
    await page.screenshot({ path: '/tmp/cmp-' + name + '.png' });
    console.log('ok', name);
  }
  await browser.close();
})();
