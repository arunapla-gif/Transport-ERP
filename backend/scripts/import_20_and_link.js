const { PrismaClient } = require('@prisma/client');
const xlsx = require('xlsx');
const path = require('path');

const prisma = new PrismaClient();

async function import20() {
  try {
    const filePath = path.join(__dirname, '..', 'gc 4.5-3.6.xlsx');
    console.log(`Loading Excel file: ${filePath}`);
    const workbook = xlsx.readFile(filePath);
    const sheetName = workbook.SheetNames[0];
    const sheet = workbook.Sheets[sheetName];
    const data = xlsx.utils.sheet_to_json(sheet).slice(0, 20); // ONLY FIRST 20!
    
    console.log(`Found ${data.length} records to import and link.`);
    
    let stats = {
      consignorsAdded: 0,
      consigneesAdded: 0,
      vehiclesAdded: 0,
      gcsAdded: 0,
      gdmsAdded: 0
    };

    // Preload caches
    const allConsignors = await prisma.consignor.findMany({ select: { id: true, name: true } });
    const allConsignees = await prisma.consignee.findMany({ select: { id: true, name: true } });
    const allVehicles = await prisma.vehicle.findMany({ select: { id: true, vehicleNumber: true } });
    
    const cache = {
      consignors: Object.fromEntries(allConsignors.map(c => [c.name, c.id])),
      consignees: Object.fromEntries(allConsignees.map(c => [c.name, c.id])),
      vehicles: Object.fromEntries(allVehicles.map(v => [v.vehicleNumber, v.id])),
      gdms: {}
    };

    for (let i = 0; i < data.length; i++) {
      const row = data[i];
      if (!row['GC No']) continue; 
      
      const gcNumberStr = String(row['GC No']).trim();
      const rawGcNo = `LEGACY-${gcNumberStr}`; 
      
      // Skip if already exists
      const existing = await prisma.gC.findUnique({ where: { gcNumber: rawGcNo } });
      if (existing) continue;

      const consignorName = row['Consignor'] ? String(row['Consignor']).trim() : 'UNKNOWN CONSIGNOR';
      const consigneeName = row['Consingee'] ? String(row['Consingee']).trim() : 'UNKNOWN CONSIGNEE';
      const lorryNo = row['Despatch Lorry'] ? String(row['Despatch Lorry']).trim() : null;
      const gdmNoStr = row['Despatch No'] ? String(row['Despatch No']).trim() : null;
      
      // 1. Get or Create Consignor
      let cnorId = cache.consignors[consignorName];
      if (!cnorId) {
        let cnor = await prisma.consignor.create({ data: { name: consignorName } });
        stats.consignorsAdded++;
        cnorId = cnor.id;
        cache.consignors[consignorName] = cnorId;
      }

      // 2. Get or Create Consignee
      let cneeId = cache.consignees[consigneeName];
      if (!cneeId) {
        let cnee = await prisma.consignee.create({ data: { name: consigneeName } });
        stats.consigneesAdded++;
        cneeId = cnee.id;
        cache.consignees[consigneeName] = cneeId;
      }

      // 3. Get or Create Vehicle
      let vehId = null;
      if (lorryNo) {
        vehId = cache.vehicles[lorryNo];
        if (!vehId) {
          let veh = await prisma.vehicle.create({ data: { vehicleNumber: lorryNo } });
          stats.vehiclesAdded++;
          vehId = veh.id;
          cache.vehicles[lorryNo] = vehId;
        }
      }

      // 4. Get or Create GDM
      let gdmId = null;
      if (gdmNoStr) {
        const fullGdmNo = `LEGACY-GDM-${gdmNoStr}`;
        gdmId = cache.gdms[fullGdmNo];
        if (!gdmId) {
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
            stats.gdmsAdded++;
          }
          gdmId = gdm.id;
          cache.gdms[fullGdmNo] = gdmId;
        }
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
          consignorId: cnorId,
          consigneeId: cneeId,
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
      stats.gcsAdded++;
    }

    console.log("=== APPROVED 20 RECORDS IMPORT COMPLETE ===");
    console.log(stats);

  } catch (err) {
    console.error("Import Error:", err);
  } finally {
    await prisma.$disconnect();
  }
}

import20();
