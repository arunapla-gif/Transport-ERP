const express = require('express');
const cors = require('cors');
const { PrismaClient } = require('@prisma/client');
const { GoogleGenerativeAI } = require('@google/generative-ai');
const http = require('http');
const { Server } = require('socket.io');

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST']
  }
});

// Setup socket connection
io.on('connection', (socket) => {
  console.log('Client connected:', socket.id);

  socket.on('join-room', (roomId) => {
    socket.join(roomId);
    console.log(`Socket ${socket.id} joined room ${roomId}`);
  });

  socket.on('mobile-joined', (roomId) => {
    // Notify room that scanner is connected
    socket.to(roomId).emit('scanner-status', { connected: true });
  });

  socket.on('scan-data', ({ roomId, data }) => {
    console.log(`Data received in room ${roomId}:`, data);
    // Send data only to others in the room (the PC)
    socket.to(roomId).emit('scan-received', data);
  });

  socket.on('disconnect', () => {
    console.log('Client disconnected:', socket.id);
  });
});
const prisma = new PrismaClient();
const PORT = process.env.PORT || 5000;

app.use(cors());
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ limit: '50mb', extended: true }));

// Basic health check endpoint
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', message: 'Transport ERP Backend is running' });
});

// Helper to log API usage
const logApiUsage = async (provider, apiName, status, cost = 0) => {
  try {
    await prisma.apiUsageLog.create({
      data: { provider, apiName, status, cost }
    });
  } catch (err) {
    console.error('Failed to log API usage:', err);
  }
};

app.get('/api/usage/stats', async (req, res) => {
  try {
    const logs = await prisma.apiUsageLog.findMany({
      orderBy: { timestamp: 'desc' }
    });
    
    // Group by Daily, Monthly, Yearly
    const stats = {
      daily: {},
      monthly: {},
      yearly: {},
      totalCost: 0,
      recent: logs.slice(0, 100)
    };
    
    logs.forEach(log => {
      const date = new Date(log.timestamp);
      const day = date.toISOString().split('T')[0];
      const month = day.substring(0, 7);
      const year = day.substring(0, 4);
      
      // Daily
      if (!stats.daily[day]) stats.daily[day] = { count: 0, cost: 0 };
      stats.daily[day].count += 1;
      stats.daily[day].cost += log.cost || 0;
      
      // Monthly
      if (!stats.monthly[month]) stats.monthly[month] = { count: 0, cost: 0 };
      stats.monthly[month].count += 1;
      stats.monthly[month].cost += log.cost || 0;
      
      // Yearly
      if (!stats.yearly[year]) stats.yearly[year] = { count: 0, cost: 0 };
      stats.yearly[year].count += 1;
      stats.yearly[year].cost += log.cost || 0;
      
      stats.totalCost += log.cost || 0;
    });
    
    res.json(stats);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch API stats' });
  }
});

// ==============================
// CONSIGNOR ENDPOINTS
// ==============================
app.get('/api/consignors', async (req, res) => {
  try {
    const consignors = await prisma.consignor.findMany({ orderBy: { id: 'desc' } });
    res.json(consignors);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch consignors' });
  }
});

app.post('/api/consignors', async (req, res) => {
  try {
    const { name, ...rest } = req.body;
    const consignor = await prisma.consignor.upsert({
      where: { name },
      update: rest,
      create: { name, ...rest }
    });
    res.json(consignor);
  } catch (error) {
    res.status(500).json({ error: 'Failed to create consignor' });
  }
});

app.put('/api/consignors/:id', async (req, res) => {
  try {
    const consignor = await prisma.consignor.update({
      where: { id: parseInt(req.params.id) },
      data: req.body,
    });
    res.json(consignor);
  } catch (error) {
    res.status(500).json({ error: 'Failed to update consignor' });
  }
});

app.delete('/api/consignors/:id', async (req, res) => {
  try {
    await prisma.consignor.delete({ where: { id: parseInt(req.params.id) } });
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: 'Failed to delete consignor' });
  }
});


// ==============================
// FREIGHT BILL ENDPOINTS
// ==============================
app.get('/api/freight-bills', async (req, res) => {
  try {
    const bills = await prisma.freightBill.findMany({ orderBy: { id: 'desc' } });
    res.json(bills);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch Freight Bills' });
  }
});

app.post('/api/freight-bills', async (req, res) => {
  try {
    const billData = req.body;
    
    if (billData.date) billData.date = new Date(billData.date);
    if (billData.grossFreight) billData.grossFreight = parseFloat(billData.grossFreight);
    if (billData.advancePaid) billData.advancePaid = parseFloat(billData.advancePaid);
    if (billData.commission) billData.commission = parseFloat(billData.commission);
    if (billData.shortage) billData.shortage = parseFloat(billData.shortage);
    if (billData.tds) billData.tds = parseFloat(billData.tds);
    if (billData.netBalance) billData.netBalance = parseFloat(billData.netBalance);

    const bill = await prisma.freightBill.create({
      data: billData
    });
    res.status(201).json(bill);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to create Freight Bill' });
  }
});

// ==============================
// CONSIGNEE ENDPOINTS
// ==============================
app.get('/api/consignees', async (req, res) => {
  try {
    const consignees = await prisma.consignee.findMany({ orderBy: { id: 'desc' } });
    res.json(consignees);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch consignees' });
  }
});

app.post('/api/consignees', async (req, res) => {
  try {
    const { name, ...rest } = req.body;
    const consignee = await prisma.consignee.upsert({
      where: { name },
      update: rest,
      create: { name, ...rest }
    });
    res.json(consignee);
  } catch (error) {
    res.status(500).json({ error: 'Failed to create consignee' });
  }
});

app.put('/api/consignees/:id', async (req, res) => {
  try {
    const consignee = await prisma.consignee.update({
      where: { id: parseInt(req.params.id) },
      data: req.body,
    });
    res.json(consignee);
  } catch (error) {
    res.status(500).json({ error: 'Failed to update consignee' });
  }
});

app.delete('/api/consignees/:id', async (req, res) => {
  try {
    await prisma.consignee.delete({ where: { id: parseInt(req.params.id) } });
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: 'Failed to delete consignee' });
  }
});
// ==============================
// VEHICLE ENDPOINTS
// ==============================
app.get('/api/vehicles', async (req, res) => {
  try {
    const vehicles = await prisma.vehicle.findMany({ orderBy: { id: 'desc' } });
    res.json(vehicles);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch vehicles' });
  }
});

