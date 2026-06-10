const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const xlsx = require('xlsx');
const path = require('path');
const fs = require('fs');

async function runTest() {
  try {
    console.log("Reading Book2.xlsx...");
    const workbook = xlsx.readFile(path.join(__dirname, '../../Book2.xlsx'));
    const sheetName = workbook.SheetNames[0];
    const data = xlsx.utils.sheet_to_json(workbook.Sheets[sheetName]);

    // Filter to get records with GSTIN and take first 25 unique ones
    const uniqueGstins = new Set();
    const testRecords = [];
    
    for (const row of data) {
      const gstin = row['GSTIN'] ? row['GSTIN'].trim() : null;
      if (gstin && gstin.length === 15 && !uniqueGstins.has(gstin)) {
        uniqueGstins.add(gstin);
        testRecords.push({
          partyType: 'CONSIGNOR',
          oldId: String(row['ID'] || ''),
          oldName: String(row['Consignor Name'] || ''),
          oldAddress: String(row['Address line1'] || ''),
          oldCity: String(row['City / Village'] || ''),
          oldGstin: gstin,
          oldPhone: String(row['Contact1'] || ''),
        });
      }
      if (testRecords.length >= 25) break;
    }

    console.log(`Found ${testRecords.length} records. Uploading to staging...`);
    
    // Clear old test data
    await prisma.legacyMaster.deleteMany({
      where: { oldGstin: { in: testRecords.map(r => r.oldGstin) } }
    });

    const createdRecords = [];
    for (const record of testRecords) {
      const dbRec = await prisma.legacyMaster.create({ data: { ...record, status: 'PENDING' } });
      createdRecords.push(dbRec);
    }

    console.log("Fetching API data via AppyFlow for 25 records...");
    
    let reportMarkdown = `# Legacy Master Migration Test (25 Records)\n\n`;
    reportMarkdown += `| Old Name (Excel) | Old City | GSTIN | New Legal Name (API) | New Address (API) | Status |\n`;
    reportMarkdown += `|---|---|---|---|---|---|\n`;

    let successCount = 0;
    let failCount = 0;

    for (const record of createdRecords) {
      try {
        console.log(`Fetching ${record.oldGstin}...`);
        
        // Fetch Appyflow directly as requested by user's configuration
        const response = await fetch(`https://appyflow.in/api/verifyGST?gstNo=${record.oldGstin}&key_secret=7eWP3WelRNexYGJ172L3Hb8JNrY2`);
        const apiData = await response.json();
        
        if (apiData.error || !apiData.taxpayerInfo) {
          throw new Error("AppyFlow failed");
        }
        
        const tpInfo = apiData.taxpayerInfo;
        const apiName = tpInfo.legalName || tpInfo.tradeName || '';
        const pradr = tpInfo.pradr?.addr || {};
        const apiAddress = [pradr.bno, pradr.st, pradr.loc].filter(Boolean).join(', ');
        const apiCity = pradr.loc || '';
        const apiState = pradr.stcd || '';
        const apiPincode = pradr.pncd || '';
        
        await prisma.legacyMaster.update({
          where: { id: record.id },
          data: {
            apiName, apiAddress, apiCity, apiState, apiPincode, 
            status: 'READY', provider: 'APPYFLOW'
          }
        });

        reportMarkdown += `| ${record.oldName} | ${record.oldCity} | \`${record.oldGstin}\` | **${apiName}** | ${apiAddress}, ${apiCity} | ✅ SUCCESS |\n`;
        successCount++;
      } catch (err) {
        console.error(`Failed for ${record.oldGstin}: ${err.message}`);
        await prisma.legacyMaster.update({
          where: { id: record.id },
          data: { status: 'FAILED_FETCH' }
        });
        reportMarkdown += `| ${record.oldName} | ${record.oldCity} | \`${record.oldGstin}\` | - | - | ❌ FAILED |\n`;
        failCount++;
      }
      
      // small delay to prevent rate limit
      await new Promise(r => setTimeout(r, 600));
    }
    
    reportMarkdown += `\n**Summary:**\n* Total Tested: 25\n* Successfully Fetched: ${successCount}\n* Failed: ${failCount}\n`;
    
    // Save report to workspace
    fs.writeFileSync(path.join(__dirname, '../../Legacy_Import_Test_Report.md'), reportMarkdown);
    console.log("Done. Report saved.");
    
  } catch (err) {
    console.error("Test failed:", err);
  } finally {
    await prisma.$disconnect();
  }
}

runTest();
