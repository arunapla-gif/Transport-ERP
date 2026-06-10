const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
async function run() {
  const c = await prisma.legacyMaster.groupBy({ by: ['status', 'partyType'], _count: true });
  console.log(c);
  process.exit(0);
}
run();
