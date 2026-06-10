const { PrismaClient } = require('@prisma/client');
const xlsx = require('xlsx');
const path = require('path');

const prisma = new PrismaClient();

async function importConsignees() {
  console.log("Starting Consignee Import to Legacy Staging...");
  try {
    const workbook = xlsx.readFile(path.join(__dirname, '..', 'Book1.xlsx'));
    const sheet = workbook.Sheets[workbook.SheetNames[0]];
    const data = xlsx.utils.sheet_to_json(sheet);
    
    // Filter only those with a valid-looking GSTIN
    const validData = data.filter(row => {
      const gstin = String(row['GSTIN'] || '').trim();
      return gstin && gstin.length >= 10;
    });

    console.log(`Found ${validData.length} Consignees with GSTINs to import.`);

    let importedCount = 0;
    
    for (const row of validData) {
      const oldId = String(row['ID'] || '');
      const oldName = String(row['Name'] || '').trim();
      const oldAddress = String(row['Address line1'] || '').trim();
      const oldCity = String(row['City / Village'] || '').trim();
      const oldGstin = String(row['GSTIN'] || '').trim().toUpperCase();
      const oldPhone = String(row['Contact1'] || '').trim();

      // Check if it already exists in staging to avoid duplicates
      const exists = await prisma.legacyMaster.findFirst({
        where: { partyType: 'CONSIGNEE', oldName: oldName, oldGstin: oldGstin }
      });

      if (!exists) {
        await prisma.legacyMaster.create({
          data: {
            partyType: 'CONSIGNEE',
            oldId,
            oldName,
            oldAddress,
            oldCity,
            oldGstin,
            oldPhone,
            status: 'PENDING'
          }
        });
        importedCount++;
      }
    }

    console.log(`Successfully imported ${importedCount} unique Consignees into Legacy Staging.`);

  } catch (error) {
    console.error("Error importing:", error);
  } finally {
    await prisma.$disconnect();
  }
}

importConsignees();
