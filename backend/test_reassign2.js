require('dotenv').config();
async function test() {
  try {
    const clientId = process.env.WHITEBOOKS_CLIENT_ID?.trim();
    const clientSecret = process.env.WHITEBOOKS_CLIENT_SECRET?.trim();
    const email = process.env.WHITEBOOKS_EMAIL?.trim();
    
    const username = process.env.BELL_WHITEBOOKS_USERNAME?.trim();
    const password = process.env.BELL_WHITEBOOKS_PASSWORD?.trim();
    const gstin = process.env.BELL_WHITEBOOKS_GSTIN?.trim();
    
    const targetGstin = process.env.WHITEBOOKS_GSTIN?.trim();

    const authUrl = `https://api.whitebooks.in/ewaybillapi/v1.03/authenticate?email=${encodeURIComponent(email)}&username=${encodeURIComponent(username)}&password=${encodeURIComponent(password)}`;
    const authResponse = await fetch(authUrl, {
      method: "GET",
      headers: { "Content-Type": "application/json", "client_id": clientId, "client_secret": clientSecret, "gstin": gstin, "ip_address": "127.0.0.1" }
    });
    
    const updUrl = `https://api.whitebooks.in/ewaybillapi/v1.03/ewayapi/UpdTransporter?email=${encodeURIComponent(email)}`;
    const response = await fetch(updUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json", "client_id": clientId, "client_secret": clientSecret, "gstin": gstin, "ip_address": "127.0.0.1" },
      body: JSON.stringify({
        ewbNo: 123456789012, // Dummy EWB
        transporterId: targetGstin
      })
    });
    console.log("UpdTransporter:", await response.text());

  } catch(e) { console.error(e); }
}
test();