app.post('/api/vehicles', async (req, res) => {
  try {
    const vehicle = await prisma.vehicle.create({ data: req.body });
    res.json(vehicle);
  } catch (error) {
    if (error.code === 'P2002') {
      return res.status(400).json({ error: 'Vehicle Number already exists' });
    }
    res.status(500).json({ error: 'Failed to create vehicle' });
  }
});

app.put('/api/vehicles/:id', async (req, res) => {
  try {
    const vehicle = await prisma.vehicle.update({
      where: { id: parseInt(req.params.id) },
      data: req.body,
    });
    res.json(vehicle);
  } catch (error) {
    if (error.code === 'P2002') {
      return res.status(400).json({ error: 'Vehicle Number already exists' });
    }
    res.status(500).json({ error: 'Failed to update vehicle' });
  }
});

app.delete('/api/vehicles/:id', async (req, res) => {
  try {
    await prisma.vehicle.delete({ where: { id: parseInt(req.params.id) } });
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: 'Failed to delete vehicle' });
  }
});

// ==============================
// COMPANY ENDPOINTS
// ==============================
app.get('/api/companies', async (req, res) => {
  try {
    const companies = await prisma.company.findMany({ orderBy: { id: 'desc' } });
    res.json(companies);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch companies' });
  }
});

app.post('/api/companies', async (req, res) => {
  try {
    const data = { ...req.body };
    delete data.id;
    const company = await prisma.company.create({ data });
    res.json(company);
  } catch (error) {
    console.error("Failed to create company:", error);
    if (error.code === 'P2002') return res.status(400).json({ error: 'GSTIN already exists' });
    res.status(500).json({ error: 'Failed to create company' });
  }
});

app.put('/api/companies/:id', async (req, res) => {
  try {
    const data = { ...req.body };
    delete data.id;
    const company = await prisma.company.update({
      where: { id: parseInt(req.params.id) },
      data,
    });
    res.json(company);
  } catch (error) {
    console.error("Failed to update company:", error);
    if (error.code === 'P2002') return res.status(400).json({ error: 'GSTIN already exists' });
    res.status(500).json({ error: 'Failed to update company' });
  }
});

app.delete('/api/companies/:id', async (req, res) => {
  try {
    await prisma.company.delete({ where: { id: parseInt(req.params.id) } });
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: 'Failed to delete company' });
  }
});

// ==============================
// GODOWN ENDPOINTS
// ==============================
app.get('/api/godowns', async (req, res) => {
  try {
    const godowns = await prisma.godown.findMany({ orderBy: { id: 'desc' } });
    res.json(godowns);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch godowns' });
  }
});

app.post('/api/godowns', async (req, res) => {
  try {
    const { name } = req.body;
    const godown = await prisma.godown.create({ data: { name } });
    res.json(godown);
  } catch (error) {
    if (error.code === 'P2002') return res.status(400).json({ error: 'Godown name already exists' });
    res.status(500).json({ error: 'Failed to create godown' });
  }
});

// --- Remote Mobile Scanner API ---
const remoteScans = {};

app.get('/api/scanner/poll', (req, res) => {
  const { code } = req.query;
  if (!code) return res.status(400).json({ error: 'Code required' });
  
  if (remoteScans[code]) {
    const data = remoteScans[code];
    delete remoteScans[code];
    return res.json({ status: 'success', data });
  }
  
  return res.json({ status: 'waiting' });
});

app.post('/api/scanner/push', (req, res) => {
  const { code, data } = req.body;
  if (!code || !data) return res.status(400).json({ error: 'Code and data required' });
  
  remoteScans[code] = data;
  res.json({ success: true });
});

// --- Warehouse Inward Endpoints ---
app.get('/api/warehouse-inward', async (req, res) => {
  try {
    const { date } = req.query;
    let whereClause = {};
    
    if (date) {
      const startOfDay = new Date(date);
      startOfDay.setHours(0, 0, 0, 0);
      const endOfDay = new Date(date);
      endOfDay.setHours(23, 59, 59, 999);
      whereClause.createdAt = {
        gte: startOfDay,
        lte: endOfDay
      };
    } else {
      // Default to today if no date provided
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      whereClause.createdAt = {
        gte: today
      };
    }

    const inwards = await prisma.warehouseInward.findMany({
      where: whereClause,
      orderBy: { createdAt: 'desc' }
    });
    res.json(inwards);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to fetch inward entries' });
  }
});

app.post('/api/warehouse-inward', async (req, res) => {
  try {
    const lastEntry = await prisma.warehouseInward.findFirst({
      orderBy: { receiptNo: 'desc' },
      where: { receiptNo: { not: null } }
    });
    const nextReceiptNo = lastEntry && lastEntry.receiptNo ? lastEntry.receiptNo + 1 : 1;

    const inward = await prisma.warehouseInward.create({ 
      data: { ...req.body, receiptNo: nextReceiptNo } 
    });
    res.json(inward);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to save inward entry' });
  }
});

app.put('/api/warehouse-inward/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const inward = await prisma.warehouseInward.update({
      where: { id: parseInt(id) },
      data: req.body
    });
    res.json(inward);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to update inward entry' });
  }
});

app.put('/api/godowns/:id', async (req, res) => {
  try {
    const { name } = req.body;
    const godown = await prisma.godown.update({
      where: { id: parseInt(req.params.id) },
      data: { name },
    });
    res.json(godown);
  } catch (error) {
    if (error.code === 'P2002') return res.status(400).json({ error: 'Godown name already exists' });
    res.status(500).json({ error: 'Failed to update godown' });
  }
});

app.delete('/api/godowns/:id', async (req, res) => {
  try {
    await prisma.godown.delete({ where: { id: parseInt(req.params.id) } });
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: 'Failed to delete godown' });
  }
});

