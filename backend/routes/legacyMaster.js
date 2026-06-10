const express = require('express');
const router = express.Router();
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// GET all staged legacy master data
router.get('/', async (req, res) => {
  try {
    const data = await prisma.legacyMaster.findMany({
      orderBy: { createdAt: 'desc' }
    });
    res.json(data);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// POST to upload initial data from Excel
router.post('/upload', async (req, res) => {
  try {
    const { rows, partyType } = req.body; // rows should be an array of objects
    
    // Map excel columns to legacyMaster columns
    const mappedData = rows.map(row => ({
      partyType,
      oldId: String(row['ID'] || row['id'] || ''),
      oldName: String(row['Consignor Name'] || row['Name'] || row['name'] || ''),
      oldAddress: String(row['Address line1'] || row['address'] || ''),
      oldCity: String(row['City / Village'] || row['city'] || ''),
      oldGstin: String(row['GSTIN'] || row['gstin'] || ''),
      oldPhone: String(row['Contact1'] || row['phone'] || ''),
      status: 'PENDING'
    }));

    const result = await prisma.legacyMaster.createMany({
      data: mappedData,
      skipDuplicates: true
    });

    res.json({ message: 'Data uploaded to staging successfully', count: result.count });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// POST to fetch API data for a specific record
router.post('/fetch-api/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const record = await prisma.legacyMaster.findUnique({ where: { id: Number(id) } });
    
    if (!record || !record.oldGstin) {
      return res.status(400).json({ error: 'Record not found or GSTIN is missing' });
    }

    const gstin = record.oldGstin.trim();
    let apiName, apiAddress, apiCity, apiState, apiPincode, provider;

    // Fetch directly from AppyFlow
    const keySecret = process.env.APPYFLOW_KEY_SECRET || '7eWP3WelRNexYGJ172L3Hb8JNrY2';
    const wbResponse = await fetch(`https://appyflow.in/api/verifyGST?gstNo=${gstin}&key_secret=${keySecret}`);
    
    if (!wbResponse.ok) {
       throw new Error("AppyFlow fetch failed or GSTIN is invalid");
    }
    
    const wbData = await wbResponse.json();
    
    if (wbData.error) {
       throw new Error(wbData.message || 'Invalid GST');
    }
    
    const info = wbData.taxpayerInfo;
    if (!info) throw new Error('No taxpayer info found');

    const addr = info.pradr?.addr || {};
    const companyName = info.tradeNam || info.lgnm || '';
    
    const cleanAddressParts = (parts) => {
      let joined = parts.filter(Boolean).join(', ');
      if (!companyName) return joined;
      try {
        const cleanName = companyName.replace(/[^a-zA-Z0-9 ]/g, '').trim();
        if (cleanName) {
          const regexPattern = cleanName.split(/\s+/).join('\\s*[^a-zA-Z0-9]*\\s*');
          const regex = new RegExp('^' + regexPattern + '\\s*[^a-zA-Z0-9]*\\s*', 'i');
          joined = joined.replace(regex, '');
        }
      } catch (e) {}
      return joined;
    };

    const apiLegalName = info.lgnm || '';
    const rawTradeName = info.tradeNam || '';
    const apiTradeNames = rawTradeName ? [rawTradeName] : [];
    
    apiName = companyName;
    apiAddress = cleanAddressParts([addr.bno, addr.bnm, addr.st, addr.flno]);
    apiCity = addr.loc || addr.city || '';
    const apiDistrict = addr.dst || '';
    apiState = addr.stcd || '';
    apiPincode = addr.pncd || addr.pincode || '';
    
    const apiAddresses = (info.adadr || []).map(a => {
      const adr = a.addr || {};
      return {
        address: cleanAddressParts([adr.bno, adr.bnm, adr.st, adr.flno]),
        city: adr.loc || adr.city || '',
        district: adr.dst || '',
        state: adr.stcd || '',
        pincode: adr.pncd || adr.pincode || ''
      };
    });
    
    provider = 'APPYFLOW';

    const updatedRecord = await prisma.legacyMaster.update({
      where: { id: Number(id) },
      data: {
        apiName, apiAddress, apiCity, apiDistrict, apiState, apiPincode, apiAddresses, apiLegalName, apiTradeNames, provider, status: 'READY'
      }
    });

    res.json(updatedRecord);
  } catch (error) {
    // If both APIs fail or network error
    await prisma.legacyMaster.update({
      where: { id: Number(req.params.id) },
      data: { status: 'FAILED_FETCH' }
    });
    res.status(500).json({ error: error.message });
  }
});

// POST to approve and move to live Master
router.post('/approve/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { useApiData, mergeTradeName } = req.body;
    
    const record = await prisma.legacyMaster.findUnique({ where: { id: Number(id) } });
    if (!record) return res.status(404).json({ error: 'Record not found' });

    // Determine final values based on user's choice
    let finalName = record.oldName;
    if (useApiData) {
      if (mergeTradeName) {
        // Only merge if the old name is meaningfully different from the API name
        const cleanApi = (record.apiName || '').toUpperCase().replace(/[^A-Z0-9]/g, '');
        const cleanOld = (record.oldName || '').toUpperCase().replace(/[^A-Z0-9]/g, '');
        
        if (cleanApi && cleanOld && cleanApi !== cleanOld && !cleanApi.includes(cleanOld) && !cleanOld.includes(cleanApi)) {
          finalName = `${record.apiName} (${record.oldName})`;
        } else {
          finalName = record.apiName;
        }
      } else {
        finalName = record.apiName;
      }
    }
    const finalAddress = useApiData ? record.apiAddress : record.oldAddress;
    const finalCity = useApiData ? record.apiCity : record.oldCity;
    const finalDistrict = useApiData ? record.apiDistrict : null;
    const finalState = useApiData ? record.apiState : '';
    const finalPincode = useApiData ? record.apiPincode : '';
    const finalAddresses = useApiData ? (record.apiAddresses || []) : [];
    const finalTradeNames = useApiData ? (record.apiTradeNames || []) : [];
    const finalLegalName = useApiData ? record.apiLegalName : null;
    
    let migrationType = 'OLD_DATA_ONLY';
    if (useApiData) {
      migrationType = mergeTradeName ? 'MERGED_NAME' : 'API_ONLY';
    }
    
    // Save to actual table
    const safeName = finalName || 'Unknown';
    if (record.partyType === 'CONSIGNOR') {
      const existing = await prisma.consignor.findUnique({ where: { name: safeName } });
      if (!existing) {
        await prisma.consignor.create({
          data: {
            name: safeName,
            address: finalAddress,
            city: finalCity,
            district: finalDistrict,
            state: finalState,
            pincode: finalPincode,
            gstin: record.oldGstin,
            phone: record.oldPhone,
            migrationType,
            addresses: finalAddresses,
            tradeNames: finalTradeNames,
            legalName: finalLegalName
          }
        });
      }
    } else {
      const existing = await prisma.consignee.findUnique({ where: { name: safeName } });
      if (!existing) {
        await prisma.consignee.create({
          data: {
            name: safeName,
            address: finalAddress,
            city: finalCity,
            district: finalDistrict,
            state: finalState,
            pincode: finalPincode,
            gstin: record.oldGstin,
            phone: record.oldPhone,
            migrationType,
            addresses: finalAddresses,
            tradeNames: finalTradeNames,
            legalName: finalLegalName
          }
        });
      }
    }

    // Mark as approved in staging
    await prisma.legacyMaster.update({
      where: { id: Number(id) },
      data: { status: 'APPROVED' }
    });

    // Invalidate the fast memory cache so the UI sees the new records
    if (global.clearMasterCache) {
      if (record.partyType === 'CONSIGNOR') global.clearMasterCache('consignors');
      if (record.partyType === 'CONSIGNEE') global.clearMasterCache('consignees');
    }

    res.json({ message: 'Successfully migrated to live master' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;
