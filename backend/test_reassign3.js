require('dotenv').config();
async function test() {
  try {
    const email = process.env.WHITEBOOKS_EMAIL?.trim();
    const gstin = process.env.BELL_WHITEBOOKS_GSTIN?.trim();
    const clientId = process.env.WHITEBOOKS_CLIENT_ID?.trim();
    const clientSecret = process.env.WHITEBOOKS_CLIENT_SECRET?.trim();
    
    const targetGstin = process.env.WHITEBOOKS_GSTIN?.trim();

    const updUrl = `https://api.whitebooks.in/ewaybillapi/v1.03/ewayapi/updatetransporter?email=${encodeURIComponent(email)}`;
    const response = await fetch(updUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json", "client_id": clientId, "client_secret": clientSecret, "gstin": gstin, "ip_address": "127.0.0.1" },
      body: JSON.stringify({
        ewbNo: 123456789012,
        transId: targetGstin
      })
    });
    console.log("transId:", await response.text());

  } catch(e) { console.error(e); }
}
test();