// ==============================
// GST SEARCH API (WhiteBooks Live)
// ==============================
app.get('/api/gst-search/:gstin', async (req, res) => {
  const { gstin: searchGstin } = req.params;
  
  if (searchGstin.length !== 15) {
    return res.status(400).json({ error: 'Invalid GSTIN format' });
  }

  try {
    const clientId = process.env.WHITEBOOKS_CLIENT_ID?.trim();
    const clientSecret = process.env.WHITEBOOKS_CLIENT_SECRET?.trim();
    const username = process.env.WHITEBOOKS_USERNAME?.trim(); 
    const password = process.env.WHITEBOOKS_PASSWORD?.trim(); 
    const gstin = process.env.WHITEBOOKS_GSTIN?.trim();
    const email = process.env.WHITEBOOKS_EMAIL?.trim();
    
    if (!clientId || !clientSecret || !username || !password || !email || !gstin) {
      throw new Error("Missing WhiteBooks Production Credentials in .env (including Email and GSTIN)");
    }

    // 1. Authenticate (Session mapped automatically by WhiteBooks)
    const authUrl = `https://api.whitebooks.in/ewaybillapi/v1.03/authenticate?email=${encodeURIComponent(email)}&username=${encodeURIComponent(username)}&password=${encodeURIComponent(password)}`;
    const authResponse = await fetch(authUrl, {
      method: "GET",
      headers: {
        "Content-Type": "application/json",
        "client_id": clientId,
        "client_secret": clientSecret,
        "gstin": gstin,
        "ip_address": "127.0.0.1"
      }
    });
    
    const authData = await authResponse.json();
    if (!authResponse.ok || authData.status_cd === "0") {
       const errMsg = authData.error ? authData.error.message : (authData.message || "Failed to authenticate with WhiteBooks.");
       throw new Error(`Authentication Failed: ${errMsg}`);
    }

    // 2. Fetch GST Details from E-Way Bill Gateway
    const url = `https://api.whitebooks.in/ewaybillapi/v1.03/ewayapi/getgstindetails?email=${encodeURIComponent(email)}&GSTIN=${searchGstin}`;
    const response = await fetch(url, {
      method: "GET",
      headers: {
        "Content-Type": "application/json",
        "client_id": clientId,
        "client_secret": clientSecret,
        "gstin": gstin,
        "ip_address": "127.0.0.1"
      }
    });
    const responseText = await response.text();
    const data = JSON.parse(responseText);

    if (!response.ok || data.status_cd === "0") {
      throw new Error((data.error && data.error.message) || data.message || `WhiteBooks API Error: ${response.status}`);
    }
    
    return await mapGstResponse(data, searchGstin, res);
  } catch (error) {
    logApiUsage('WhiteBooks', 'VAHAN RC Search', 'Success', 0.10); // ₹15,000 for 1,50,000 requests = 10 Paisa per call
    res.status(500).json({ error: error.message || 'Failed to fetch GST details from WhiteBooks' });
  }
});

const gstStateCodes = {
  "01": "Jammu and Kashmir", "02": "Himachal Pradesh", "03": "Punjab", "04": "Chandigarh",
  "05": "Uttarakhand", "06": "Haryana", "07": "Delhi", "08": "Rajasthan", "09": "Uttar Pradesh",
  "10": "Bihar", "11": "Sikkim", "12": "Arunachal Pradesh", "13": "Nagaland", "14": "Manipur",
  "15": "Mizoram", "16": "Tripura", "17": "Meghalaya", "18": "Assam", "19": "West Bengal",
  "20": "Jharkhand", "21": "Odisha", "22": "Chhattisgarh", "23": "Madhya Pradesh",
  "24": "Gujarat", "26": "Dadra and Nagar Haveli and Daman and Diu", "27": "Maharashtra",
  "28": "Andhra Pradesh", "29": "Karnataka", "30": "Goa", "31": "Lakshadweep", "32": "Kerala",
  "33": "Tamil Nadu", "34": "Puducherry", "35": "Andaman and Nicobar Islands",
  "36": "Telangana", "37": "Andhra Pradesh", "38": "Ladakh"
};

async function resolveLocationFromPincode(pincode) {
  if (!pincode) return { city: null, district: null };
  try {
    const response = await fetch(`http://www.postalpincode.in/api/pincode/${pincode}`);
    const data = await response.json();
    if (data.Status === "Success" && data.PostOffice && data.PostOffice.length > 0) {
      return {
        city: data.PostOffice[0].Taluk || data.PostOffice[0].Name || null,
        district: data.PostOffice[0].District || null
      };
    }
  } catch (err) {
    console.error("Pincode lookup error:", err.message);
  }
  return { city: null, district: null };
}

async function mapGstResponse(data, originalGstin, res) {
  console.log("WhiteBooks Full GST Response Data:", JSON.stringify(data, null, 2));
  
  const gstData = data.data || data;
  
  // Resolve State Name
  const rawStateCode = gstData.stateCode || gstData.pradr?.addr?.stcd || '';
  const stateName = gstStateCodes[rawStateCode] || rawStateCode;
  
  // Smart Location Resolution
  const pincode = gstData.pinCode || gstData.pradr?.addr?.pncd || '';
  let resolvedCity = gstData.city || gstData.pradr?.addr?.loc || '';
  let resolvedDistrict = '';
  
  if (pincode) {
    const loc = await resolveLocationFromPincode(pincode);
    if (!resolvedCity && loc.city) resolvedCity = loc.city;
    if (loc.district) resolvedDistrict = loc.district;
  }
  
  // Final fallback if the API fails
  if (!resolvedCity) {
    resolvedCity = gstData.address2 ? gstData.address2.replace(/[0-9]/g, '').trim() : '';
  }

  // Address Cleaner Engine
  const cleanAddressPart = (str) => {
    if (!str) return '';
    let s = str;
    if (pincode) s = s.replace(new RegExp(pincode, 'gi'), '');
    if (resolvedCity) s = s.replace(new RegExp(resolvedCity, 'gi'), '');
    if (resolvedDistrict) s = s.replace(new RegExp(resolvedDistrict, 'gi'), '');
    // Remove extra spaces and commas left behind
    return s.replace(/^[,\s]+|[,\s]+$/g, '').replace(/,\s*,/g, ',').replace(/\s+/g, ' ').trim();
  };

  let cleanAddr1 = cleanAddressPart(gstData.address1);
  let cleanAddr2 = cleanAddressPart(gstData.address2);
  
  let addr = [cleanAddr1, cleanAddr2].filter(Boolean).join(", ");
  
  // Fallback for non-EwayBill payload
  if (!addr && gstData.pradr && gstData.pradr.addr) {
    addr = [
      gstData.pradr.addr.bno, 
      gstData.pradr.addr.st, 
      gstData.pradr.addr.loc
    ].filter(Boolean).join(", ");
  }

  res.json({
    gstin: (gstData.gstin || searchGstin).toUpperCase(),
    tradeName: gstData.tradeName || gstData.tradeNam || gstData.lgnm || '',
    legalName: gstData.legalName || gstData.lgnm || '',
    address: addr || 'Address not available',
    city: resolvedCity,
    district: resolvedDistrict,
    state: stateName,
    pincode: pincode,
    status: gstData.status || gstData.sts || 'Active'
  });
}

// ==============================
// GC ENDPOINTS
// ==============================
app.get('/api/gcs', async (req, res) => {
  try {
    const gcs = await prisma.gC.findMany({ 
      orderBy: { id: 'desc' },
      include: {
        consignor: true,
        consignee: true,
        goods: true,
        gdm: {
          include: { vehicle: true }
        }
      }
    });
    res.json(gcs);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch GCs' });
  }
});

