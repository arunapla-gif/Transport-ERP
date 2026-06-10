const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
async function run() {
  const c4 = await prisma.consignee.count({ where: { gstin: { not: null } } });
  console.log(`Official Consignees: ${c4}`);
  process.exit(0);
}
run();
