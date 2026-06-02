const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function clearData() {
  try {
    console.log("Cleaning database...");
    
    const delItems = await prisma.gCItem.deleteMany({});
    console.log(`✅ Deleted ${delItems.count} Goods Items.`);

    const delGcs = await prisma.gC.deleteMany({});
    console.log(`✅ Deleted ${delGcs.count} GCs.`);

    const delGdms = await prisma.gDM.deleteMany({});
    console.log(`✅ Deleted ${delGdms.count} GDMs.`);

    const delConsignors = await prisma.consignor.deleteMany({
      where: { name: { contains: 'STRESS' } }
    });
    console.log(`✅ Deleted ${delConsignors.count} Stress Consignors.`);

    const delConsignees = await prisma.consignee.deleteMany({
      where: { name: { contains: 'STRESS' } }
    });
    console.log(`✅ Deleted ${delConsignees.count} Stress Consignees.`);

    const delVehicles = await prisma.vehicle.deleteMany({
      where: { vehicleNumber: { contains: 'STRESS' } }
    });
    console.log(`✅ Deleted ${delVehicles.count} Stress Vehicles.`);

    console.log("Database successfully cleaned for testing!");
  } catch (err) {
    console.error("Error cleaning database:", err);
  } finally {
    await prisma.$disconnect();
  }
}

clearData();
