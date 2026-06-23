require('dotenv').config();
async function test() {
  try {
    const ewbNo = '522014329109';
    
    const clientId = process.env.WHITEBOOKS_CLIENT_ID?.trim();
    const clientSecret = process.env.WHITEBOOKS_CLIENT_SECRET?.trim();
    const email = process.env.WHITEBOOKS_EMAIL?.trim();
    const gstin = process.env.WHITEBOOKS_GSTIN?.trim();

    const ewbUrl = `https://api.whitebooks.in/ewaybillapi/v1.03/ewayapi/getewaybill?email=${encodeURIComponent(email)}&ewbNo=${ewbNo}`;
    const response = await fetch(ewbUrl, {
      method: "GET",
      headers: { "Content-Type": "application/json", "client_id": clientId, "client_secret": clientSecret, "gstin": gstin, "ip_address": "127.0.0.1" }
    });
    
    const root = await response.json();
    const data = root.data || {};
    console.log({
      status: data.status,
      validUpto: data.validUpto,
      vehListDetails: data.vehListDetails
    });

  } catch(e) { console.error(e); }
}
test();
