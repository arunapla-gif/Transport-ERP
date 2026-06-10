const xlsx = require('xlsx');
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function run() {
  console.log("Loading Excel file...");
  const workbook = xlsx.readFile('/Users/arun_ap/Desktop/TRANSPORT ERP/Book1.xlsx');
  const sheet = workbook.Sheets[workbook.SheetNames[0]];
  const data = xlsx.utils.sheet_to_json(sheet);
  
  // 1. Get all existing GSTINs across both live DB and Legacy queue to prevent duplicates
  const liveConsignees = await prisma.consignee.findMany({ select: { gstin: true } });
  const legacyQueue = await prisma.legacyMaster.findMany({ select: { oldGstin: true } });
  
  const knownGstins = new Set();
  liveConsignees.forEach(c => { if (c.gstin) knownGstins.add(c.gstin.toUpperCase()); });
  legacyQueue.forEach(l => { if (l.oldGstin) knownGstins.add(l.oldGstin.toUpperCase()); });

  let newGstinsFound = 0;
  let skippedDuplicates = 0;

  console.log(`Currently known GSTINs in system: ${knownGstins.size}`);

  // 2. Extract valid GSTIN records from Excel
  const toQueue = new Map(); // using Map to deduplicate within the Excel file itself

  for (const row of data) {
    const rawGstin = row['GST NO'] || row['GSTIN'] || row['gst no'] || row['GST NO '];
    if (rawGstin && String(rawGstin).trim().length > 0) {
      const gstin = String(rawGstin).trim().toUpperCase();
      
      if (knownGstins.has(gstin)) {
        skippedDuplicates++;
        continue;
      }

      if (!toQueue.has(gstin)) {
        toQueue.set(gstin, {
          partyType: 'CONSIGNEE',
          oldName: String(row['Name'] || row['Consignee Name'] || 'UNKNOWN').trim(),
          oldGstin: gstin,
          oldAddress: String(row['Address line1'] || '').trim(),
          status: 'PENDING'
        });
      }
    }
  }

  console.log(`\nFound ${toQueue.size} BRAND NEW GSTINs to add to the Legacy Migration Queue.`);
  console.log(`Skipped ${skippedDuplicates} records that already exist in your system or queue.`);

  // 3. Insert into LegacyMaster
  if (toQueue.size > 0) {
    await prisma.legacyMaster.createMany({
      data: Array.from(toQueue.values()),
      skipDuplicates: true
    });
    console.log(`\nSuccessfully added ${toQueue.size} new records to the Legacy Queue!`);
  } else {
    console.log(`\nNo new records to add. Everything is already queued or imported!`);
  }
}

run()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
