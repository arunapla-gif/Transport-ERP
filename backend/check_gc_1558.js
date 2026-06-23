const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  const gc = await prisma.gC.findFirst({
    where: { gcNumber: 'BELL-1558' },
    include: { consignee: true, consignor: true }
  });
  console.log("GC Details for BELL-1558:");
  console.log(JSON.stringify(gc, null, 2));
}
main().catch(console.error).finally(() => prisma.$disconnect());
