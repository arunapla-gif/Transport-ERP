const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
async function run() {
  const consignees = await prisma.consignee.findMany();
  console.log('Consignees Count:', consignees.length);
  for (const c of consignees) {
    console.log(`- ${c.name}: tradeNames=${JSON.stringify(c.tradeNames)}, legalName=${c.legalName}, addresses=${JSON.stringify(c.addresses)}`);
  }
}
run().finally(() => process.exit(0));
