const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const xlsx = require('xlsx');
const path = require('path');
const fs = require('fs');

async function runFullConsignorMigration() {
  try {
    console.log("Reading Book2.xlsx...");
    const workbook = xlsx.readFile(path.join(__dirname, '../../Book2.xlsx'));
    const sheetName = workbook.SheetNames[0];
    const data = xlsx.utils.sheet_to_json(workbook.Sheets[sheetName]);

    console.log(`Parsed ${data.length} total rows from Excel.`);

    // Filter to get records with valid GSTINs
    const uniqueGstins = new Map();
    
    for (const row of data) {
      const gstin = row['GSTIN'] ? String(row['GSTIN']).trim().toUpperCase() : null;
      if (gstin && gstin.length === 15 && !uniqueGstins.has(gstin)) {
        uniqueGstins.set(gstin, {
          partyType: 'CONSIGNOR',
          oldId: String(row['ID'] || ''),
          oldName: String(row['Consignor Name'] || ''),
          oldAddress: String(row['Address line1'] || ''),
          oldCity: String(row['City / Village'] || ''),
          oldGstin: gstin,
          oldPhone: String(row['Contact1'] || ''),
        });
      }
    }

    const testRecords = Array.from(uniqueGstins.values());
    console.log(`Found ${testRecords.length} unique Consignors with valid GSTINs.`);
    
    // Upload to Staging
    console.log("Uploading to Staging...");
    for (const record of testRecords) {
      // Upsert by oldGstin
      const existing = await prisma.legacyMaster.findFirst({
        where: { oldGstin: record.oldGstin, partyType: 'CONSIGNOR' }
      });
      if (!existing) {
        await prisma.legacyMaster.create({ data: { ...record, status: 'PENDING' } });
      }
    }

    // Get all pending consignors
    const records = await prisma.legacyMaster.findMany({
      where: { partyType: 'CONSIGNOR' },
      orderBy: { id: 'asc' }
    });

    console.log(`Starting Whitebooks API Fetch for ${records.length} total Consignors...`);

    let reportMarkdown = `# Full Consignor Legacy Migration Report\n\n`;
    reportMarkdown += `Here is the full mapping of all Consignors from \`Book2.xlsx\` powered by WhiteBooks API.\n\n`;
    reportMarkdown += `| Old Name (Excel) | GSTIN | New Legal Name (API) | New Address (API) | Status |\n`;
    reportMarkdown += `|---|---|---|---|---|\n`;

    let successCount = 0;
    let failCount = 0;

    for (let i = 0; i < records.length; i++) {
      const record = records[i];
      if (record.status === 'APPROVED') continue; // Skip already migrated ones

      try {
        process.stdout.write(`[${i+1}/${records.length}] Fetching ${record.oldGstin}... `);
        
        // Skip fetch if already fetched successfully previously
        if (record.status !== 'READY') {
          const response = await fetch(`http://localhost:${process.env.PORT || 5005}/api/gst-search/${record.oldGstin}`);
          const apiData = await response.json();
          
          if (!response.ok || apiData.error) {
            throw new Error(apiData.error || "Whitebooks failed");
          }
          
          const apiName = apiData.legalName || apiData.tradeName || '';
          const apiAddress = apiData.address || '';
          const apiCity = apiData.city || '';
          const apiState = apiData.state || '';
          const apiPincode = apiData.pincode || '';
          
          await prisma.legacyMaster.update({
            where: { id: record.id },
            data: {
              apiName, apiAddress, apiCity, apiState, apiPincode, 
              status: 'READY', provider: 'WHITEBOOKS'
            }
          });
          
          reportMarkdown += `| ${record.oldName} | \`${record.oldGstin}\` | **${apiName}** | ${apiAddress}, ${apiCity} | ✅ FETCHED |\n`;
        } else {
          reportMarkdown += `| ${record.oldName} | \`${record.oldGstin}\` | **${record.apiName}** | ${record.apiAddress}, ${record.apiCity} | ✅ PREV. FETCHED |\n`;
        }
        
        console.log(`Success`);
        successCount++;
        
        // Strict delay to completely avoid Whitebooks rate limits
        await new Promise(r => setTimeout(r, 600));

      } catch (err) {
        console.log(`FAILED: ${err.message}`);
        await prisma.legacyMaster.update({
          where: { id: record.id },
          data: { status: 'FAILED_FETCH' }
        });
        reportMarkdown += `| ${record.oldName} | \`${record.oldGstin}\` | - | - | ❌ ${err.message.substring(0,20)} |\n`;
        failCount++;
      }
    }
    
    reportMarkdown += `\n**Summary:**\n* Total Unique Consignors: ${records.length}\n* Successfully Fetched: ${successCount}\n* Failed (Invalid GSTIN): ${failCount}\n`;
    
    // Save report to workspace
    const reportPath = path.join(__dirname, '../../Full_Consignor_Migration_Report.md');
    fs.writeFileSync(reportPath, reportMarkdown);
    console.log(`\nDone! Saved comprehensive report to ${reportPath}`);
    
  } catch (err) {
    console.error("Critical Failure:", err);
  } finally {
    await prisma.$disconnect();
  }
}

runFullConsignorMigration();