app.get('/api/gcs/:gcNumber', async (req, res) => {
  try {
    const gcNumberParam = req.params.gcNumber;
    
    // Support batch fetching for comma-separated GC numbers
    if (gcNumberParam.includes(',')) {
      const gcNumbers = gcNumberParam.split(',').map(n => n.trim()).filter(Boolean);
      const gcs = await prisma.gC.findMany({
        where: { gcNumber: { in: gcNumbers } },
        include: {
          consignor: true,
          consignee: true,
          goods: true,
        },
        orderBy: { gcNumber: 'asc' }
      });
      return res.json(gcs);
    }
    
    // Single fetching (backwards compatibility)
    const gc = await prisma.gC.findUnique({
      where: { gcNumber: gcNumberParam },
      include: {
        consignor: true,
        consignee: true,
        goods: true,
      }
    });
    if (!gc) return res.status(404).json({ error: 'GC not found' });
    res.json(gc);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch GC' });
  }
});

app.put('/api/gcs/:id/freight', async (req, res) => {
  try {
    const { freightFixed, freightType, freightRate, freightTotal, advancePaid, balanceFreight, freightNote } = req.body;
    
    const gc = await prisma.gC.update({
      where: { id: parseInt(req.params.id) },
      data: {
        freightFixed,
        freightType,
        freightRate: freightRate ? parseFloat(freightRate) : null,
        freightTotal: freightTotal ? parseFloat(freightTotal) : null,
        advancePaid: advancePaid ? parseFloat(advancePaid) : null,
        balanceFreight: balanceFreight ? parseFloat(balanceFreight) : null,
        freightNote
      }
    });
    res.json(gc);
  } catch (error) {
    res.status(500).json({ error: 'Failed to update GC Freight' });
  }
});

app.post('/api/gcs', async (req, res) => {
  try {
    const { goods, consignorGstin, consigneeGstin, consignorAddressPreview, consigneeAddressPreview, ...gcData } = req.body;
    
    // Parse numeric fields properly before saving
    if (gcData.freightRate) gcData.freightRate = parseFloat(gcData.freightRate);
    if (gcData.freightTotal) gcData.freightTotal = parseFloat(gcData.freightTotal);
    if (gcData.advancePaid) gcData.advancePaid = parseFloat(gcData.advancePaid);
    if (gcData.balanceFreight) gcData.balanceFreight = parseFloat(gcData.balanceFreight);
    if (gcData.invoiceValue) gcData.invoiceValue = parseFloat(gcData.invoiceValue);
    if (gcData.date) gcData.date = new Date(gcData.date);
    if (gcData.invoiceDate) gcData.invoiceDate = new Date(gcData.invoiceDate);

    const gc = await prisma.gC.create({
      data: {
        ...gcData,
        goods: {
          create: goods.map(item => ({
            articleCount: item.articles ? parseInt(item.articles) : null,
            units: item.units,
            hsn: item.hsn,
            godown: item.godown,
            description: item.description,
            weight: item.weight ? parseFloat(item.weight) : null,
            rate: item.rate ? parseFloat(item.rate) : null,
            amount: item.amount ? parseFloat(item.amount) : null,
          }))
        }
      },
      include: {
        goods: true
      }
    });
    res.json(gc);
  } catch (error) {
    console.error("Error creating GC:", error);
    if (error.code === 'P2002') {
      return res.status(400).json({ error: `GC Number ${req.body.gcNumber} already exists. Please use a unique number.` });
    }
    res.status(500).json({ error: error.message || 'Failed to create GC' });
  }
});

app.put('/api/gcs/:id', async (req, res) => {
  try {
    const { goods, consignorId, consigneeId, consignorGstin, consigneeGstin, consignorAddressPreview, consigneeAddressPreview, ...gcData } = req.body;
    
    // Parse numeric fields properly before saving
    if (gcData.freightRate) gcData.freightRate = parseFloat(gcData.freightRate);
    if (gcData.freightTotal) gcData.freightTotal = parseFloat(gcData.freightTotal);
    if (gcData.advancePaid) gcData.advancePaid = parseFloat(gcData.advancePaid);
    if (gcData.balanceFreight) gcData.balanceFreight = parseFloat(gcData.balanceFreight);
    if (gcData.invoiceValue) gcData.invoiceValue = parseFloat(gcData.invoiceValue);
    if (gcData.date) gcData.date = new Date(gcData.date);
    if (gcData.invoiceDate) gcData.invoiceDate = new Date(gcData.invoiceDate);

    const gc = await prisma.gC.update({
      where: { id: parseInt(req.params.id) },
      data: {
        ...gcData,
        consignor: { connect: { id: parseInt(consignorId) } },
        consignee: { connect: { id: parseInt(consigneeId) } },
        goods: {
          deleteMany: {}, // Delete all existing goods for this GC
          create: goods.map(item => ({
            articleCount: item.articles ? parseInt(item.articles) : null,
            units: item.units,
            hsn: item.hsn,
            godown: item.godown,
            description: item.description,
            weight: item.weight ? parseFloat(item.weight) : null,
            rate: item.rate ? parseFloat(item.rate) : null,
            amount: item.amount ? parseFloat(item.amount) : null,
          }))
        }
      },
      include: {
        goods: true
      }
    });
    res.json(gc);
  } catch (error) {
    console.error("Error updating GC:", error);
    if (error.code === 'P2002') {
      return res.status(400).json({ error: `GC Number ${req.body.gcNumber} already exists.` });
    }
    res.status(500).json({ error: error.message || 'Failed to update GC' });
  }
});

// --- GDM ENDPOINTS ---
app.get('/api/gdms', async (req, res) => {
  try {
    const gdms = await prisma.gDM.findMany({
      include: {
        vehicle: true,
        gcs: {
          include: {
            consignor: true,
            consignee: true,
            goods: true
          }
        }
      }
    });
    res.json(gdms);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch GDMs' });
  }
});

app.get('/api/gdms/:gdmNumber', async (req, res) => {
  try {
    const gdmNumberParam = req.params.gdmNumber;
    
    // Support batch fetching for comma-separated GDM numbers
    if (gdmNumberParam.includes(',')) {
      const gdmNumbers = gdmNumberParam.split(',').map(n => n.trim()).filter(Boolean);
      const gdms = await prisma.gDM.findMany({
        where: { gdmNumber: { in: gdmNumbers } },
        include: {
          vehicle: true,
          gcs: {
            include: {
              consignor: true,
              consignee: true,
              goods: true
            }
          }
        },
        orderBy: { gdmNumber: 'asc' }
      });
      return res.json(gdms);
    }
    
    // Single fetching
    const gdm = await prisma.gDM.findUnique({
      where: { gdmNumber: gdmNumberParam },
      include: {
        vehicle: true,
        gcs: {
          include: {
            consignor: true,
            consignee: true,
            goods: true
          }
        }
      }
    });
    if (!gdm) return res.status(404).json({ error: 'GDM not found' });
    res.json(gdm);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch GDM' });
  }
});

