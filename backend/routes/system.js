const express = require('express');
const router = express.Router();
const os = require('os');
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// ==============================
// HEALTH & BOOT ENDPOINT
// ==============================
router.get('/health', async (req, res) => {
  try {
    // Lightweight query to ensure Neon database connection is active
    await prisma.$queryRaw`SELECT 1`;
    res.status(200).json({ status: 'healthy', db: 'connected', timestamp: new Date() });
  } catch (error) {
    console.error("Health check failed:", error);
    res.status(503).json({ status: 'unhealthy', db: 'disconnected', error: error.message });
  }
});

// System Pulse
router.get('/system-pulse', async (req, res) => {
  try {
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    // 1. Total Inwards Today
    const inwardsToday = await prisma.warehouseInward.count({
      where: { createdAt: { gte: today } }
    });

    // 2. Total Pending GCs (Created but not dispatched)
    const pendingGCs = await prisma.gC.count({
      where: { status: 'Created' }
    });

    // 3. Total API Usage Today
    const apiCallsToday = await prisma.apiUsageLog.count({
      where: { timestamp: { gte: today } }
    });

    // Determine System Health
    const dbStatus = "Connected";
    let urgentAlert = null;

    if (pendingGCs > 1000) {
      urgentAlert = `Warning: High backlog! ${pendingGCs} GCs are pending dispatch.`;
    } else if (apiCallsToday > 500) {
      urgentAlert = `Warning: High API usage! ${apiCallsToday} API calls made today. Check limits.`;
    }

    res.json({
      status: 'ok',
      timestamp: new Date().toISOString(),
      stats: {
        inwardsToday,
        pendingGCs,
        apiCallsToday,
        dbStatus
      },
      urgentAlert
    });
  } catch (error) {
    console.error('System Pulse Error:', error);
    res.status(500).json({ error: 'Failed to fetch pulse.' });
  }
});

// System Health
router.get('/system/health', async (req, res) => {
  try {
    const start = Date.now();
    // Execute a simple query to measure DB latency
    await prisma.$queryRaw`SELECT 1`;
    const dbLatency = Date.now() - start;

    const memoryUsage = process.memoryUsage();
    
    const axios = require('axios');
    
    // Attempt to ping external APIs to check their availability
    const checkUrl = async (url) => {
      try {
        const fetchStart = Date.now();
        const response = await axios.head(url, { timeout: 3000, validateStatus: () => true });
        return { online: response.status < 500, latency: Date.now() - fetchStart };
      } catch (err) {
        return { online: false, latency: -1 };
      }
    };
    
    const [appyflowStatus, vahanStatus] = await Promise.all([
      checkUrl('https://b2b.appyflow.in'),
      checkUrl('https://vahan.parivahan.gov.in') // just a domain check
    ]);

    res.json({
      success: true,
      data: {
        uptime: process.uptime(),
        memoryUsage: {
          rss: memoryUsage.rss,
          heapTotal: memoryUsage.heapTotal,
          heapUsed: memoryUsage.heapUsed,
        },
        cpuLoad: os.loadavg(),
        dbLatency,
        externalServices: {
          appyflow: appyflowStatus,
          vahan: vahanStatus
        }
      }
    });
  } catch (error) {
    console.error("Health check error:", error);
    res.status(500).json({ success: false, error: error.message });
  }
});

router.get('/system/health/history', async (req, res) => {
  try {
    const logs = await prisma.systemHealthLog.findMany({
      orderBy: { createdAt: 'desc' },
      take: 96 // last 24 hours at 15-min intervals
    });
    // Reverse to get chronological order for charts
    res.json({ success: true, data: logs.reverse() });
  } catch (error) {
    console.error("Health history error:", error);
    res.status(500).json({ success: false, error: error.message });
  }
});

router.get('/audit-logs', async (req, res) => {
  try {
    const logs = await prisma.auditLog.findMany({
      orderBy: { createdAt: 'desc' },
      take: 500
    });
    res.json(logs);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch audit logs' });
  }
});

