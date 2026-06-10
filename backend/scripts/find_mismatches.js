const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const fs = require('fs');
const path = require('path');

function getTokens(str) {
  if (!str) return [];
  return str.toUpperCase().replace(/[^A-Z0-9]/g, ' ').split(' ').filter(t => t.length > 2);
}

function calculateSimilarity(name1, name2) {
  const tokens1 = getTokens(name1);
  const tokens2 = getTokens(name2);
  
  if (tokens1.length === 0 || tokens2.length === 0) return 0;
  
  let matchCount = 0;
  for (const t1 of tokens1) {
    for (const t2 of tokens2) {
      if (t1 === t2 || t1.includes(t2) || t2.includes(t1)) {
        matchCount++;
        break; // Count each token only once
      }
    }
  }
  
  // Return percentage of matched tokens relative to the shortest name
  const minTokens = Math.min(tokens1.length, tokens2.length);
  return (matchCount / minTokens) * 100;
}

async function run() {
  try {
    const readyRecords = await prisma.legacyMaster.findMany({
      where: { partyType: 'CONSIGNOR', status: 'READY' }
    });

    const mismatches = [];

    for (const record of readyRecords) {
      if (record.oldName && record.apiName) {
        const similarity = calculateSimilarity(record.oldName, record.apiName);
        
        // If similarity is very low, consider it a mismatch
        if (similarity < 30) {
          mismatches.push({
            id: record.id,
            oldName: record.oldName,
            apiName: record.apiName,
            gstin: record.oldGstin,
            similarity
          });
        }
      }
    }

    // Sort by lowest similarity first
    mismatches.sort((a, b) => a.similarity - b.similarity);

    let md = `# Name Mismatches Report (Consignors)\n\n`;
    md += `Out of ${readyRecords.length} successfully fetched records, we found **${mismatches.length}** where the Excel Name looks completely different from the Government API Name.\n\n`;
    md += `| GSTIN | Old Excel Name | Official API Name | Confidence |\n`;
    md += `|---|---|---|---|\n`;

    // Only show top 100 to avoid massive files
    const displayList = mismatches.slice(0, 100);
    for (const m of displayList) {
      md += `| \`${m.gstin}\` | ${m.oldName} | **${m.apiName}** | ${m.similarity === 0 ? '🔴 0% Match' : '🟠 Low Match'} |\n`;
    }

    const reportPath = path.join(__dirname, '../../Name_Mismatches_Report.md');
    fs.writeFileSync(reportPath, md);
    console.log(`Found ${mismatches.length} mismatches. Report saved to ${reportPath}`);

  } catch (err) {
    console.error(err);
  } finally {
    await prisma.$disconnect();
  }
}

run();
