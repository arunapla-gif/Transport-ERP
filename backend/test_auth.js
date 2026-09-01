require('dotenv').config();

async function test() {
  try {
    const clientId = process.env.WHITEBOOKS_CLIENT_ID?.trim();
    const clientSecret = process.env.WHITEBOOKS_CLIENT_SECRET?.trim();
    const username = process.env.WHITEBOOKS_USERNAME?.trim(); 
    const password = process.env.WHITEBOOKS_PASSWORD?.trim(); 
    const gstin = process.env.WHITEBOOKS_GSTIN?.trim() || process.env.TRANSPORTER_GSTIN?.trim();
    const email = process.env.WHITEBOOKS_EMAIL?.trim();

    if (!clientId) {
       console.log("No credentials found");
       return;
    }

    // With OAuth 2.0 Client Credentials, /authenticate is deprecated.
    // Testing direct EWB fetch instead.
    const ewaybillno = "552028120315";
    const ewbUrl = `https://api.whitebooks.in/ewaybillapi/v1.03/ewayapi/getewaybill?email=${encodeURIComponent(email)}&ewbNo=${ewaybillno}`;
    
    const ewbResponse = await fetch(ewbUrl, {
      method: "GET",
      headers: {
        "Content-Type": "application/json",
        "client_id": clientId,
        "client_secret": clientSecret,
        "gstin": gstin,
        "ip_address": "127.0.0.1"
      }
    });
    
    const ewbData = await ewbResponse.json();
    console.log(JSON.stringify(ewbData, null, 2));
  } catch (e) {
    console.error(e);
  }
}
test();
