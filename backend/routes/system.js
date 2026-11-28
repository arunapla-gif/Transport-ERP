const express = require('express');
const router = express.Router();
const os = require('os');
const prisma = require('../db');

// ==============================
// APP VERSION & AUTO-UPDATER
// ==============================
router.get(['/app-version', '/system/app-version'], (req, res) => {
  res.json({
    status: 'ok',
    web: {
      version: "1.0.26",
      buildNumber: 27,
      forceUpdate: false,
      releaseNotes: "• System Boot: Added 6-hour cached non-blocking WhiteBooks EWB Gateway check\n• E-Way Bill: Future-proofed all local validators & QR scanners for 12–15 digit EWBs (Jan 2027 ready)"
    },
    android: {
      version: "1.0.8",
      buildNumber: 9,
      downloadUrl: "https://transport-erp-production.up.railway.app/downloads/transport-erp-operator.apk",
      forceUpdate: false,
      releaseNotes: "• Unified Dashboard desktop header into a single compact 58px bar"
    },
    windows: {
      version: "1.0.2",
      buildNumber: 3,
      downloadUrl: "https://transport-erp-production.up.railway.app/downloads/TransportERP-Office-Setup.exe",
      forceUpdate: false,
      releaseNotes: "• SQL-level search & pagination for Consignors & Consignees\n• Debounced GC Register search & controller leak fixes\n• Persistent HTTP pooling & static Master caching"
    }
  });
});

// ==============================
// HEALTH & BOOT ENDPOINT
// ==============================
router.get('/health', async (req, res) => {
  try {
    // Lightweight query to ensure PostgreSQL connection is active
    await prisma.$queryRaw`SELECT 1`;
    res.status(200).json({ status: 'healthy', db: 'connected', timestamp: new Date() });
  } catch (error) {
    console.error("Health check failed:", error);
    res.status(503).json({ status: 'unhealthy', db: 'disconnected', error: error.message });
  }
});

// Cached WhiteBooks E-Way Bill Gateway status (6-hour TTL, zero-cost single ping)
let _whitebooksStatusCache = null;
const WHITEBOOKS_CACHE_TTL_MS = 6 * 60 * 60 * 1000;

