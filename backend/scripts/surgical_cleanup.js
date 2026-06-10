const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function runSurgicalCleanup() {
  console.log("Starting Surgical Cleanup...");

  try {
    // 1. Find all LEGACY GCs
    const legacyGcs = await prisma.gC.findMany({
      where: { gcNumber: { startsWith: 'LEGACY-' } },
      select: { id: true }
    });
    
    const legacyGcIds = legacyGcs.map(g => g.id);
    
    if (legacyGcIds.length > 0) {
      // 1a. Delete GC Items
      const deletedItems = await prisma.gCItem.deleteMany({
        where: { gcId: { in: legacyGcIds } }
      });
      console.log(`Deleted ${deletedItems.count} Legacy GC Items.`);

      // 1b. Delete GCs
      const deletedGcs = await prisma.gC.deleteMany({
        where: { gcNumber: { startsWith: 'LEGACY-' } }
      });
      console.log(`Deleted ${deletedGcs.count} Legacy GCs.`);
    }

    // 2. Delete Corrupted Consignors
    // Criteria: migrationType = 'MANUAL', address is null/empty, AND has 0 GCs attached
    const deletedConsignors = await prisma.consignor.deleteMany({
      where: { 
        migrationType: 'MANUAL',
        OR: [ { address: null }, { address: '' } ],
        gcs: { none: {} }
      }
    });
    console.log(`Deleted ${deletedConsignors.count} Corrupted Consignors.`);

    // 3. Delete Corrupted Consignees
    // Criteria: migrationType = 'MANUAL', address is null/empty, AND has 0 GCs attached
    const deletedConsignees = await prisma.consignee.deleteMany({
      where: { 
        migrationType: 'MANUAL',
        OR: [ { address: null }, { address: '' } ],
        gcs: { none: {} }
      }
    });
    console.log(`Deleted ${deletedConsignees.count} Corrupted Consignees.`);

    console.log("✅ Surgical Cleanup Complete!");
    
  } catch (err) {
    console.error("Cleanup Error:", err);
  } finally {
    await prisma.$disconnect();
  }
}

runSurgicalCleanup();
