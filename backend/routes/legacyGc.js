const express = require('express');
const router = express.Router();
const xlsx = require('xlsx');
const path = require('path');
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

let book1Cache = null;
let book2Cache = null;

function getBooksData() {
  if (book1Cache && book2Cache) return { book1Cache, book2Cache };
  
  book1Cache = {};
  book2Cache = {};
  
  try {
    const wb1 = xlsx.readFile(path.join(__dirname, '..', '..', 'Book1.xlsx'));
    const d1 = xlsx.utils.sheet_to_json(wb1.Sheets[wb1.SheetNames[0]]);
    d1.forEach(row => {
      const name = String(row['Name'] || row['name'] || '').trim().toUpperCase();
      if (name) {
        book1Cache[name] = {
          address: String(row['Address line1'] || ''),
          city: String(row['City / Village'] || ''),
          gstin: String(row['GSTIN'] || ''),
          phone: String(row['Contact1'] || '')
        };
      }
    });
  } catch (e) { console.error("Error loading Book1.xlsx", e); }

  try {
    const wb2 = xlsx.readFile(path.join(__dirname, '..', '..', 'Book2.xlsx'));
    const d2 = xlsx.utils.sheet_to_json(wb2.Sheets[wb2.SheetNames[0]]);
    d2.forEach(row => {
      const name = String(row['Consignor Name'] || row['Name'] || '').trim().toUpperCase();
      if (name) {
        book2Cache[name] = {
          address: String(row['Address line1'] || ''),
          city: String(row['City / Village'] || ''),
          gstin: String(row['GSTIN'] || ''),
          phone: String(row['Contact1'] || '')
        };
      }
    });
  } catch (e) { console.error("Error loading Book2.xlsx", e); }
  
  return { book1Cache, book2Cache };
}

router.get('/preview', async (req, res) => {
  try {
    const filePath = path.join(__dirname, '..', '..', 'gc 4.5-3.6.xlsx');
    const workbook = xlsx.readFile(filePath);
    const sheetName = workbook.SheetNames[0];
    const sheet = workbook.Sheets[sheetName];
    const allData = xlsx.utils.sheet_to_json(sheet);
    
    // Filter to ONLY include GCs that are pending in Godown (Closing stock > 0)
    const pendingData = allData.filter(row => Number(row['Closing']) > 0);
    
    const data = pendingData.slice(0, 300); // 300 records for preview
    
    // Fetch existing master names to check for matches
    const allConsignors = await prisma.consignor.findMany({ select: { name: true } });
    const allConsignees = await prisma.consignee.findMany({ select: { name: true } });
    const allImportedGcs = await prisma.gC.findMany({ 
      where: { gcNumber: { startsWith: 'LEGACY-' } },
      select: { gcNumber: true }
    });
    
    const consignorSet = new Set(allConsignors.map(c => c.name.toUpperCase()));
    const consigneeSet = new Set(allConsignees.map(c => c.name.toUpperCase()));
    const importedGcSet = new Set(allImportedGcs.map(g => g.gcNumber));

    const augmentedData = data.map((row, index) => {
      const gcNoStr = String(row['GC No']).trim();
      const rawGcNo = `LEGACY-${gcNoStr}`;
      const cnorName = row['Consignor'] ? String(row['Consignor']).trim() : '';
      const cneeName = row['Consingee'] ? String(row['Consingee']).trim() : '';
      
      return {
        id: index,
        gcNo: row['GC No'],
        date: row['GC Date'],
        lorry: row['Despatch Lorry'],
        consignor: cnorName,
        consignee: cneeName,
        consignorExists: consignorSet.has(cnorName.toUpperCase()),
        consigneeExists: consigneeSet.has(cneeName.toUpperCase()),
        status: importedGcSet.has(rawGcNo) ? 'APPROVED' : 'PENDING',
        rawData: row
      };
    });

    res.json(augmentedData);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

router.post('/approve', async (req, res) => {
  try {
    const { rawData, consignorId, consigneeId } = req.body;
    if (!rawData || !rawData['GC No']) return res.status(400).json({ error: 'Missing GC Data' });
    if (!consignorId || !consigneeId) return res.status(400).json({ error: 'Missing Mapped Consignor or Consignee ID' });

    const row = rawData;
    const gcNumberStr = String(row['GC No']).trim();
    const rawGcNo = `LEGACY-${gcNumberStr}`;

    const existing = await prisma.gC.findUnique({ where: { gcNumber: rawGcNo } });
    if (existing) return res.json({ message: 'Already approved' });

    const lorryNo = row['Despatch Lorry'] ? String(row['Despatch Lorry']).trim() : null;
    const gdmNoStr = row['Despatch No'] ? String(row['Despatch No']).trim() : null;

    // We already have cnor and cnee IDs passed securely from the frontend mapper!
    let cnor = { id: parseInt(consignorId) };
    let cnee = { id: parseInt(consigneeId) };

    // 3. Get or Create Vehicle
    let vehId = null;
    if (lorryNo) {
      let veh = await prisma.vehicle.findUnique({ where: { vehicleNumber: lorryNo } });
      if (!veh) veh = await prisma.vehicle.create({ data: { vehicleNumber: lorryNo } });
      vehId = veh.id;
    }

    // 4. Get or Create GDM
    let gdmId = null;
    if (gdmNoStr) {
      const fullGdmNo = `LEGACY-GDM-${gdmNoStr}`;
      let gdm = await prisma.gDM.findUnique({ where: { gdmNumber: fullGdmNo } });
      if (!gdm) {
        const dispDateStr = row['Despatch Date'];
        let parsedDate = new Date();
        if (dispDateStr && String(dispDateStr).includes('-')) {
          parsedDate = new Date(String(dispDateStr).split('-').reverse().join('-'));
        }
        gdm = await prisma.gDM.create({
          data: {
            gdmNumber: fullGdmNo,
            date: parsedDate,
            status: 'Dispatched',
            vehicleId: vehId
          }
        });
      }
      gdmId = gdm.id;
    }

    // 5. Create GC
    const closing = Number(row['Closing']) || 0;
    const opening = Number(row['Opening']) || 0;
    const status = closing === 0 ? 'Dispatched' : 'Created'; 
    
    const gcDateStr = row['GC Date'];
    let gcDate = new Date();
    if (gcDateStr && String(gcDateStr).includes('-')) {
      gcDate = new Date(String(gcDateStr).split('-').reverse().join('-'));
    }

    await prisma.gC.create({
      data: {
        gcNumber: rawGcNo,
        financialYear: row['Fin Year'] || '2026-2027',
        date: gcDate,
        time: row['Time'] || '',
        status: status,
        consignorId: cnor.id,
        consigneeId: cnee.id,
        godown: 'Godown 1',
        gdmId: gdmId,
        goods: {
          create: [
            {
              articleCount: opening,
              units: row['Unit'] || 'Cases',
              description: row['Goods type'] || 'General Goods'
            }
          ]
        }
      }
    });

    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
