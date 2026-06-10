const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function run() {
  console.log("Starting to reverse the legacy import...");

  // 1. Find all Legacy GCs
  const legacyGcs = await prisma.gC.findMany({
    where: { gcNumber: { startsWith: 'LEGACY-' } },
    select: { id: true }
  });
  const legacyGcIds = legacyGcs.map(g => g.id);

  if (legacyGcIds.length > 0) {
    const deletedItems = await prisma.gCItem.deleteMany({
      where: { gcId: { in: legacyGcIds } }
    });
    console.log(`Deleted ${deletedItems.count} GC Items.`);

    const deletedGcs = await prisma.gC.deleteMany({
      where: { gcNumber: { startsWith: 'LEGACY-' } }
    });
    console.log(`Deleted ${deletedGcs.count} Legacy GCs.`);
  }

  // 2. Delete all Legacy GDMs
  const deletedGdms = await prisma.gDM.deleteMany({
    where: { gdmNumber: { startsWith: 'LEGACY-GDM-' } }
  });
  console.log(`Deleted ${deletedGdms.count} Legacy GDMs.`);

  // 3. Delete Orphaned Consignors (0 GCs)
  const deletedConsignors = await prisma.consignor.deleteMany({
    where: { gcs: { none: {} } }
  });
  console.log(`Deleted ${deletedConsignors.count} Orphaned Consignors.`);

  // 4. Delete Orphaned Consignees (0 GCs)
  const deletedConsignees = await prisma.consignee.deleteMany({
    where: { gcs: { none: {} } }
  });
  console.log(`Deleted ${deletedConsignees.count} Orphaned Consignees.`);

  // 5. Delete Orphaned Vehicles (0 GDMs and 0 Trips)
  const deletedVehicles = await prisma.vehicle.deleteMany({
    where: { gdms: { none: {} }, trips: { none: {} } }
  });
  console.log(`Deleted ${deletedVehicles.count} Orphaned Vehicles.`);

  console.log("Reversal Complete!");
  await prisma.$disconnect();
}

run().catch(console.error);
