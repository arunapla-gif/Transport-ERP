const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
async function run() {
  const all = await prisma.warehouseInward.findMany({
    orderBy: { createdAt: 'desc' },
    take: 5
  });
  console.log(all);
}
run().finally(() => prisma.$disconnect());
