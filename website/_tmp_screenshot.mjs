
const { chromium } = require('@playwright/test');
(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();
  await page.setViewportSize({ width: 1280, height: 800 });
  // Navigate but don't wait for load — just network idle is fine for SSR overlay
  page.goto('http://localhost:3000').catch(() => {});
  // Wait just 300ms — before the 600ms auto-dismiss fires
  await new Promise(r => setTimeout(r, 300));
  await page.screenshot({ path: 'loading-spinner.png' });
  await browser.close();
  console.log('done');
})();