app.post('/api/gdms', async (req, res) => {
  try {
    const { 
      gdmNumber, date, time, vehicleId, driverName, driverPhone, startKm, 
      destination, fromLocation, toName, deliveryAt, memoAmount, advanceAmount, balanceAmount, gcIds 
    } = req.body;

    // 1. Create the GDM record
    const gdm = await prisma.gDM.create({
      data: {
        gdmNumber,
        date: date ? new Date(date) : null,
        time: time || null,
        vehicleId: vehicleId ? parseInt(vehicleId) : null,
        driverName: driverName || null,
        driverPhone: driverPhone || null,
        startKm: startKm !== undefined && startKm !== "" ? parseInt(startKm) : null,
        destination: destination || null,
        fromLocation: fromLocation || null,
        toName: toName || null,
        deliveryAt: deliveryAt || null,
        memoAmount: memoAmount !== undefined && memoAmount !== "" ? parseFloat(memoAmount) : null,
        advanceAmount: advanceAmount !== undefined && advanceAmount !== "" ? parseFloat(advanceAmount) : null,
        balanceAmount: balanceAmount !== undefined && balanceAmount !== "" ? parseFloat(balanceAmount) : null,
      }
    });

    // 2. Attach the selected GCs to this newly created GDM
    if (gcIds && gcIds.length > 0) {
      await prisma.gC.updateMany({
        where: { id: { in: gcIds.map(id => parseInt(id)) } },
        data: { gdmId: gdm.id, status: 'In Transit' }
      });
    }

    res.json(gdm);
  } catch (error) {
    console.error("Error creating GDM:", error);
    if (error.code === 'P2002') {
      return res.status(400).json({ error: `GDM Number ${req.body.gdmNumber} already exists.` });
    }
    res.status(500).json({ error: error.message || 'Failed to create GDM' });
  }
});
// ==============================
// UPDATE GDM
// ==============================
app.put('/api/gdms/:id', async (req, res) => {
  try {
    const gdmId = parseInt(req.params.id);
    const { 
      date, time, vehicleId, driverName, driverPhone, startKm, 
      destination, fromLocation, toName, deliveryAt, memoAmount, advanceAmount, balanceAmount, gcIds 
    } = req.body;

    // 1. Update the GDM record
    const gdm = await prisma.gDM.update({
      where: { id: gdmId },
      data: {
        date: date ? new Date(date) : null,
        time: time || null,
        vehicleId: vehicleId ? parseInt(vehicleId) : null,
        driverName: driverName || null,
        driverPhone: driverPhone || null,
        startKm: startKm !== undefined && startKm !== "" ? parseInt(startKm) : null,
        destination: destination || null,
        fromLocation: fromLocation || null,
        toName: toName || null,
        deliveryAt: deliveryAt || null,
        memoAmount: memoAmount !== undefined && memoAmount !== "" ? parseFloat(memoAmount) : null,
        advanceAmount: advanceAmount !== undefined && advanceAmount !== "" ? parseFloat(advanceAmount) : null,
        balanceAmount: balanceAmount !== undefined && balanceAmount !== "" ? parseFloat(balanceAmount) : null,
      }
    });

    // 2. Detach old GCs
    await prisma.gC.updateMany({
      where: { gdmId: gdmId },
      data: { gdmId: null, status: 'Created' }
    });

    // 3. Attach new GCs
    if (gcIds && gcIds.length > 0) {
      await prisma.gC.updateMany({
        where: { id: { in: gcIds.map(id => parseInt(id)) } },
        data: { gdmId: gdm.id, status: 'In Transit' }
      });
    }

    res.json(gdm);
  } catch (error) {
    console.error("Error updating GDM:", error);
    res.status(500).json({ error: error.message || 'Failed to update GDM' });
  }
});

