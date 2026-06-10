const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function run() {
  const consignees = await prisma.consignee.findMany({
    where: {
      gstin: { not: null },
      migrationType: { in: ['API_ONLY', 'MANUAL'] }
    }
  });

  const gstinMap = {};
  
  for (const c of consignees) {
    if (!c.gstin || c.gstin.trim() === '') continue;
    
    const gstin = c.gstin.toUpperCase();
    if (!gstinMap[gstin]) {
      gstinMap[gstin] = [];
    }
    gstinMap[gstin].push(c);
  }

  let duplicateGroups = 0;
  let totalDuplicates = 0;

  console.log("--- Duplicate GSTINs in API Data ---");
  for (const [gstin, records] of Object.entries(gstinMap)) {
    if (records.length > 1) {
      duplicateGroups++;
      totalDuplicates += records.length;
      console.log(`\nGSTIN: ${gstin} (${records.length} records)`);
      for (const r of records) {
        console.log(`  - ID: ${r.id} | Name: ${r.name} | City: ${r.city}`);
      }
    }
  }

  if (duplicateGroups === 0) {
    console.log("\nNo duplicates found! Every GSTIN is unique.");
  } else {
    console.log(`\nFound ${duplicateGroups} different GSTINs that have multiple records (Total ${totalDuplicates} duplicate entries).`);
  }
}

run()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
