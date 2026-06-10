const { PrismaClient } = require('@prisma/client');
const xlsx = require('xlsx');
const path = require('path');
const fs = require('fs');

const prisma = new PrismaClient();

async function importLegacyExcel() {
  try {
    const filePath = path.join(__dirname, '..', 'gc 4.5-3.6.xlsx');
    console.log(`Loading Excel file: ${filePath}`);
    const workbook = xlsx.readFile(filePath);
    const sheetName = workbook.SheetNames[0];
    const sheet = workbook.Sheets[sheetName];
    const data = xlsx.utils.sheet_to_json(sheet);
    
    console.log(`Found ${data.length} records to import.`);
    
    let stats = {
      gcsAdded: 0,
      gdmsAdded: 0,
      unmappedConsignors: 0,
      unmappedConsignees: 0
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
      if (i % 100 === 0 && i > 0) console.log(`Processed ${i}/${data.length}...`);
      
      const row = data[i];
      if (!row['GC No']) continue; 
      
      const gcNumberStr = String(row['GC No']).trim();
      const rawGcNo = `LEGACY-${gcNumberStr}`; 

      // Skip if already imported
      const existing = await prisma.gC.findUnique({ where: { gcNumber: rawGcNo }});
      if (existing) continue;

      const consignorName = row['Consignor'] ? String(row['Consignor']).trim() : '';
      const consigneeName = row['Consingee'] ? String(row['Consingee']).trim() : '';
      const lorryNo = row['Despatch Lorry'] ? String(row['Despatch Lorry']).trim() : null;
      const gdmNoStr = row['Despatch No'] ? String(row['Despatch No']).trim() : null;
      
      let cnorId = cache.consignors[consignorName] || null;
      if (!cnorId) stats.unmappedConsignors++;

      let cneeId = cache.consignees[consigneeName] || null;
      if (!cneeId) stats.unmappedConsignees++;

      let vehId = lorryNo ? (cache.vehicles[lorryNo] || null) : null;

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

      const closing = Number(row['Closing']) || 0;
      const opening = Number(row['Opening']) || 0;
      const status = closing === 0 ? 'Dispatched' : 'Created'; 
      
      const gcDateStr = row['GC Date'];
      let gcDate = new Date();
      if (gcDateStr && String(gcDateStr).includes('-')) {
        gcDate = new Date(String(gcDateStr).split('-').reverse().join('-'));
      }

      const markText = `Legacy Import. Consignor: ${consignorName}, Consignee: ${consigneeName}`;

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
          privateMark: markText,
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
      await new Promise(resolve => setTimeout(resolve, 50));
    }

    console.log("=== IMPORT COMPLETE (NO MASTERS WRITTEN) ===");
    console.log(stats);

  } catch (err) {
    console.error("Import Error:", err);
  } finally {
    await prisma.$disconnect();
  }
}

importLegacyExcel();