// ==============================
// E-WAY BILL ENDPOINTS (WhiteBooks Live GSP)
// ==============================
app.get('/api/ewaybill/:ewaybillno', async (req, res) => {
  try {
    const ewaybillno = req.params.ewaybillno?.replace(/\s+/g, '');
    const priorityIsBell = req.query.company === 'BELL';
    
    // Credentials
    const clientId = process.env.WHITEBOOKS_CLIENT_ID?.trim();
    const clientSecret = process.env.WHITEBOOKS_CLIENT_SECRET?.trim();
    const email = process.env.WHITEBOOKS_EMAIL?.trim();
    
    if (!clientId || !clientSecret || !email) {
      throw new Error(`Missing WhiteBooks Core Credentials`);
    }

    async function attemptFetch(isBell) {
      let username, password, gstin;
      if (isBell) {
        username = process.env.BELL_WHITEBOOKS_USERNAME?.trim();
        password = process.env.BELL_WHITEBOOKS_PASSWORD?.trim();
        gstin = process.env.BELL_WHITEBOOKS_GSTIN?.trim();
      } else {
        username = process.env.WHITEBOOKS_USERNAME?.trim();
        password = process.env.WHITEBOOKS_PASSWORD?.trim();
        gstin = process.env.WHITEBOOKS_GSTIN?.trim() || process.env.TRANSPORTER_GSTIN?.trim();
      }

      if (!username || !password || !gstin) {
        throw new Error(`Missing WhiteBooks Credentials for ${isBell ? 'BELL' : 'AP'}`);
      }

      // 1. Authenticate
      const authUrl = `https://api.whitebooks.in/ewaybillapi/v1.03/authenticate?email=${encodeURIComponent(email)}&username=${encodeURIComponent(username)}&password=${encodeURIComponent(password)}`;
      const authResponse = await fetch(authUrl, {
        method: "GET",
        headers: { "Content-Type": "application/json", "client_id": clientId, "client_secret": clientSecret, "gstin": gstin, "ip_address": "127.0.0.1" }
      });
      
      const authData = await authResponse.json();
      if (!authResponse.ok || authData.status_cd === "0") {
         throw new Error(`Auth Failed for ${isBell ? 'BELL' : 'AP'}`);
      }

      // 2. Fetch E-Way Bill
      logApiUsage('WhiteBooks', 'Fetch E-Way Bill (NIC)', 'Success', 0.10); // ₹15,000 for 1,50,000 requests = 10 Paisa per call
      const ewbUrl = `https://api.whitebooks.in/ewaybillapi/v1.03/ewayapi/getewaybill?email=${encodeURIComponent(email)}&ewbNo=${ewaybillno}`;
      const response = await fetch(ewbUrl, {
        method: "GET",
        headers: { "Content-Type": "application/json", "client_id": clientId, "client_secret": clientSecret, "gstin": gstin, "ip_address": "127.0.0.1" }
      });

      const data = await response.json();
      if (!response.ok || data.status_cd === "0") {
        throw new Error(`EWB Fetch Failed for ${isBell ? 'BELL' : 'AP'}`);
      }
      return { ewb: data.data || data, detectedCompany: isBell ? 'B' : 'A' };
    }

    let result;
    try {
      // 1. Try the company they already selected in the UI first (Fastest)
      result = await attemptFetch(priorityIsBell);
    } catch (firstErr) {
      console.log(`Primary Fetch Failed (${priorityIsBell ? 'BELL' : 'AP'}):`, firstErr.message);
      try {
        // 2. Auto-fallback to the other company if the first one failed
        result = await attemptFetch(!priorityIsBell);
      } catch (secondErr) {
        console.log(`Fallback Fetch Failed (${!priorityIsBell ? 'BELL' : 'AP'}):`, secondErr.message);
        throw new Error("Could not retrieve E-Way bill from either AP or BELL. Please check the E-Way bill number.");
      }
    }

    const { ewb, detectedCompany } = result;
    console.log("DEBUG_EWB_RAW:", JSON.stringify(ewb));

    // 3. Map to existing frontend schema
    res.json({
      detectedCompany,
      ewayBillNo: ewb.ewbNo || ewaybillno,
      ewayBillDate: ewb.ewayBillDate || new Date().toISOString(),
      docNo: ewb.docNo || ewb.documentNo,
      docDate: ewb.docDate || ewb.documentDate,
      totInvValue: ewb.totInvValue,
      fromGstin: ewb.fromGstin,
      fromTrdName: ewb.fromTrdName || ewb.fromTradeName || ewb.transporterName,
      fromAddr1: ewb.fromAddr1 || ewb.fromAddress1,
      fromAddr2: ewb.fromAddr2 || ewb.fromAddress2,
      fromPlace: ewb.fromPlace || ewb.fromAddr2 || '',
      fromPincode: ewb.fromPincode,
      fromStateCode: ewb.fromStateCode,
      toGstin: ewb.toGstin,
      toTrdName: ewb.toTrdName || ewb.toTradeName,
      toAddr1: ewb.toAddr1 || ewb.toAddress1,
      toAddr2: ewb.toAddr2 || ewb.toAddress2,
      toPlace: ewb.toPlace || ewb.toAddr2 || '',
      toPincode: ewb.toPincode,
      toStateCode: ewb.toStateCode,
      itemList: ewb.itemList || []
    });

  } catch (error) {
    console.error("WhiteBooks API Error:", error.message);
    res.status(500).json({ error: error.message || 'Failed to fetch E-Way Bill details from WhiteBooks' });
  }
});

