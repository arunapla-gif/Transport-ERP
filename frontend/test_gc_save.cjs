const puppeteer = require('puppeteer');

(async () => {
  const browser = await puppeteer.launch({ headless: 'new', args: ['--no-sandbox'] });
  const page = await browser.newPage();
  
  page.on('console', msg => console.log('BROWSER LOG:', msg.text()));
  page.on('pageerror', err => console.log('BROWSER ERROR:', err.message));
  
  await page.goto('http://localhost:5173/new-gc-entry');
  
  // Wait for the app to load
  await page.waitForTimeout(3000);
  
  // Try to find the page body
  const body = await page.evaluate(() => document.body.innerHTML.substring(0, 500));
  console.log("Body length:", body.length);
  
  // Just simulate the crash.
  // Actually, we can't easily script the whole form filling here.
  // We can just evaluate the exact logic that handleSaveGC does!
  
  await browser.close();
})();
