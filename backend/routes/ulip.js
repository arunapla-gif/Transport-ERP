const express = require('express');
const router = express.Router();

// Placeholder Base URL for the Third-Party ULIP Provider (e.g., AppyFlow, SurePass, etc.)
// Or the direct GOULIP.in production endpoint
const ULIP_API_BASE = process.env.ULIP_API_BASE || 'https://api.ulip.placeholder.com';
const ULIP_API_KEY = process.env.ULIP_API_KEY || 'your_ulip_api_key_here';

const getHeaders = () => ({
  'Content-Type': 'application/json',
  'Authorization': `Bearer ${ULIP_API_KEY}`,
  // If using direct ULIP, might require encryption headers
});

/**
 * 1. VAHAN API - Vehicle Verification
 * Used to fetch Registration Date, Fitness, Insurance, Owner Name from Lorry Number.
 */
router.post('/vahan/verify', async (req, res) => {
  const { lorryNo } = req.body;
  if (!lorryNo) return res.status(400).json({ error: 'Lorry Number is required' });

  try {
    // TODO: Replace with actual ULIP/Vendor Vahan Endpoint
    // const response = await axios.get(`${ULIP_API_BASE}/vahan/${lorryNo}`, { headers: getHeaders() });
    
    // Mock response for development until keys are provided
    const mockData = {
      lorryNo: lorryNo.toUpperCase(),
      ownerName: "PENDING ULIP INTEGRATION",
      fitnessValidUpto: "2025-12-31",
      insuranceValidUpto: "2024-12-31",
      vehicleClass: "HEAVY GOODS VEHICLE",
      fuelType: "DIESEL",
      rcStatus: "ACTIVE"
    };

    res.json({ success: true, data: mockData });
  } catch (error) {
    console.error("Vahan API Error:", error.message);
    res.status(500).json({ error: 'Failed to verify vehicle data from Vahan' });
  }
});

/**
 * 2. SARATHI API - Driver License Verification
 * Used to verify if a Driver's License is valid and check driver history.
 */
router.post('/sarathi/verify', async (req, res) => {
  const { dlNumber, dob } = req.body;
  if (!dlNumber) return res.status(400).json({ error: 'DL Number is required' });

  try {
    // TODO: Replace with actual ULIP/Vendor Sarathi Endpoint
    
    const mockData = {
      dlNumber: dlNumber.toUpperCase(),
      driverName: "PENDING ULIP INTEGRATION",
      validUpto: "2030-01-01",
      status: "ACTIVE",
      vehicleClasses: ["LMV", "TRANS"]
    };

    res.json({ success: true, data: mockData });
  } catch (error) {
    console.error("Sarathi API Error:", error.message);
    res.status(500).json({ error: 'Failed to verify Driver License' });
  }
});

/**
 * 3. FASTAG TRACKING API - Vahan Location via Tolls
 * Used to get the last known toll plaza crossed by the vehicle.
 */
router.post('/fastag/track', async (req, res) => {
  const { lorryNo } = req.body;
  if (!lorryNo) return res.status(400).json({ error: 'Lorry Number is required' });

  try {
    // TODO: Replace with actual ULIP/Vendor FASTag Tracking Endpoint
    
    const mockData = {
      lorryNo: lorryNo.toUpperCase(),
      lastTollPlaza: "Kappalur Toll Plaza, Madurai",
      crossedAt: new Date().toISOString(),
      direction: "South to North"
    };

    res.json({ success: true, data: mockData });
  } catch (error) {
    console.error("FASTag API Error:", error.message);
    res.status(500).json({ error: 'Failed to track FASTag location' });
  }
});

module.exports = router;
