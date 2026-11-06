const { chromium } = require('/data/InHousePackages/reporter/.nodeenv/node_modules/playwright');
const refs = [
  ['tenx', 'https://cf.10xgenomics.com/samples/cell-exp/6.1.0/10k_PBMC_3p_v3/10k_PBMC_3p_v3_web_summary.html'],
  ['multiqc-demo', 'https://multiqc.info/example'],
];
(async () => {
  const browser = await chromium.launch();
  for (const [name, url] of refs) {
    try {
      const page = await browser.newPage({ viewport: { width: 1400, height: 900 } });
      await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 15000 });
      await page.waitForTimeout(4000);
      await page.screenshot({ path: '/tmp/ref-' + name + '.png' });
      await page.close();
      console.log('ok', name, page.url());
    } catch (e) {
      console.log('FAIL', name, String(e).slice(0, 80));
    }
  }
  await browser.close();
})();
