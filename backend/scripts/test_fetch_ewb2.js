require('dotenv').config();

async function run() {
  try {
    const email = process.env.WHITEBOOKS_EMAIL?.trim();
    const username = process.env.BELL_WHITEBOOKS_USERNAME?.trim();
    const password = process.env.BELL_WHITEBOOKS_PASSWORD?.trim();
    const gstin = process.env.BELL_WHITEBOOKS_GSTIN?.trim();
    const clientId = process.env.WHITEBOOKS_CLIENT_ID?.trim();
    const clientSecret = process.env.WHITEBOOKS_CLIENT_SECRET?.trim();

    const authUrl = `https://api.whitebooks.in/ewaybillapi/v1.03/authenticate?email=${encodeURIComponent(email)}&username=${encodeURIComponent(username)}&password=${encodeURIComponent(password)}`;
    
    const authResponse = await fetch(authUrl, {
      method: "GET",
      headers: { "Content-Type": "application/json", "client_id": clientId, "client_secret": clientSecret, "gstin": gstin, "ip_address": "127.0.0.1" }
    });
    
    const authData = await authResponse.json();
    if (!authResponse.ok || authData.status_cd === "0") {
       throw new Error(`Auth Failed`);
    }

    const token = authData.authtoken || authData.data?.authtoken || authData.AuthToken || '';
    
    const ewaybillno = "502012969563"; // Eway bill provided by user
    const ewbUrl = `https://api.whitebooks.in/ewaybillapi/v1.03/ewayapi/getewaybill?email=${encodeURIComponent(email)}&ewbNo=${ewaybillno}`;
    
    const response = await fetch(ewbUrl, {
      method: "GET",
      headers: { 
        "Content-Type": "application/json", 
        "client_id": clientId, 
        "client_secret": clientSecret, 
        "gstin": gstin, 
        "ip_address": "127.0.0.1",
        "AuthToken": token
      }
    });

    const data = await response.json();
    console.log(JSON.stringify(data, null, 2));

  } catch (err) {
    console.error("Error:", err);
  }
}

run();
