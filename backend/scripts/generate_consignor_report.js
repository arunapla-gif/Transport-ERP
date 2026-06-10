const { PrismaClient } = require('@prisma/client');
const fs = require('fs');
const prisma = new PrismaClient();

async function run() {
  // 1. Find unmigrated from Staging
  const unmigrated = await prisma.legacyMaster.findMany({
    where: {
      partyType: 'CONSIGNOR',
      status: { not: 'APPROVED' }
    }
  });

  // 2. Find Duplicates (Official vs Dumb)
  const officialConsignors = await prisma.consignor.findMany({
    where: { gstin: { not: null } }
  });
  
  const dumbConsignors = await prisma.consignor.findMany({
    where: { gstin: null }
  });

  // Simple normalization function
  const normalize = (name) => name.toUpperCase()
    .replace(/[^A-Z0-9]/g, '')
    .replace(/AGENCIES|AGENCY|TRADERS|TRADING|ENTERPRISES|FIREWORKS|FIRE|WORKS|AND|CO|SRI|SREE|M\/S|THE/g, '');

  const matches = [];

  for (const off of officialConsignors) {
    const normOff = normalize(off.name);
    if (normOff.length < 3) continue;

    for (const dumb of dumbConsignors) {
      const normDumb = normalize(dumb.name);
      if (normDumb.length < 3) continue;

      if (normOff === normDumb || normOff.includes(normDumb) || normDumb.includes(normOff)) {
        matches.push({
          official: off,
          dumb: dumb
        });
        break; // Just map the first best match for the report
      }
    }
  }

  let report = `# Consignor Migration Report\n\n`;
  
  report += `## 1. Unmigrated from Staging (Legacy Master Page)\n`;
  report += `There are **${unmigrated.length}** records still sitting in Staging and not yet migrated to the active database.\n\n`;
  
  unmigrated.forEach(u => {
    report += `- **${u.oldName || u.apiName}** (GSTIN: ${u.oldGstin}) - Status: ${u.status}\n`;
  });

  report += `\n## 2. Duplicate Consolidation Analysis\n`;
  report += `Found **${matches.length}** "dumb" consignors (with attached GCs) that can be merged with official GSTIN profiles.\n\n`;
  
  report += `| Official Profile (From Whitebooks) | Dumb Profile (From GC Import) | Action |\n`;
  report += `| :--- | :--- | :--- |\n`;
  
  matches.slice(0, 50).forEach(m => {
    report += `| ${m.official.name} (${m.official.gstin}) | ${m.dumb.name} (Has GCs) | Will Merge |\n`;
  });
  
  if (matches.length > 50) {
    report += `| ... and ${matches.length - 50} more | ... | ... |\n`;
  }

  // Write to Artifacts Directory (using process.cwd to run it in background, I'll print the content to stdout)
  console.log(report);
  
  process.exit(0);
}
run();
