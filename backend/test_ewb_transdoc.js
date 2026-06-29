require('dotenv').config();
process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

async function testGenerate() {
  try {
    const clientId = process.env.WHITEBOOKS_CLIENT_ID;
    const clientSecret = process.env.WHITEBOOKS_CLIENT_SECRET;
    const email = process.env.WHITEBOOKS_EMAIL;
    const username = process.env.WHITEBOOKS_USERNAME;
    const password = process.env.WHITEBOOKS_PASSWORD;
    const gstin = process.env.WHITEBOOKS_GSTIN || process.env.TRANSPORTER_GSTIN;

    const authUrl = `https://api.whitebooks.in/ewaybillapi/v1.03/authenticate?email=${encodeURIComponent(email)}&username=${encodeURIComponent(username)}&password=${encodeURIComponent(password)}`;
    const authResponse = await fetch(authUrl, {
      method: "GET",
      headers: { "Content-Type": "application/json", "client_id": clientId, "client_secret": clientSecret, "gstin": gstin, "ip_address": "127.0.0.1" }
    });
    
    const authData = await authResponse.json();
    if (!authResponse.ok || authData.status_cd === "0") throw new Error("Auth Failed");

    // TEST 1: WITHOUT transDocNo and transDocDate AT ALL
    const payloadNoKeys = {
      supplyType: "O",
      subSupplyType: "1",
      docType: "INV",
      docNo: "TEST-" + Math.floor(Date.now() / 1000),
      docDate: new Date().toLocaleDateString('en-IN', { day: '2-digit', month: '2-digit', year: 'numeric' }).replace(/-/g, '/'),
      
      fromGstin: gstin, // MUST BE VALID GSTIN
      fromTrdName: "TEST SENDER",
      fromAddr1: "Sivakasi",
      fromPlace: "Sivakasi",
      fromPincode: 626123,
      fromStateCode: 33,
      actualFromStateCode: 33,
      
      toGstin: "URP",
      toTrdName: "TEST RECEIVER",
      toAddr1: "Madurai",
      toPlace: "Madurai",
      toPincode: 625001,
      toStateCode: 33,
      actualToStateCode: 33,
      
      totalValue: 100,
      cgstValue: 0,
      sgstValue: 0,
      igstValue: 0,
      cessValue: 0,
      totInvValue: 100,
      
      transporterId: "", 
      transporterName: "",
      transMode: "1",
      transDistance: "100",
      vehicleNo: "TN67A1234",
      vehicleType: "R",
      
      itemList: [{
        productName: "Test Goods",
        productDesc: "Test Goods",
        hsnCode: 3604,
        quantity: 1,
        qtyUnit: "NOS",
        taxableAmount: 100,
        sgstRate: 0, cgstRate: 0, igstRate: 0, cessRate: 0
      }]
    };

    const genUrl = `https://api.whitebooks.in/ewaybillapi/v1.03/ewayapi/generateewaybill?email=${encodeURIComponent(email)}`;
    
    console.log("TESTING WITHOUT TRANSDOC KEYS...");
    let res1 = await fetch(genUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json", "client_id": clientId, "client_secret": clientSecret, "gstin": gstin, "ip_address": "127.0.0.1" },
      body: JSON.stringify(payloadNoKeys)
    });
    console.log("Response:", JSON.stringify(await res1.json(), null, 2));

  } catch (err) {
    console.error("Error:", err.message);
  }
}
testGenerate();
