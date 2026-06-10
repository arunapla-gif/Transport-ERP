const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function run() {
  const approved = await prisma.legacyMaster.findMany({
    where: { status: 'APPROVED', partyType: 'CONSIGNEE' }
  });

  let inMaster = 0;
  let missing = 0;

  for (const a of approved) {
    const exists = await prisma.consignee.findFirst({
      where: { gstin: a.oldGstin }
    });
    if (exists) inMaster++;
    else missing++;
  }

  console.log(`Out of ${approved.length} APPROVED records in LegacyMaster:`);
  console.log(`Found in live Consignee master: ${inMaster}`);
  console.log(`Missing from live Consignee master: ${missing}`);
}

run().finally(() => prisma.$disconnect());
