const puppeteer = require('puppeteer');

(async () => {
  try {
    const browser = await puppeteer.launch({ headless: "new" });
    const page = await browser.newPage();
    
    // Capture console messages
    page.on('console', msg => {
      if (msg.type() === 'error') {
        console.log('BROWSER_ERROR:', msg.text());
      }
    });

    page.on('pageerror', error => {
      console.log('PAGE_ERROR:', error.message);
    });

    console.log("Navigating to http://localhost:5178/new-gc...");
    await page.goto('http://localhost:5178/new-gc', { waitUntil: 'networkidle0', timeout: 10000 });
    
    const content = await page.content();
    console.log("Page loaded. Length:", content.length);
    
    await browser.close();
  } catch (err) {
    console.error("Script failed:", err);
  }
})();