// Generate Consolidated E-Way Bill (CEWB)
app.post('/api/ewaybill/cewb', async (req, res) => {
  try {
    const { vehicleNo, fromPlace, transDocNo, transDocDate, ewbNos } = req.body;
    const isBell = req.query.company === 'BELL';
    
    // Select credentials
    const clientId = process.env.WHITEBOOKS_CLIENT_ID?.trim();
    const clientSecret = process.env.WHITEBOOKS_CLIENT_SECRET?.trim();
    const email = process.env.WHITEBOOKS_EMAIL?.trim();
    
    let username, password, gstin;
    if (isBell) {
      username = process.env.BELL_WHITEBOOKS_USERNAME?.trim();
      password = process.env.BELL_WHITEBOOKS_PASSWORD?.trim();
      gstin = process.env.BELL_WHITEBOOKS_GSTIN?.trim();
    } else {
      username = process.env.WHITEBOOKS_USERNAME?.trim();
      password = process.env.WHITEBOOKS_PASSWORD?.trim();
      gstin = process.env.WHITEBOOKS_GSTIN?.trim() || process.env.TRANSPORTER_GSTIN?.trim();
    }

    if (!clientId || !clientSecret || !username || !password || !email || !gstin) {
      throw new Error(`Missing WhiteBooks Credentials for ${isBell ? 'BELL' : 'AP'}`);
    }

    // 1. Authenticate
    const authUrl = `https://api.whitebooks.in/ewaybillapi/v1.03/authenticate?email=${encodeURIComponent(email)}&username=${encodeURIComponent(username)}&password=${encodeURIComponent(password)}`;
    const authResponse = await fetch(authUrl, {
      method: "GET",
      headers: {
        "Content-Type": "application/json",
        "client_id": clientId,
        "client_secret": clientSecret,
        "gstin": gstin,
        "ip_address": "127.0.0.1"
      }
    });
    
    const authData = await authResponse.json();
    if (!authResponse.ok || authData.status_cd === "0") {
       throw new Error("Authentication Failed: " + (authData.error?.message || "Check credentials."));
    }

    // 2. Build CEWB Payload
    const cewbPayload = {
      vehicleNo: vehicleNo,
      fromPlace: fromPlace || "Sivakasi",
      fromState: 33, // Default Tamil Nadu
      transMode: "1", // Road
      transDocNo: transDocNo,
      transDocDate: transDocDate,
      tripSheetEwbBills: ewbNos.map(no => ({ ewbNo: Number(no) }))
    };

    // 3. Post to WhiteBooks CEWB URL
    const cewbUrl = `https://api.whitebooks.in/ewaybillapi/v1.03/ewayapi/generatecewb?email=${encodeURIComponent(email)}`;
    const response = await fetch(cewbUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "client_id": clientId,
        "client_secret": clientSecret,
        "gstin": gstin,
        "AuthToken": authData.authtoken || authData.data?.authtoken || authData.AuthToken
      },
      body: JSON.stringify(cewbPayload)
    });
    
    const cewbData = await response.json();
    if (!response.ok || cewbData.status_cd === "0") {
      throw new Error(cewbData.error?.message || cewbData.message || "Failed to generate CEWB");
    }
    
    res.json(cewbData.data || cewbData);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ==========================================
// TRIPS & UNASSIGNED GDMS API
// ==========================================

// Get all unassigned GDMs (GDMs without a Trip)
app.get('/api/gdms-unassigned', async (req, res) => {
  try {
    const gdms = await prisma.gDM.findMany({
      where: { tripId: null },
      include: {
        vehicle: true,
        gcs: {
          include: {
            consignor: true,
            consignee: true
          }
        }
      },
      orderBy: { id: 'desc' }
    });
    res.json(gdms);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch unassigned GDMs' });
  }
});

// Create a new Trip and assign GDMs
app.post('/api/trips', async (req, res) => {
  try {
    const { 
      tripNumber, date, vehicleId, driverName, driverPhone, 
      lorryHire, advancePaid, balanceAmount, additions, deductions, remarks, gdmIds,
      sourcedBy, brokerName, loadingPayer, loadingCharge, commissionAmount, commissionDetails
    } = req.body;

    const trip = await prisma.trip.create({
      data: {
        tripNumber,
        date: date ? new Date(date) : new Date(),
        vehicleId,
        driverName,
        driverPhone,
        lorryHire: parseFloat(lorryHire) || 0,
        advancePaid: parseFloat(advancePaid) || 0,
        balanceAmount: parseFloat(balanceAmount) || 0,
        sourcedBy: sourcedBy || 'Direct',
        brokerName: brokerName || '',
        loadingPayer: loadingPayer || 'Transport',
        loadingCharge: parseFloat(loadingCharge) || 0,
        commissionAmount: parseFloat(commissionAmount) || 0,
        commissionDetails: commissionDetails || '',
        additions: parseFloat(additions) || 0,
        deductions: parseFloat(deductions) || 0,
        remarks,
        status: 'Active'
      }
    });

    if (gdmIds && gdmIds.length > 0) {
      await prisma.gDM.updateMany({
        where: { id: { in: gdmIds } },
        data: { tripId: trip.id }
      });
    }

    res.json({ message: 'Trip created successfully', trip });
  } catch (error) {
    res.status(500).json({ error: 'Failed to create Trip' });
  }
});

// Get all trips
app.get('/api/trips', async (req, res) => {
  try {
    const trips = await prisma.trip.findMany({
      include: {
        vehicle: true,
        gdms: {
          include: {
            gcs: {
              include: { consignee: true, goods: true }
            }
          }
        }
      },
      orderBy: { id: 'desc' }
    });
    res.json(trips);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch Trips' });
  }
});

// Settle Trip (Attach GDMs and Allocate Consignee Payments)
app.post('/api/trips/:id/settle', async (req, res) => {
  try {
    const tripId = parseInt(req.params.id);
    const { gdmIds, allocations, crossingAmount, returnAmount } = req.body;

    // 1. Attach GDMs to the Trip if not already attached
    if (gdmIds && gdmIds.length > 0) {
      await prisma.gDM.updateMany({
        where: { id: { in: gdmIds } },
        data: { tripId }
      });
    }

    // 2. Update GC allocations (paidToDriver, paidToTransport)
    if (allocations && Array.isArray(allocations)) {
      for (const alloc of allocations) {
        await prisma.gC.update({
          where: { id: alloc.gcId },
          data: {
            paidToDriver: alloc.paidToDriver || 0,
            paidToTransport: alloc.paidToTransport || 0
          }
        });
      }
    }

    // 3. Mark Trip as Settled and store Crossing/Return amounts
    const updatedTrip = await prisma.trip.update({
      where: { id: tripId },
      data: {
        status: 'Settled',
        crossingAmount: crossingAmount || 0,
        returnAmount: returnAmount || 0,
        settledDate: new Date()
      }
    });

    res.json({ message: 'Trip settled successfully', trip: updatedTrip });
  } catch (error) {
    console.error('Settlement Error:', error);
    res.status(500).json({ error: 'Failed to settle Trip' });
  }
});

// ==========================================
// PARTY ACCOUNTS (LEDGER & PAYMENTS)
// ==========================================

// Log a lump sum payment
app.post('/api/party-payments', async (req, res) => {
  try {
    const { partyType, partyId, amount, paymentMode, reference, remarks, date } = req.body;
    
    const payment = await prisma.partyPayment.create({
      data: {
        partyType,
        partyId: parseInt(partyId),
        amount: parseFloat(amount),
        paymentMode,
        reference,
        remarks,
        date: date ? new Date(date) : new Date()
      }
    });
    
    res.json({ message: 'Payment recorded successfully', payment });
  } catch (error) {
    console.error('Payment Error:', error);
    res.status(500).json({ error: 'Failed to record payment' });
  }
});

// Fetch running ledger for a party
app.get('/api/party-ledger/:partyType/:partyId', async (req, res) => {
  try {
    const partyType = req.params.partyType; // 'Consignee' or 'Consignor'
    const partyId = parseInt(req.params.partyId);

    // 1. Fetch all GCs for this party to build GC Debits & Credits
    const gcs = await prisma.gC.findMany({
      where: partyType === 'Consignee' ? { consigneeId: partyId } : { consignorId: partyId },
      include: {
        gdm: {
          include: { trip: true }
        }
      }
    });

    const ledgerEntries = [];

    gcs.forEach(gc => {
      // Create a Debit entry for the Freight
      const freight = parseFloat(gc.freightTotal) || 0;
      if (freight > 0) {
        ledgerEntries.push({
          id: `gc-debit-${gc.id}`,
          date: gc.date || new Date(),
          type: 'DEBIT',
          amount: freight,
          reference: `GC: ${gc.gcNumber}`,
          remarks: 'Freight Charges'
        });
      }

      // Create a Credit entry if paid to Driver during Trip Settlement
      const paidToDriver = parseFloat(gc.paidToDriver) || 0;
      if (paidToDriver > 0) {
        ledgerEntries.push({
          id: `gc-driver-${gc.id}`,
          date: gc.gdm?.trip?.settledDate || gc.gdm?.trip?.date || gc.date || new Date(),
          type: 'CREDIT',
          amount: paidToDriver,
          reference: `GC: ${gc.gcNumber}`,
          remarks: 'Paid to Driver (Trip Settlement)'
        });
      }

      // Create a Credit entry if paid to Us during Trip Settlement
      const paidToTransport = parseFloat(gc.paidToTransport) || 0;
      if (paidToTransport > 0) {
        ledgerEntries.push({
          id: `gc-us-${gc.id}`,
          date: gc.gdm?.trip?.settledDate || gc.gdm?.trip?.date || gc.date || new Date(),
          type: 'CREDIT',
          amount: paidToTransport,
          reference: `GC: ${gc.gcNumber}`,
          remarks: 'Paid to Us (Trip Settlement)'
        });
      }
    });

    // 2. Fetch all direct payments
    const payments = await prisma.partyPayment.findMany({
      where: { partyType, partyId }
    });

    payments.forEach(payment => {
      ledgerEntries.push({
        id: `pay-${payment.id}`,
        date: payment.date,
        type: 'CREDIT',
        amount: parseFloat(payment.amount),
        reference: payment.reference || `Payment: ${payment.paymentMode}`,
        remarks: payment.remarks
      });
    });

    // 3. Sort chronologically
    ledgerEntries.sort((a, b) => new Date(a.date) - new Date(b.date));

    // 4. Calculate running balance
    let runningBalance = 0;
    const ledgerWithBalance = ledgerEntries.map(entry => {
      if (entry.type === 'DEBIT') runningBalance += entry.amount;
      if (entry.type === 'CREDIT') runningBalance -= entry.amount;
      return { ...entry, balance: runningBalance };
    });

    res.json({ ledger: ledgerWithBalance, currentBalance: runningBalance });
  } catch (error) {
    console.error('Ledger Error:', error);
    res.status(500).json({ error: 'Failed to fetch ledger' });
  }
});

// ==========================================
// GODOWN PLANNER (VOICE AI SUPPORT)
// ==========================================
app.get('/api/godown-stock', async (req, res) => {
  try {
    const pendingGcs = await prisma.gC.findMany({
      where: { gdmId: null },
      include: {
        consignee: true,
        goods: true
      }
    });
    
    // Group by Consignee
    const stockMap = {};
    pendingGcs.forEach(gc => {
      const cId = gc.consignee?.id || 'unknown';
      if (!stockMap[cId]) {
        stockMap[cId] = {
          consigneeName: gc.consignee?.name || 'Unknown',
          totalGCs: 0,
          totalArticles: 0,
          totalWeight: 0,
          gcs: []
        };
      }
      stockMap[cId].totalGCs += 1;
      
      let articles = 0;
      let weight = 0;
      if (gc.goods && gc.goods.length > 0) {
        gc.goods.forEach(item => {
          articles += (item.articleCount || 0);
          weight += (item.weight || 0);
        });
      }
      stockMap[cId].totalArticles += articles;
      stockMap[cId].totalWeight += weight;
      stockMap[cId].gcs.push(gc.gcNumber);
    });

    const groupedStock = Object.values(stockMap);
    res.json(groupedStock);
  } catch (error) {
    console.error('Godown Error:', error);
    res.status(500).json({ error: 'Failed to fetch godown stock' });
  }
});

app.post('/api/godown-ai', async (req, res) => {
  try {
    const { audioData, mimeType, stockContext } = req.body;
    
    if (!process.env.GEMINI_API_KEY) {
      return res.status(500).json({ reply: 'Gemini API key is missing in backend.' });
    }

    const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
    const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });

    // The prompt instructs the AI how to act and enforces JSON output
    const prompt = `
      You are a helpful Tamil warehouse assistant for a 70-year-old owner.
      He will ask a question about the pending godown stock (in the attached Tamil audio).
      Here is the current live stock data: ${JSON.stringify(stockContext)}
      
      Listen to the audio. Figure out which consignee or total he is asking about.
      You MUST reply ONLY with a JSON object in this exact format. Do not use markdown blocks (\`\`\`json):
      {
        "reply": "The short, natural, polite Tamil sentence answering his question. Use numbers clearly.",
        "filteredConsignees": ["Exact Consignee Name 1", "Exact Consignee Name 2"] 
      }
      Rule: 'filteredConsignees' should be an array of the exact consigneeName strings from the data that match his query. Leave it empty [] if he asks for total/all.
    `;

    // Convert base64 audio to Gemini Part object
    const audioPart = {
      inlineData: {
        data: audioData.split(',')[1] || audioData, // strip "data:audio/webm;base64,"
        mimeType: mimeType || 'audio/webm'
      }
    };

    const result = await model.generateContent([prompt, audioPart]);
    const response = await result.response;
    let responseText = response.text().trim();
    
    // Strip markdown if the AI includes it despite instructions
    if (responseText.startsWith('\`\`\`json')) {
      responseText = responseText.replace(/\`\`\`json/g, '').replace(/\`\`\`/g, '').trim();
    }
    if (responseText.startsWith('\`\`\`')) {
       responseText = responseText.replace(/\`\`\`/g, '').trim();
    }

    const aiJson = JSON.parse(responseText);
    const textReply = aiJson.reply;
    const filteredConsignees = aiJson.filteredConsignees || [];

    let audioBase64 = null;
    
    // If Google Cloud TTS is configured, convert text to premium audio
    if (process.env.GOOGLE_CLOUD_API_KEY) {
      try {
        const ttsRes = await fetch(`https://texttospeech.googleapis.com/v1/text:synthesize?key=${process.env.GOOGLE_CLOUD_API_KEY}`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            input: { text: textReply },
            voice: { languageCode: 'ta-IN', name: 'ta-IN-Standard-B' }, // High quality Male Tamil Voice
            audioConfig: { audioEncoding: 'MP3' }
          })
        });
        
        if (ttsRes.ok) {
          const ttsData = await ttsRes.json();
          audioBase64 = ttsData.audioContent;
        } else {
          console.error("TTS Failed", await ttsRes.text());
        }
      } catch (ttsErr) {
        console.error("TTS Request Error", ttsErr);
      }
    }

    res.json({ reply: textReply, audioBase64, filteredConsignees });
  } catch (error) {
    console.error('AI Error:', error);
    res.status(500).json({ reply: "மன்னிக்கவும், AI சிஸ்டமில் பிழை ஏற்பட்டுள்ளது. (AI System Error)" });
  }
});

