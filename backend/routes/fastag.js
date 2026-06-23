const express = require('express');
const axios = require('axios');
const xml2js = require('xml2js');
const router = express.Router();

// Define the API route for FASTag tracking
router.post('/track', async (req, res) => {
  const { vehicleNumber } = req.body;

  if (!vehicleNumber) {
    return res.status(400).json({ error: 'Vehicle number is required' });
  }

  // Use the company ID from environment variables, or fallback to the one provided
  const companyId = process.env.FASTAG_COMPANY_ID || '6a34b131bddbed7aa5d9a373';

  try {
    const response = await axios.post(
      'https://fastagtracking.com/qiktrack/trackingApi',
      {
        company_id: companyId,
        tracking_For: 'FASTAG',
        parameters: {
          vehiclenumber: vehicleNumber
        }
      },
      {
        headers: {
          'Content-Type': 'application/json'
        }
      }
    );

    // The API returns { response: [...], error: "false", ... }
    if (response.data.error === "true") {
      return res.status(400).json({ error: response.data.message || 'Error tracking vehicle' });
    }

    res.json({ success: true, data: response.data.response });
  } catch (error) {
    console.error('Error in FASTag API:', error.message);
    res.status(500).json({ error: 'Failed to fetch FASTag data' });
  }
});

// Define the API route for RC Verification (VAHAN)
router.post('/rc', async (req, res) => {
  const { vehicleNumber } = req.body;

  if (!vehicleNumber) {
    return res.status(400).json({ error: 'Vehicle number is required' });
  }

  const companyId = process.env.FASTAG_COMPANY_ID || '6a34b131bddbed7aa5d9a373';

  try {
    const response = await axios.post(
      'https://fastagtracking.com/qiktrack/trackingApi',
      {
        company_id: companyId,
        tracking_For: 'VAHAN',
        parameters: {
          vehiclenumber: vehicleNumber
        }
      },
      { headers: { 'Content-Type': 'application/json' } }
    );

    if (response.data.error === "true" || !response.data.response || response.data.response.length === 0) {
      return res.status(400).json({ error: response.data.message || 'Error fetching RC data' });
    }

    const xmlData = response.data.response[0]?.response;
    if (!xmlData) {
      return res.status(400).json({ error: 'Invalid or empty response from VAHAN API' });
    }

    // Parse XML
    const parser = new xml2js.Parser({ explicitArray: false });
    const result = await parser.parseStringPromise(xmlData);

    if (!result || !result.VehicleDetails) {
       return res.status(400).json({ error: 'Could not parse RC details' });
    }

    res.json({ success: true, data: result.VehicleDetails });
  } catch (error) {
    console.error('Error in VAHAN API:', error.message);
    res.status(500).json({ error: 'Failed to fetch VAHAN data' });
  }
});

// Define the API route for Driving License Verification (SARATHI)
router.post('/dl', async (req, res) => {
  const { dlNumber, dob } = req.body;

  if (!dlNumber || !dob) {
    return res.status(400).json({ error: 'Driving License number and DOB are required' });
  }

  const companyId = process.env.FASTAG_COMPANY_ID || '6a34b131bddbed7aa5d9a373';

  try {
    const response = await axios.post(
      'https://fastagtracking.com/qiktrack/tracking-Api',
      {
        company_id: companyId,
        tracking_For: 'SARATHI',
        parameters: {
          dlnumber: dlNumber,
          dob: dob
        }
      },
      { headers: { 'Content-Type': 'application/json' } }
    );

    if (response.data.error === "true" || !response.data.response || response.data.response.length === 0) {
      return res.status(400).json({ error: response.data.message || 'Error fetching DL data' });
    }

    const rawData = response.data.response[0]?.response;

    if (!rawData || !rawData.personalInformation?.name) {
      return res.status(400).json({ error: 'DL Not Found in SARATHI database. Please verify the License Number and Date of Birth.' });
    }

    const dlData = {
      dl_number: rawData.licenseInformation?.licenseNumber || dlNumber.toUpperCase(),
      owner_name: rawData.personalInformation?.name || rawData.ownerName || 'UNKNOWN',
      father_name: rawData.personalInformation?.fatherName || rawData.fatherName || '',
      dob: dob,
      blood_group: rawData.personalInformation?.bloodGroup || rawData.bloodGroup || '',
      rto: rawData.licenseInformation?.issuedAuthority || rawData.rto || '',
      status: rawData.licenseInformation?.status?.toUpperCase() || rawData.status || 'UNKNOWN',
      validity_nt: rawData.licenseInformation?.validity?.nonTransport || rawData.validity_nt || '-',
      validity_tr: rawData.licenseInformation?.validity?.transport || rawData.validity_tr || '-',
      vehicle_classes: rawData.drivingClasses ? rawData.drivingClasses.map(c => c.class) : (rawData.vehicle_classes || [])
    };

    res.json({ success: true, data: dlData, raw: rawData });
  } catch (error) {
    console.error('Error in DL API:', error.message);
    res.status(500).json({ error: 'Failed to verify Driving License' });
  }
});

module.exports = router;
