const localtunnel = require('localtunnel');
const fs = require('fs');

(async () => {
  try {
    const backendTunnel = await localtunnel({ port: 5005 });
    const frontendTunnel = await localtunnel({ port: 5173 });

    console.log('BACKEND_URL=' + backendTunnel.url);
    console.log('FRONTEND_URL=' + frontendTunnel.url);

    // Save URLs to file for reading
    fs.writeFileSync('tunnel_urls.txt', `BACKEND_URL=${backendTunnel.url}\nFRONTEND_URL=${frontendTunnel.url}\n`);

    backendTunnel.on('close', () => console.log('Backend tunnel closed'));
    frontendTunnel.on('close', () => console.log('Frontend tunnel closed'));

  } catch (err) {
    console.error(err);
  }
})();
