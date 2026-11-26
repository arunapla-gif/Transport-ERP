const express = require('express');
const router = express.Router();
const os = require('os');
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// ==============================
// APP VERSION & AUTO-UPDATER
// ==============================
router.get(['/app-version', '/system/app-version'], (req, res) => {
  res.json({
    status: 'ok',
    web: {
      version: "1.0.1",
      buildNumber: 2,
      forceUpdate: false,
      releaseNotes: "• Consignor & Consignee Master UI scaling and alignment\n• All 8 Masters 1:1 parity & full search\n• Live version indicator & in-app update check"
    },
    android: {
      version: "1.0.1",
      buildNumber: 2,
      downloadUrl: "https://transport-erp-production.up.railway.app/downloads/transport-erp-operator.apk",
      forceUpdate: false,
      releaseNotes: "• Consignor & Consignee Master UI scaling and alignment\n• All 8 Masters 1:1 parity & full search\n• Live version indicator & in-app update check"
    },
    windows: {
      version: "1.0.1",
      buildNumber: 2,
      downloadUrl: "https://transport-erp-production.up.railway.app/downloads/TransportERP-Office-Setup.exe",
      forceUpdate: false,
      releaseNotes: "• Consignor & Consignee Master UI scaling and alignment\n• All 8 Masters 1:1 parity & full search\n• Live version indicator & in-app update check"
    }
  });
});

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
    const { search, entity, action, userRole, limit = 500 } = req.query;

    const where = {};
    if (entity) where.entity = entity.toUpperCase();
    if (action) where.action = action.toUpperCase();
    if (userRole) where.userRole = userRole;

    if (search) {
      where.OR = [
        { username: { contains: search, mode: 'insensitive' } },
        { entityId: { contains: search, mode: 'insensitive' } },
        { details: { contains: search, mode: 'insensitive' } }
      ];
    }

    const logs = await prisma.auditLog.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take: Math.min(parseInt(limit) || 500, 1000)
    });

    res.json(logs);
  } catch (error) {
    console.error("GET /api/audit-logs failed:", error);
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

    const email = process.env.WHITEBOOKS_EMAIL?.trim();
    const clientId = process.env.WHITEBOOKS_CLIENT_ID?.trim();
    const clientSecret = process.env.WHITEBOOKS_CLIENT_SECRET?.trim();
    const gstin = process.env.WHITEBOOKS_GSTIN?.trim();

    const headers = { 
      "Content-Type": "application/json", 
      "client_id": clientId, 
      "client_secret": clientSecret, 
      "gstin": gstin, 
      "ip_address": "127.0.0.1" 
    };

    const testEndpoint = async (step, method, url, body = null) => {
      let start = Date.now();
      try {
        const options = { method, headers };
        if (body) options.body = JSON.stringify(body);
        
        const res = await fetch(url, options);
        const data = await res.json();
        const ping = Date.now() - start;
        
        // Validation errors count as a successful ping because we reached the engine
        const isAuthError = data.error && (data.error.message?.toLowerCase().includes('auth') || data.error.message?.toLowerCase().includes('token'));
        
        if (data.status_cd === '0') {
          if (isAuthError) {
             pushResult(step, false, ping, "Authentication Failed (Check Credentials)");
          } else {
             pushResult(step, true, ping, "Success! Reached NIC Validation Engine");
          }
        } else {
          pushResult(step, true, ping, "Success! Valid response received");
        }
      } catch (e) {
        pushResult(step, false, Date.now() - start, e.message);
      }
    };

    // 1. Get GSTIN Details
    await testEndpoint(
      "Get GSTIN Details", 
      "GET", 
      `https://api.whitebooks.in/ewaybillapi/v1.03/ewayapi/getgstindetails?email=${encodeURIComponent(email)}&GSTIN=${gstin}`
    );

    // 2. Get E-Way Bill (Fake EWB Number)
    await testEndpoint(
      "Fetch E-Way Bill", 
      "GET", 
      `https://api.whitebooks.in/ewaybillapi/v1.03/ewayapi/getewaybill?email=${encodeURIComponent(email)}&ewbNo=552028120315`
    );

    // 3. Generate E-Way Bill (Fake Payload)
    await testEndpoint(
      "Generate E-Way Bill", 
      "POST", 
      `https://api.whitebooks.in/ewaybillapi/v1.03/ewayapi/generateewaybill?email=${encodeURIComponent(email)}`,
      { docNo: "TEST001", docDate: "01/01/2026" }
    );

    // 4. Generate Consolidated E-Way Bill (Fake Payload)
    await testEndpoint(
      "Generate CEWB", 
      "POST", 
      `https://api.whitebooks.in/ewaybillapi/v1.03/ewayapi/gencewb?email=${encodeURIComponent(email)}`,
      { vehicleNo: "TN99Z9999", fromPlace: "Sivakasi" }
    );

    // 5. Update Transporter (Fake Payload)
    await testEndpoint(
      "Update Transporter", 
      "POST", 
      `https://api.whitebooks.in/ewaybillapi/v1.03/ewayapi/updatetransporter?email=${encodeURIComponent(email)}`,
      { ewbNo: 123456789012, transporterId: gstin }
    );

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
