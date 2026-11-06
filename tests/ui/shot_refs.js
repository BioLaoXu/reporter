const { chromium } = require('/data/InHousePackages/reporter/.nodeenv/node_modules/playwright');
const refs = [
  ['multiqc', 'https://multiqc.info/'],
  ['tenx', 'https://cf.10xgenomics.com/samples/cell-exp/7.0.0/SC3_v3_NextGem_DI_CellMultiplex_hs_1k/SC3_v3_NextGem_DI_CellMultiplex_hs_1k_web_summary.html'],
  ['nfcore', 'https://nf-co.re/rnaseq/3.14.0/results/nf-core-rnaseq-3.14.0-multiqc_SRR5228727_1/'],
];
(async () => {
  const browser = await chromium.launch();
  for (const [name, url] of refs) {
    try {
      const page = await browser.newPage({ viewport: { width: 1400, height: 900 } });
      await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 15000 });
      await page.waitForTimeout(3000);
      await page.screenshot({ path: '/tmp/ref-' + name + '.png' });
      await page.close();
      console.log('ok', name);
    } catch (e) {
      console.log('FAIL', name, String(e).slice(0, 80));
    }
  }
  await browser.close();
})();
