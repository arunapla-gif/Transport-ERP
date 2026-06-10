const xlsx = require('xlsx');
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function run() {
  console.log("Loading Excel file...");
  const workbook = xlsx.readFile('/Users/arun_ap/Desktop/TRANSPORT ERP/Book1.xlsx');
  const sheetName = workbook.SheetNames[0];
  const sheet = workbook.Sheets[sheetName];
  const data = xlsx.utils.sheet_to_json(sheet);
  
  console.log(`Total rows in Excel: ${data.length}`);

  const excelConsignees = new Set();
  
  for (const row of data) {
    const gstin = row['GST NO'] || row['GSTIN'] || row['gst no'] || row['GST NO '];
    if (gstin && String(gstin).trim().length > 0) {
      continue; // Skip those with GSTIN because they were deliberately ignored by the script
    }

    const cName = row['Name'] || row['Consignee Name'];
    if (cName && typeof cName === 'string') {
      const cleanName = cName.trim().toUpperCase();
      if (cleanName) {
        excelConsignees.add(cleanName);
      }
    }
  }

  console.log(`Unique Consignee Names in Excel: ${excelConsignees.size}`);

  const dbConsignees = await prisma.consignee.findMany({ select: { name: true, tradeNames: true } });
  
  const dbNames = new Set();
  for (const c of dbConsignees) {
    if (c.name) {
      // Add base name
      dbNames.add(c.name.trim().toUpperCase());
      // Also add name without brackets just in case
      dbNames.add(c.name.replace(/\([^)]*\)/g, '').trim().toUpperCase());
      // Add name without PH: suffix
      dbNames.add(c.name.replace(/\bPH.*$/i, '').trim().toUpperCase());
    }
    if (c.tradeNames && Array.isArray(c.tradeNames)) {
      for (const t of c.tradeNames) {
        dbNames.add(t.trim().toUpperCase());
      }
    }
  }

  let missingCount = 0;
  const missingExamples = [];

  for (const excelName of excelConsignees) {
    // Exact match
    if (dbNames.has(excelName)) continue;

    // Fuzzy check (e.g. if Excel has "KUMAR" and DB has "KUMAR (CITY)")
    let found = false;
    for (const dbName of dbNames) {
      if (dbName.includes(excelName) || excelName.includes(dbName)) {
        found = true;
        break;
      }
    }

    if (!found) {
      missingCount++;
      if (missingExamples.length < 10) {
        missingExamples.push(excelName);
      }
    }
  }

  console.log(`\n--- Verification Results ---`);
  console.log(`Missing from Database: ${missingCount} out of ${excelConsignees.size} unique names`);
  if (missingCount > 0) {
    console.log(`\nExamples of Missing Consignees:`);
    console.log(missingExamples.join('\n'));
  } else {
    console.log(`ALL consignees from the Excel file are present in the database!`);
  }
}

run()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
