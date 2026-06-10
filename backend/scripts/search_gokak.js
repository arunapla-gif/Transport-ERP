const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
async function run() {
  const consignees = await prisma.consignee.findMany({
    where: {
      OR: [
        { city: { contains: 'gokak', mode: 'insensitive' } },
        { address: { contains: 'gokak', mode: 'insensitive' } },
        { name: { contains: 'gokak', mode: 'insensitive' } }
      ]
    }
  });
  console.log("Consignees:");
  console.log(consignees.map(c => ({ name: c.name, address: c.address, gstin: c.gstin })));

  const legacy = await prisma.legacyMaster.findMany({
    where: {
      OR: [
        { apiCity: { contains: 'gokak', mode: 'insensitive' } },
        { address: { contains: 'gokak', mode: 'insensitive' } },
        { apiName: { contains: 'gokak', mode: 'insensitive' } },
        { oldName: { contains: 'gokak', mode: 'insensitive' } }
      ]
    }
  });
  console.log("\nLegacy:");
  console.log(legacy.map(l => ({ name: l.apiName || l.oldName, address: l.apiAddresses, oldAddress: l.address, gstin: l.oldGstin })));
}
run().finally(() => process.exit(0));
