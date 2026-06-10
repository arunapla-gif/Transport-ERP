const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function run() {
  console.log("Starting cleanup of Legacy Excel data...");

  // 1. Delete all GC Items attached to Legacy GCs
  const legacyGcs = await prisma.gC.findMany({
    where: { gcNumber: { startsWith: 'LEGACY-' } },
    select: { id: true }
  });
  
  const legacyGcIds = legacyGcs.map(g => g.id);
  
  if (legacyGcIds.length > 0) {
    const deletedItems = await prisma.gCItem.deleteMany({
      where: { gcId: { in: legacyGcIds } }
    });
    console.log(`Deleted ${deletedItems.count} GC Items attached to Legacy GCs.`);
  }

  // 2. Delete all Legacy GCs
  const deletedGcs = await prisma.gC.deleteMany({
    where: { gcNumber: { startsWith: 'LEGACY-' } }
  });
  console.log(`Deleted ${deletedGcs.count} Legacy GCs.`);

  // 3. Delete all Legacy GDMs
  const deletedGdms = await prisma.gDM.deleteMany({
    where: { gdmNumber: { startsWith: 'LEGACY-GDM-' } }
  });
  console.log(`Deleted ${deletedGdms.count} Legacy GDMs.`);

  // 4. Delete Dumb Consignors (no GSTIN, no GCs)
  const deletedConsignors = await prisma.consignor.deleteMany({
    where: { 
      migrationType: 'OLD_DATA_ONLY',
      gcs: { none: {} } // only delete if they have no GCs anymore
    }
  });
  console.log(`Deleted ${deletedConsignors.count} Dumb Consignors (with no GCs).`);

  // 5. Delete Dumb Consignees (no GSTIN, no GCs)
  const deletedConsignees = await prisma.consignee.deleteMany({
    where: { 
      migrationType: 'OLD_DATA_ONLY',
      gcs: { none: {} }
    }
  });
  console.log(`Deleted ${deletedConsignees.count} Dumb Consignees (with no GCs).`);

  console.log("Cleanup Complete!");
  await prisma.$disconnect();
}

run().catch(console.error);
