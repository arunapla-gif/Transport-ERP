const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const fs = require('fs');
const path = require('path');

async function runWhitebooksTest() {
  try {
    console.log("Fetching 25 PENDING records from LegacyMaster...");
    // Get all records we previously inserted (we can just reset their status and provider)
    const records = await prisma.legacyMaster.findMany({
      take: 25,
      orderBy: { id: 'asc' }
    });

    if (records.length === 0) {
      console.log("No records found.");
      return;
    }

    console.log(`Found ${records.length} records. Fetching via Whitebooks...`);

    let reportMarkdown = `# Legacy Master Migration Test - WHITEBOOKS (25 Records)\n\n`;
    reportMarkdown += `| Old Name (Excel) | GSTIN | New Legal Name (API) | New Address (API) | Status |\n`;
    reportMarkdown += `|---|---|---|---|---|\n`;

    let successCount = 0;
    let failCount = 0;

    for (const record of records) {
      try {
        console.log(`Fetching ${record.oldGstin} via Whitebooks...`);
        
        // Call the local backend's Whitebooks GST search endpoint
        const response = await fetch(`http://localhost:5005/api/gst-search/${record.oldGstin}`);
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

        reportMarkdown += `| ${record.oldName} | \`${record.oldGstin}\` | **${apiName}** | ${apiAddress}, ${apiCity} | ✅ SUCCESS |\n`;
        successCount++;
      } catch (err) {
        console.error(`Failed for ${record.oldGstin}: ${err.message}`);
        await prisma.legacyMaster.update({
          where: { id: record.id },
          data: { status: 'FAILED_FETCH' }
        });
        reportMarkdown += `| ${record.oldName} | \`${record.oldGstin}\` | - | - | ❌ FAILED |\n`;
        failCount++;
      }
      
      // Delay to avoid overwhelming local server
      await new Promise(r => setTimeout(r, 800));
    }
    
    reportMarkdown += `\n**Summary:**\n* Total Tested: ${records.length}\n* Successfully Fetched: ${successCount}\n* Failed: ${failCount}\n`;
    
    // Save report
    fs.writeFileSync(path.join(__dirname, '../../Legacy_Import_Whitebooks_Report.md'), reportMarkdown);
    console.log("Done. Report saved.");
    
  } catch (err) {
    console.error("Test failed:", err);
  } finally {
    await prisma.$disconnect();
  }
}

runWhitebooksTest();
