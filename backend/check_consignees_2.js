const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  const c1 = await prisma.consignee.findUnique({
    where: { id: 182 }
  });
  console.log("Consignee 182:", c1);
}
main().catch(console.error).finally(() => prisma.$disconnect());
