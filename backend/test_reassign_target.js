require('dotenv').config();
async function test() {
  try {
    const ewbNo = '522014329109';
    
    const clientId = process.env.WHITEBOOKS_CLIENT_ID?.trim();
    const clientSecret = process.env.WHITEBOOKS_CLIENT_SECRET?.trim();
    const email = process.env.WHITEBOOKS_EMAIL?.trim();
    
    // Auth as AP
    const username = process.env.WHITEBOOKS_USERNAME?.trim();
    const password = process.env.WHITEBOOKS_PASSWORD?.trim();
    const gstin = process.env.WHITEBOOKS_GSTIN?.trim();

    // Target is BELL
    const targetGstin = process.env.BELL_WHITEBOOKS_GSTIN?.trim();

    const authUrl = `https://api.whitebooks.in/ewaybillapi/v1.03/authenticate?email=${encodeURIComponent(email)}&username=${encodeURIComponent(username)}&password=${encodeURIComponent(password)}`;
    const authResponse = await fetch(authUrl, {
      method: "GET",
      headers: { "Content-Type": "application/json", "client_id": clientId, "client_secret": clientSecret, "gstin": gstin, "ip_address": "127.0.0.1" }
    });
    
    const updUrl = `https://api.whitebooks.in/ewaybillapi/v1.03/ewayapi/updatetransporter?email=${encodeURIComponent(email)}`;
    const response = await fetch(updUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json", "client_id": clientId, "client_secret": clientSecret, "gstin": gstin, "ip_address": "127.0.0.1" },
      body: JSON.stringify({
        ewbNo: parseInt(ewbNo, 10),
        transporterId: targetGstin
      })
    });
    console.log(await response.text());

  } catch(e) { console.error(e); }
}
test();
