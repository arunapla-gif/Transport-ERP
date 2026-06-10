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
    const allGcs = await prisma.gC.findMany({ where: { gcNumber: { startsWith: 'LEGACY-' } }, select: { gcNumber: true } });
    
    const cache = {
      consignors: Object.fromEntries(allConsignors.map(c => [c.name, c.id])),
      consignees: Object.fromEntries(allConsignees.map(c => [c.name, c.id])),
      vehicles: Object.fromEntries(allVehicles.map(v => [v.vehicleNumber, v.id])),
      existingGcs: new Set(allGcs.map(g => g.gcNumber)),
      gdms: {}
    };

    console.log('Preloaded cache. Processing...');

    const gcInserts = [];
    const itemInserts = [];
    
    // We will do serial master inserts if they don't exist to avoid duplicates
    for (let i = 0; i < data.length; i++) {
      if (i % 100 === 0 && i > 0) console.log(`Processed ${i}/${data.length}...`);
      
      const row = data[i];
      if (!row['GC No']) continue; 
      
      const gcNumberStr = String(row['GC No']).trim();
      const rawGcNo = `LEGACY-${gcNumberStr}`; 
      
      if (cache.existingGcs.has(rawGcNo)) continue;

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

      // 4. Get or Create GDM (if dispatched)
      let gdmId = null;
      if (gdmNoStr) {
        const fullGdmNo = `LEGACY-GDM-${gdmNoStr}`;
        gdmId = cache.gdms[fullGdmNo];
        if (!gdmId) {
          // Check DB just in case
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

      const createdGc = await prisma.gC.create({
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
      cache.existingGcs.add(rawGcNo);
      
      // Pace the database connections to avoid Neon timeouts
      await new Promise(resolve => setTimeout(resolve, 100));
    }

    console.log("=== IMPORT COMPLETE ===");
    console.log(stats);
    
    // Generate a final breakdown report for the user
    const pendingGodown = await prisma.gC.count({ where: { status: 'Created', gcNumber: { startsWith: 'LEGACY' } } });
    const dispatched = await prisma.gC.count({ where: { status: 'Dispatched', gcNumber: { startsWith: 'LEGACY' } } });
    
    const reportContent = [
      "# Legacy Data Import Report",
      "",
      "## Import Statistics",
      `- **Consignors Added:** ${stats.consignorsAdded}`,
      `- **Consignees Added:** ${stats.consigneesAdded}`,
      `- **Vehicles Added:** ${stats.vehiclesAdded}`,
      `- **GDMs Created:** ${stats.gdmsAdded}`,
      `- **Total GCs Processed:** ${stats.gcsAdded}`,
      "",
      "## Current Godown Status",
      `- **Active Warehouse Stock (Pending GCs):** ${pendingGodown}`,
      `- **Archived Stock (Dispatched GCs):** ${dispatched}`
    ].join('\n');

    fs.writeFileSync(path.join(__dirname, '..', 'Legacy_Import_Report.md'), reportContent);
    console.log('\nReport written to Legacy_Import_Report.md');

  } catch (err) {
    console.error("Import Error:", err);
  } finally {
    await prisma.$disconnect();
  }
}

importLegacyExcel();
