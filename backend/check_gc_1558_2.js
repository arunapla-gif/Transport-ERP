const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  const gc = await prisma.gC.findFirst({
    where: { gcNumber: 'BELL-1558' }
  });
  console.log("GC Details for BELL-1558:");
  console.log("Status:", gc.status);
  console.log("GdmId:", gc.gdmId);
  console.log("ConsigneeId:", gc.consigneeId);
}
main().catch(console.error).finally(() => prisma.$disconnect());
