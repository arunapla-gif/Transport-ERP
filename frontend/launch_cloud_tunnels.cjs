const localtunnel = require('localtunnel');
const fs = require('fs');
const path = require('path');

(async () => {
  try {
    console.log("Starting backend tunnel on port 5005...");
    const backendTunnel = await localtunnel({ port: 5005 });
    console.log('BACKEND_URL=' + backendTunnel.url);

    console.log("Starting frontend tunnel on port 5173...");
    const frontendTunnel = await localtunnel({ port: 5173 });
    console.log('FRONTEND_URL=' + frontendTunnel.url);

    // Update api.js to point to the backend tunnel temporarily
    const apiPath = path.join(__dirname, 'src', 'api.js');
    let apiContent = fs.readFileSync(apiPath, 'utf8');
    
    // Store original just in case
    if (!apiContent.includes('ORIGINAL_API_BASE')) {
      const originalApiBaseMatch = apiContent.match(/const API_BASE = (.*);/);
      if (originalApiBaseMatch) {
         apiContent = apiContent.replace(originalApiBaseMatch[0], `// ORIGINAL_API_BASE=${originalApiBaseMatch[1]}\nconst API_BASE = '${backendTunnel.url}/api';`);
      }
    } else {
      apiContent = apiContent.replace(/const API_BASE = '.*';/, `const API_BASE = '${backendTunnel.url}/api';`);
    }
    
    fs.writeFileSync(apiPath, apiContent);
    console.log("Updated api.js to use backend tunnel URL.");
    
    console.log("\n==============================================");
    console.log("SUCCESS! Here is your public internet URL:");
    console.log(frontendTunnel.url + "/remote-scanner");
    console.log("==============================================\n");

  } catch (err) {
    console.error("Tunnel failed:", err);
  }
})();
