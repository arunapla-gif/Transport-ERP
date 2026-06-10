const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
async function test() {
  console.time('findMany');
  const consignors = await prisma.consignor.findMany({ orderBy: { id: 'desc' } });
  console.timeEnd('findMany');
  console.time('JSON.stringify');
  JSON.stringify(consignors);
  console.timeEnd('JSON.stringify');
}
test().finally(() => prisma.$disconnect());
