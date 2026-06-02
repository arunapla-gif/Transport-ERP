const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function run() {
  // Clear them out temporarily to avoid unique constraints
  await prisma.warehouseInward.updateMany({
    data: { receiptNo: null }
  });

  const allInwards = await prisma.warehouseInward.findMany({
    orderBy: { createdAt: 'asc' }
  });

  console.log(`Found ${allInwards.length} records. Updating receipt numbers...`);

  let currentReceipt = 1;
  for (const inward of allInwards) {
    await prisma.warehouseInward.update({
      where: { id: inward.id },
      data: { receiptNo: currentReceipt }
    });
    currentReceipt++;
  }

  console.log("Done updating receipt numbers!");
}

run().finally(() => prisma.$disconnect());
