const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function resetTestData() {
  console.log("🧹 Starting Database Cleanup...");

  try {
    // 1. Delete all transactional data (Cascades must be handled carefully)
    console.log("Deleting GC Items...");
    await prisma.gCItem.deleteMany({});
    
    console.log("Deleting GCs...");
    await prisma.gC.deleteMany({});
    
    console.log("Deleting GDMs...");
    await prisma.gDM.deleteMany({});
    
    console.log("Deleting Trips...");
    await prisma.trip.deleteMany({});
    
    console.log("Deleting Party Payments...");
    await prisma.partyPayment.deleteMany({});
    
    console.log("Deleting Daily Transactions...");
    await prisma.dailyTransaction.deleteMany({});

    // 2. Delete the E2E Test Master Data specifically
    console.log("Deleting E2E Master Data...");
    await prisma.consignor.deleteMany({ where: { name: { contains: 'E2E Test' } } });
    await prisma.consignee.deleteMany({ where: { name: { contains: 'E2E Test' } } });
    await prisma.vehicle.deleteMany({ where: { vehicleNumber: { contains: 'TN-E2E' } } });

    console.log("✅ All test data has been completely wiped! Your database is now a clean slate for real data.");
  } catch (error) {
    console.error("❌ Error during cleanup:", error);
  } finally {
    await prisma.$disconnect();
  }
}

resetTestData();