router.post('/usage/sandbox-test', async (req, res) => {
  // Set long timeout for multi-step test
  req.setTimeout(60000);
  
  try {
    const results = [];
    const pushResult = (step, success, ping, message, data = null) => {
      results.push({ step, success, ping, message, data });
    };

    // Shared Sandbox Credentials
    const email = process.env.WHITEBOOKS_EMAIL?.trim() || "admin@example.com"; 
    const username = "BVMGSP";
    const password = "Wbooks@0142";
    const gstin = "29AAGCB1286Q000";
    const clientId = "EWBS670d1a72-ce2e-4c8d-9839-73b5ebc30539";
    const clientSecret = "EWBSafc52ae4-adc7-455e-b458-7539b8321d36";
    const headers = { "Content-Type": "application/json", "client_id": clientId, "client_secret": clientSecret, "gstin": gstin, "ip_address": "127.0.0.1" };

    // --- STEP 1: AUTH ---
    let authStart = Date.now();
    let authRes, authData;
    try {
      authRes = await fetch(`https://apisandbox.whitebooks.in/ewaybillapi/v1.03/authenticate?email=${encodeURIComponent(email)}&username=${encodeURIComponent(username)}&password=${encodeURIComponent(password)}`, { method: "GET", headers });
      authData = await authRes.json();
      const ping = Date.now() - authStart;
      if (!authRes.ok || authData.status_cd === "0") throw new Error(authData.error?.message || authData.status_desc || 'Auth Failed');
      headers["AuthToken"] = authData.authtoken || authData.data?.authtoken || authData.AuthToken || '';
      pushResult("Authenticate", true, ping, "Successfully retrieved token.");
    } catch (e) {
      pushResult("Authenticate", false, Date.now() - authStart, e.message);
      return res.json({ success: false, results }); // Abort if auth fails
    }

    // --- STEP 2: GENERATE EWB 1 ---
    let gen1Start = Date.now();
    let ewb1 = null;
    try {
      const docNo = `TEST-${Math.floor(Date.now() / 1000)}`;
      
      const genPayload = {
        supplyType: "O", subSupplyType: "1", docType: "INV", docNo, docDate: "29/07/2026",
        fromGstin: gstin, fromTrdName: "TEST CONSIGNOR", fromAddr1: "Bangalore", fromPlace: "Bangalore", fromPincode: 560001, fromStateCode: 29, actualFromStateCode: 29,
        toGstin: "URP", toTrdName: "TEST CONSIGNEE", toAddr1: "Sivakasi", toPlace: "Sivakasi", toPincode: 626123, toStateCode: 33, actualToStateCode: 33,
        totalValue: 100, cgstValue: 9, sgstValue: 9, igstValue: 0, cessValue: 0, totInvValue: 118,
        transporterId: "", transporterName: "", transMode: "1", transDistance: "100", vehicleNo: "KA01AB1234", vehicleType: "R",
        itemList: [{ productName: "Goods", productDesc: "Goods", hsnCode: 3604, quantity: 1, qtyUnit: "NOS", taxableAmount: 100, sgstRate: 9, cgstRate: 9, igstRate: 0, cessRate: 0 }]
      };
      
      const genRes = await fetch(`https://apisandbox.whitebooks.in/ewaybillapi/v1.03/ewayapi/generateewaybill?email=${encodeURIComponent(email)}`, { method: "POST", headers, body: JSON.stringify(genPayload) });
      const genData = await genRes.json();
      const ping = Date.now() - gen1Start;
      if (!genRes.ok || genData.status_cd === "0") throw new Error(genData.error?.message || genData.error?.errorDesc || genData.status_desc || 'Generate Failed');
      ewb1 = genData.data?.ewayBillNo || genData.ewayBillNo;
      pushResult("Generate", true, ping, `Success! EWB: ${ewb1}`);
    } catch (e) {
      pushResult("Generate", false, Date.now() - gen1Start, e.message);
    }

    // --- STEP 3: FETCH EWB ---
    let fetchStart = Date.now();
    try {
      if (!ewb1) throw new Error('Skipped because Generation failed.');
      const fetchRes = await fetch(`https://apisandbox.whitebooks.in/ewaybillapi/v1.03/ewayapi/getewaybill?email=${encodeURIComponent(email)}&ewbNo=${ewb1}`, { method: "GET", headers });
      const fetchData = await fetchRes.json();
      const ping = Date.now() - fetchStart;
      if (!fetchRes.ok || fetchData.status_cd === "0") throw new Error(fetchData.error?.message || 'Fetch Failed');
      pushResult("Fetch", true, ping, `Successfully fetched mapping for ${ewb1}`);
    } catch (e) {
      pushResult("Fetch", false, Date.now() - fetchStart, e.message);
    }

    // --- STEP 4: REGENERATE (GENERATE EWB 2) ---
    let regStart = Date.now();
    let ewb2 = null;
    try {
      const docNo = `REG-${Math.floor(Date.now() / 1000)}`;
      
      const regPayload = {
        supplyType: "O", subSupplyType: "1", docType: "INV", docNo, docDate: "29/07/2026",
        fromGstin: gstin, fromTrdName: "TEST CONSIGNOR", fromAddr1: "Bangalore", fromPlace: "Bangalore", fromPincode: 560001, fromStateCode: 29, actualFromStateCode: 29,
        toGstin: "URP", toTrdName: "TEST CONSIGNEE", toAddr1: "Sivakasi", toPlace: "Sivakasi", toPincode: 626123, toStateCode: 33, actualToStateCode: 33,
        totalValue: 100, cgstValue: 9, sgstValue: 9, igstValue: 0, cessValue: 0, totInvValue: 118,
        transporterId: "", transporterName: "", transMode: "1", transDistance: "100", vehicleNo: "KA01AB1234", vehicleType: "R",
        itemList: [{ productName: "Goods", productDesc: "Goods", hsnCode: 3604, quantity: 1, qtyUnit: "NOS", taxableAmount: 100, sgstRate: 9, cgstRate: 9, igstRate: 0, cessRate: 0 }]
      };
      
      const regRes = await fetch(`https://apisandbox.whitebooks.in/ewaybillapi/v1.03/ewayapi/generateewaybill?email=${encodeURIComponent(email)}`, { method: "POST", headers, body: JSON.stringify(regPayload) });
      const regData = await regRes.json();
      const ping = Date.now() - regStart;
      if (!regRes.ok || regData.status_cd === "0") throw new Error(regData.error?.message || regData.error?.errorDesc || 'Regenerate Failed');
      ewb2 = regData.data?.ewayBillNo || regData.ewayBillNo;
      pushResult("Regenerate", true, ping, `Success! EWB: ${ewb2}`);
    } catch (e) {
      pushResult("Regenerate", false, Date.now() - regStart, e.message);
    }

    // --- STEP 5: CONSOLIDATE (CEWB) ---
    let cewbStart = Date.now();
    try {
      if (!ewb1 || !ewb2) throw new Error('Skipped because we need 2 active EWBs.');
      const cewbPayload = {
        vehicleNo: "KA01AB1234", fromPlace: "Bangalore", fromState: 29, transMode: "1", 
        transDocNo: `TR-${Math.floor(Date.now() / 1000)}`,
        transDocDate: "29/07/2026",
        tripSheetEwbBills: [{ ewbNo: Number(ewb1) }, { ewbNo: Number(ewb2) }]
      };
      
      const cewbRes = await fetch(`https://apisandbox.whitebooks.in/ewaybillapi/v1.03/ewayapi/generatecewb?email=${encodeURIComponent(email)}`, { method: "POST", headers, body: JSON.stringify(cewbPayload) });
      const cewbData = await cewbRes.json();
      const ping = Date.now() - cewbStart;
      
      if (!cewbRes.ok || cewbData.status_cd === "0") throw new Error(cewbData.error?.message || cewbData.error?.errorDesc || 'CEWB Failed');
      const cewbNo = cewbData.data?.cEwbNo || cewbData.cEwbNo;
      pushResult("CEWB", true, ping, `Success! CEWB: ${cewbNo}`);
    } catch (e) {
      pushResult("CEWB", false, Date.now() - cewbStart, e.message);
    }

    const allSuccess = results.every(r => r.success);
    
    // Log overall ping
    try {
       await prisma.apiUsageLog.create({
         data: { provider: 'WhiteBooks (Sandbox)', apiName: 'Full Lifecycle Test', status: allSuccess ? 'Success' : 'Failed', cost: 0.00 }
       });
    } catch(e) {}

    res.json({ success: allSuccess, results });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

router.get('/usage/stats', async (req, res) => {
  try {
    // 1. Raw SQL for fast Database Aggregation (Daily)
    const dailyRaw = await prisma.$queryRaw`
      SELECT date_trunc('day', timestamp) as day, 
             COUNT(*)::int as count, 
             SUM(cost)::float as cost 
      FROM "ApiUsageLog" 
      GROUP BY 1 
      ORDER BY 1 DESC 
      LIMIT 30;
    `;
    
    // 2. Raw SQL for fast Database Aggregation (Monthly)
    const monthlyRaw = await prisma.$queryRaw`
      SELECT date_trunc('month', timestamp) as month, 
             COUNT(*)::int as count, 
             SUM(cost)::float as cost 
      FROM "ApiUsageLog" 
      GROUP BY 1 
      ORDER BY 1 DESC 
      LIMIT 12;
    `;

    // 3. Fast Total Aggregate
    const totalAgg = await prisma.apiUsageLog.aggregate({
      _sum: { cost: true }
    });

    // 4. Strict limit on Recent Logs
    const recent = await prisma.apiUsageLog.findMany({
      orderBy: { timestamp: 'desc' },
      take: 100
    });

    // Structure for Frontend
    const stats = {
      daily: {},
      monthly: {},
      yearly: {}, // Frontend only uses monthly/daily currently
      totalCost: totalAgg._sum.cost || 0,
      recent
    };

    // Format SQL results for frontend maps
    dailyRaw.forEach(row => {
      const dateStr = new Date(row.day).toISOString().split('T')[0];
      stats.daily[dateStr] = { count: row.count, cost: row.cost || 0 };
    });

    monthlyRaw.forEach(row => {
      const monthStr = new Date(row.month).toISOString().substring(0, 7);
      stats.monthly[monthStr] = { count: row.count, cost: row.cost || 0 };
    });

    res.json(stats);
  } catch (error) {
    console.error("GET /api/usage/stats failed:", error);
    res.status(500).json({ error: 'Failed to fetch API stats' });
  }
});

module.exports = router;
