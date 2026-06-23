const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  const c1 = await prisma.consignee.findMany({
    where: { name: { contains: 'SANJAY' } },
    select: { id: true, name: true, parentId: true }
  });
  console.log("Sanjay Consignees:", c1);
}
main().catch(console.error).finally(() => prisma.$disconnect());
