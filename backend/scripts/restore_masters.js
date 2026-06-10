const fs = require('fs');
const path = require('path');
const xlsx = require('xlsx');
const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();

async function restoreMasters() {
  console.log("Starting Data Restoration...");

  let consignorsRestored = 0;
  let consigneesRestored = 0;

  try {
    // 1. RESTORE CONSIGNORS FROM BOOK2.XLSX
    console.log("Restoring Consignors from Book2.xlsx...");
    const book2Path = path.join(__dirname, '..', 'Book2.xlsx');
    
    if (fs.existsSync(book2Path)) {
      const workbook = xlsx.readFile(book2Path);
      const sheet = workbook.Sheets[workbook.SheetNames[0]];
      const data = xlsx.utils.sheet_to_json(sheet);
      
      for (const row of data) {
        const name = String(row['Consignor Name'] || row['Name'] || '').trim();
        const address = String(row['Address line1'] || '').trim();
        const city = String(row['City / Village'] || '').trim();
        const gstin = String(row['GSTIN'] || '').trim().toUpperCase();
        const phone = String(row['Contact1'] || '').trim();

        if (name) {
          await prisma.consignor.upsert({
            where: { name: name },
            update: {
              address: address,
              city: city,
              gstin: gstin,
              phone: phone
            },
            create: {
              name: name,
              address: address,
              city: city,
              gstin: gstin,
              phone: phone
            }
          });
          consignorsRestored++;
        }
      }
      console.log(`✅ Restored ${consignorsRestored} Consignors from Book2.xlsx.`);
    } else {
      console.log("⚠️ Book2.xlsx not found.");
    }

    // 2. RESTORE CONSIGNEES FROM BOOK1.XLSX
    console.log("Restoring Consignees from Book1.xlsx...");
    const book1Path = path.join(__dirname, '..', 'Book1.xlsx');
    if (fs.existsSync(book1Path)) {
      const workbook = xlsx.readFile(book1Path);
      const sheet = workbook.Sheets[workbook.SheetNames[0]];
      const data = xlsx.utils.sheet_to_json(sheet);
      
      for (const row of data) {
        const name = String(row['Name'] || row['Consignee Name'] || '').trim();
        const address = String(row['Address line1'] || '').trim();
        const city = String(row['City / Village'] || '').trim();
        const gstin = String(row['GST NO'] || row['GSTIN'] || row['gst no'] || '').trim().toUpperCase();
        const phone = String(row['Contact1'] || '').trim();

        if (name) {
          await prisma.consignee.upsert({
            where: { name: name },
            update: {
              address: address,
              city: city,
              gstin: gstin,
              phone: phone
            },
            create: {
              name: name,
              address: address,
              city: city,
              gstin: gstin,
              phone: phone
            }
          });
          consigneesRestored++;
        }
      }
      console.log(`✅ Restored ${consigneesRestored} Consignees from Book1.xlsx.`);
    } else {
       console.log("⚠️ Book1.xlsx not found.");
    }

    console.log("\n🎉 Restoration Complete!");
    console.log(`Consignors Restored: ${consignorsRestored}`);
    console.log(`Consignees Restored: ${consigneesRestored}`);

  } catch (error) {
    console.error("❌ Restoration failed:", error);
  } finally {
    await prisma.$disconnect();
  }
}

restoreMasters();