// ==========================================
// DAILY ACCOUNTS (EXPENSES & INCOME)
// ==========================================

// Get all daily transactions (with optional date filtering later)
app.get('/api/daily-transactions', async (req, res) => {
  try {
    const transactions = await prisma.dailyTransaction.findMany({
      orderBy: { date: 'desc' }
    });
    res.json(transactions);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch transactions' });
  }
});

// Create a new daily transaction
app.post('/api/daily-transactions', async (req, res) => {
  try {
    const { date, type, category, amount, paymentMode, description, reference } = req.body;
    const transaction = await prisma.dailyTransaction.create({
      data: {
        date: date ? new Date(date) : new Date(),
        type,
        category,
        amount: parseFloat(amount) || 0,
        paymentMode,
        description,
        reference
      }
    });
    res.json(transaction);
  } catch (error) {
    res.status(500).json({ error: 'Failed to record transaction' });
  }
});

// Delete a daily transaction
app.delete('/api/daily-transactions/:id', async (req, res) => {
  try {
    const { id } = req.params;
    await prisma.dailyTransaction.delete({
      where: { id: parseInt(id) }
    });
    res.json({ message: 'Transaction deleted successfully' });
  } catch (error) {
    res.status(500).json({ error: 'Failed to delete transaction' });
  }
});

server.listen(PORT, () => {
  console.log(`Server is running on http://localhost:${PORT}`);
});
