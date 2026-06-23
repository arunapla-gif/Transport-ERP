const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  const gc = await prisma.gC.findFirst({
    where: { gcNumber: 'BELL-1555' }
  });
  console.log("GC Details:", gc);
}
main().catch(console.error).finally(() => prisma.$disconnect());
