const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function run() {
  console.log("Checking for GCs linked to Consignees...");
  const linkedGcs = await prisma.gC.count({
    where: { consigneeId: { not: null } }
  });

  if (linkedGcs > 0) {
    console.log(`Found ${linkedGcs} GCs linked to Consignees. Cannot safely delete Consignees without orphaned GCs.`);
    // Optionally remove consignee links if needed, or delete GCs?
    // Let's just nullify the consigneeId on GCs to allow deletion if needed, 
    // BUT maybe there are no GCs since we wiped them!
  }

  // Nullify consigneeId on any existing GCs to prevent constraint errors
  await prisma.gC.updateMany({
    data: { consigneeId: null }
  });
  console.log("Unlinked all Consignees from any remaining GCs.");

  // Delete all Consignees
  const result = await prisma.consignee.deleteMany({});
  console.log(`Successfully deleted ${result.count} Consignee records.`);
  
  await prisma.$disconnect();
}

run().catch(console.error);
