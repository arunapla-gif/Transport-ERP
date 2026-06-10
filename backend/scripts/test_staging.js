const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
async function run() {
  const c = await prisma.legacyMaster.count({ where: { partyType: 'CONSIGNOR' } });
  const c2 = await prisma.consignor.count();
  const c3 = await prisma.legacyMaster.count({ where: { partyType: 'CONSIGNEE' } });
  const c4 = await prisma.consignee.count();
  console.log(`Staging Consignors: ${c}, Active Consignors: ${c2}`);
  console.log(`Staging Consignees: ${c3}, Active Consignees: ${c4}`);
  process.exit(0);
}
run();
