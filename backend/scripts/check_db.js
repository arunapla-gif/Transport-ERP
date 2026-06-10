const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function check() {
  const c = await prisma.consignor.findMany({ take: 5 });
  console.log("CONSIGNORS:");
  console.log(c);
  
  const lm = await prisma.legacyMaster.findMany({ take: 2, where: { status: 'APPROVED' } });
  console.log("LEGACY MASTER APPROVED:");
  console.log(lm);
  
  const lmP = await prisma.legacyMaster.findMany({ take: 2, where: { status: 'PENDING' } });
  console.log("LEGACY MASTER PENDING:");
  console.log(lmP);
  await prisma.$disconnect();
}
check();