router.get('/whitebooks-status', async (req, res) => {
  const force = req.query.refresh === '1';
  const now = Date.now();
  if (!force && _whitebooksStatusCache && (now - _whitebooksStatusCache.timestamp) < WHITEBOOKS_CACHE_TTL_MS) {
    return res.json({ ..._whitebooksStatusCache.payload, cached: true });
  }

  const email = process.env.WHITEBOOKS_EMAIL?.trim();
  const clientId = process.env.WHITEBOOKS_CLIENT_ID?.trim();
  const clientSecret = process.env.WHITEBOOKS_CLIENT_SECRET?.trim();
  const gstin = process.env.WHITEBOOKS_GSTIN?.trim();

  if (!email || !clientId || !clientSecret || !gstin) {
    const payload = { ok: false, pingMs: 0, message: 'WhiteBooks credentials not configured', checkedAt: new Date().toISOString() };
    _whitebooksStatusCache = { timestamp: now, payload };
    return res.json({ ...payload, cached: false });
  }

  const start = Date.now();
  try {
    const url = `https://api.whitebooks.in/ewaybillapi/v1.03/ewayapi/getgstindetails?email=${encodeURIComponent(email)}&GSTIN=${gstin}`;
    const response = await fetch(url, {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
        'client_id': clientId,
        'client_secret': clientSecret,
        'gstin': gstin,
        'ip_address': '127.0.0.1'
      },
      signal: AbortSignal.timeout(8000)
    });
    const pingMs = Date.now() - start;
    const rawText = await response.text();
    let data = null;
    try { data = JSON.parse(rawText); } catch (_) {}

    const errMsg = data?.error?.message || data?.error?.errorDesc || '';
    const isAuthErr = errMsg.toLowerCase().includes('auth') || errMsg.toLowerCase().includes('token');

    let payload;
    if (!data) {
      payload = { ok: false, pingMs, message: `Gateway HTTP ${response.status}`, checkedAt: new Date().toISOString() };
    } else if (data.status_cd === '0' && isAuthErr) {
      payload = { ok: false, pingMs, message: 'Auth Failed — check WhiteBooks credentials', checkedAt: new Date().toISOString() };
    } else {
      payload = { ok: true, pingMs, message: 'WhiteBooks v1.03 Online', checkedAt: new Date().toISOString() };
    }
    _whitebooksStatusCache = { timestamp: now, payload };
    return res.json({ ...payload, cached: false });
  } catch (e) {
    const payload = { ok: false, pingMs: Date.now() - start, message: e.message || 'Unreachable', checkedAt: new Date().toISOString() };
    _whitebooksStatusCache = { timestamp: now, payload };
    return res.json({ ...payload, cached: false });
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
  req.setTimeout(60000);

  try {
    const email = process.env.WHITEBOOKS_EMAIL?.trim();
    const clientId = process.env.WHITEBOOKS_CLIENT_ID?.trim();
    const clientSecret = process.env.WHITEBOOKS_CLIENT_SECRET?.trim();
    const gstin = process.env.WHITEBOOKS_GSTIN?.trim();

    if (!email || !clientId || !clientSecret || !gstin) {
      return res.status(400).json({
        success: false,
        error: 'Missing WhiteBooks credentials (WHITEBOOKS_EMAIL, CLIENT_ID, CLIENT_SECRET, GSTIN).'
      });
    }

    const headers = {
      "Content-Type": "application/json",
      "client_id": clientId,
      "client_secret": clientSecret,
      "gstin": gstin,
      "ip_address": "127.0.0.1"
    };

    const testEndpoint = async (step, method, url, body = null) => {
      const start = Date.now();
      try {
        const options = { method, headers, signal: AbortSignal.timeout(15000) };
        if (body) options.body = JSON.stringify(body);

        const response = await fetch(url, options);
        const rawText = await response.text();
        const ping = Date.now() - start;

        let data;
        try {
          data = JSON.parse(rawText);
        } catch {
          return {
            step,
            success: false,
            ping,
            message: `Invalid non-JSON response (HTTP ${response.status})`,
            data: null
          };
        }

        // Validation errors count as a successful ping because we reached the engine
        const isAuthError = data.error && (data.error.message?.toLowerCase().includes('auth') || data.error.message?.toLowerCase().includes('token'));

        if (data.status_cd === '0') {
          if (isAuthError) {
            return { step, success: false, ping, message: "Authentication Failed (Check Credentials)", data: null };
          }
          return { step, success: true, ping, message: "Success! Reached NIC Validation Engine", data: null };
        }
        return { step, success: true, ping, message: "Success! Valid response received", data: null };
      } catch (e) {
        return { step, success: false, ping: Date.now() - start, message: e.message, data: null };
      }
    };

    const results = await Promise.all([
      testEndpoint(
        "Get GSTIN Details",
        "GET",
        `https://api.whitebooks.in/ewaybillapi/v1.03/ewayapi/getgstindetails?email=${encodeURIComponent(email)}&GSTIN=${gstin}`
      ),
      testEndpoint(
        "Fetch E-Way Bill",
        "GET",
        `https://api.whitebooks.in/ewaybillapi/v1.03/ewayapi/getewaybill?email=${encodeURIComponent(email)}&ewbNo=552028120315`
      ),
      testEndpoint(
        "Generate E-Way Bill",
        "POST",
        `https://api.whitebooks.in/ewaybillapi/v1.03/ewayapi/generateewaybill?email=${encodeURIComponent(email)}`,
        { docNo: "TEST001", docDate: "01/01/2026" }
      ),
      testEndpoint(
        "Generate CEWB",
        "POST",
        `https://api.whitebooks.in/ewaybillapi/v1.03/ewayapi/gencewb?email=${encodeURIComponent(email)}`,
        { vehicleNo: "TN99Z9999", fromPlace: "Sivakasi" }
      ),
      testEndpoint(
        "Update Transporter",
        "POST",
        `https://api.whitebooks.in/ewaybillapi/v1.03/ewayapi/updatetransporter?email=${encodeURIComponent(email)}`,
        { ewbNo: 123456789012, transporterId: gstin }
      )
    ]);

    const allSuccess = results.every(r => r.success);

    // Log overall ping
    try {
      await prisma.apiUsageLog.create({
        data: { provider: 'WhiteBooks (Sandbox)', apiName: 'Full Lifecycle Test', status: allSuccess ? 'Success' : 'Failed', cost: 0.00 }
      });
    } catch (e) {}

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
