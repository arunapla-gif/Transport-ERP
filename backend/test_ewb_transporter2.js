require('dotenv').config();
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function test() {
  try {
    const gc = await prisma.gC.findFirst({
      where: { ewbNumber: { not: null, not: "" } },
      orderBy: { id: 'desc' }
    });
    if (!gc) return console.log("No EWB found");
    
    const ewbNo = gc.ewbNumber;
    console.log(`Checking EWB: ${ewbNo}`);

    const clientId = process.env.WHITEBOOKS_CLIENT_ID?.trim();
    const clientSecret = process.env.WHITEBOOKS_CLIENT_SECRET?.trim();
    const email = process.env.WHITEBOOKS_EMAIL?.trim();
    const username = process.env.WHITEBOOKS_USERNAME?.trim();
    const password = process.env.WHITEBOOKS_PASSWORD?.trim();
    const gstin = process.env.WHITEBOOKS_GSTIN?.trim();

    // 1. Fetch
    const ewbUrl = `https://api.whitebooks.in/ewaybillapi/v1.03/ewayapi/getewaybill?email=${encodeURIComponent(email)}&ewbNo=${ewbNo}`;
    const response = await fetch(ewbUrl, {
      method: "GET",
      headers: { "Content-Type": "application/json", "client_id": clientId, "client_secret": clientSecret, "gstin": gstin, "ip_address": "127.0.0.1" }
    });
    
    const data = await response.json();
    console.log(data);

  } catch(e) { console.error(e); }
}
test();
