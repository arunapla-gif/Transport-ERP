require('dotenv').config();

async function testBellAuth() {
  const clientId = process.env.WHITEBOOKS_CLIENT_ID?.trim();
  const clientSecret = process.env.WHITEBOOKS_CLIENT_SECRET?.trim();
  const username = process.env.BELL_WHITEBOOKS_USERNAME?.trim();
  const password = process.env.BELL_WHITEBOOKS_PASSWORD?.trim();
  const gstin = process.env.BELL_WHITEBOOKS_GSTIN?.trim();
  const email = process.env.WHITEBOOKS_EMAIL?.trim();

  console.log('Testing BELL Authentication...');
  console.log(`Username: ${username}`);
  console.log(`GSTIN: ${gstin}`);

  if (!clientId || !clientSecret || !username || !password || !email || !gstin) {
    console.error("Missing credentials in .env!");
    return;
  }

  const authUrl = `https://api.whitebooks.in/ewaybillapi/v1.03/authenticate?email=${encodeURIComponent(email)}&username=${encodeURIComponent(username)}&password=${encodeURIComponent(password)}`;
  
  try {
    const response = await fetch(authUrl, {
      method: "GET",
      headers: {
        "Content-Type": "application/json",
        "client_id": clientId,
        "client_secret": clientSecret,
        "gstin": gstin,
        "ip_address": "127.0.0.1"
      }
    });
    
    const data = await response.json();
    console.log('\n--- API RESPONSE ---');
    console.log(JSON.stringify(data, null, 2));
    
    if (!response.ok || data.status_cd === "0") {
       console.error("\n❌ AUTHENTICATION FAILED!");
    } else {
       console.log("\n✅ AUTHENTICATION SUCCESSFUL!");
       console.log(`AuthToken received: ${data.authtoken || data.data?.authtoken ? 'YES' : 'NO'}`);
    }
  } catch (error) {
    console.error("Fetch error:", error);
  }
}

testBellAuth();
