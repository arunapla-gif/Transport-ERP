const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
async function run() {
  const lastEntry = await prisma.warehouseInward.findFirst({
    orderBy: { receiptNo: 'desc' },
    where: { receiptNo: { not: null } }
  });
  console.log("Last entry:", lastEntry);
  const nextReceiptNo = lastEntry && lastEntry.receiptNo ? lastEntry.receiptNo + 1 : 1;
  console.log("Next receipt No:", nextReceiptNo);
}
run().finally(() => prisma.$disconnect());
