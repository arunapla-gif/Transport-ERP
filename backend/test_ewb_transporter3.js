require('dotenv').config();
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function test() {
  try {
    const ewbNo = '502022006821';
    
    const clientId = process.env.WHITEBOOKS_CLIENT_ID?.trim();
    const clientSecret = process.env.WHITEBOOKS_CLIENT_SECRET?.trim();
    const email = process.env.WHITEBOOKS_EMAIL?.trim();
    // Using BELL credentials
    const gstin = process.env.BELL_WHITEBOOKS_GSTIN?.trim();

    // 1. Fetch
    const ewbUrl = `https://api.whitebooks.in/ewaybillapi/v1.03/ewayapi/getewaybill?email=${encodeURIComponent(email)}&ewbNo=${ewbNo}`;
    const response = await fetch(ewbUrl, {
      method: "GET",
      headers: { "Content-Type": "application/json", "client_id": clientId, "client_secret": clientSecret, "gstin": gstin, "ip_address": "127.0.0.1" }
    });
    
    const data = await response.json();
    console.log({
      transporterId: data.transporterId,
      transporterName: data.transporterName,
      status: data.status,
      fromGstin: data.fromGstin,
      toGstin: data.toGstin
    });

  } catch(e) { console.error(e); }
}
test();
