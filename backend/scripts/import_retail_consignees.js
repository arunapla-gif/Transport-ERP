const { PrismaClient } = require('@prisma/client');
const xlsx = require('xlsx');
const path = require('path');

const prisma = new PrismaClient();

async function run() {
  try {
    const filePath = path.join(__dirname, '..', 'Book1.xlsx');
    console.log(`Loading Excel file: ${filePath}`);
    const workbook = xlsx.readFile(filePath);
    const sheet = workbook.Sheets[workbook.SheetNames[0]];
    const data = xlsx.utils.sheet_to_json(sheet);
    
    console.log(`Total rows in Excel: ${data.length}`);

    // Preload existing consignees to avoid duplicates
    const allConsignees = await prisma.consignee.findMany({ select: { name: true } });
    const existingNames = new Set(allConsignees.map(c => c.name.toLowerCase()));

    let importedCount = 0;
    let skippedCount = 0;
    
    console.log('Starting import of retail consignees...');

    for (const row of data) {
      // Check for GSTIN
      const gstin = row['GST NO'] || row['GSTIN'] || row['gst no'] || row['GST NO '];
      if (gstin && String(gstin).trim().length > 0) {
        skippedCount++; // Skip those with GSTIN
        continue;
      }

      // We need at least a name
      const rawName = row['Name'] || row['Consignee Name'];
      if (!rawName) continue;

      let name = String(rawName).trim();
      
      // Combine address
      const addr1 = row['Address line1'] ? String(row['Address line1']).trim() : '';
      const area = row['Street / Area'] ? String(row['Street / Area']).trim() : '';
      const address = [addr1, area].filter(Boolean).join(', ');
      
      const city = row['City / Village'] ? String(row['City / Village']).trim() : null;
      
      // Combine contacts
      const c1 = row['Contact1'] ? String(row['Contact1']).trim() : '';
      const c2 = row['Contact2'] ? String(row['Contact2']).trim() : '';
      const phone = [c1, c2].filter(Boolean).join(', ');

      // Handle duplicate names
      let uniqueName = name;
      let counter = 1;
      while (existingNames.has(uniqueName.toLowerCase())) {
        if (counter === 1 && city) {
          uniqueName = `${name} (${city})`;
        } else {
          uniqueName = `${name} (${counter})`;
        }
        counter++;
      }

      existingNames.add(uniqueName.toLowerCase());

      await prisma.consignee.create({
        data: {
          name: uniqueName,
          address: address || null,
          city: city,
          phone: phone || null,
          group: 'Retail',
          migrationType: 'RETAIL_IMPORT'
        }
      });
      importedCount++;
      
      // Prevent Neon from crashing by adding a slight delay
      await new Promise(resolve => setTimeout(resolve, 50));
      
      if (importedCount % 100 === 0) {
        console.log(`Imported ${importedCount} retail consignees...`);
      }
    }

    console.log('--- Import Complete ---');
    console.log(`Successfully imported: ${importedCount}`);
    console.log(`Skipped (Has GSTIN): ${skippedCount}`);
    
    // Clear the master cache just in case
    console.log('Database updated. You can refresh your browser.');
  } catch (err) {
    console.error('Import failed:', err);
  } finally {
    await prisma.$disconnect();
  }
}

run();
