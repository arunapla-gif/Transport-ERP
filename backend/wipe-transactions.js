const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function wipeTransactions() {
  console.log("⚠️  Starting selective wipe of transactional data...");

  try {
    console.log("Executing TRUNCATE with RESTART IDENTITY CASCADE...");
    await prisma.$executeRawUnsafe(`TRUNCATE TABLE "GCItem", "GC", "GDM", "Trip", "FreightBill", "DailyTransaction", "PartyPayment", "WarehouseInward" RESTART IDENTITY CASCADE;`);
    
    console.log("✅ Selective wipe and sequence reset completed successfully.");
    console.log("✅ Consignor, Consignee, Vehicle, Godown, Unit, and Company tables were NOT touched.");
  } catch (error) {
    console.error("❌ Error during selective wipe:", error);
  } finally {
    await prisma.$disconnect();
  }
}

wipeTransactions();
