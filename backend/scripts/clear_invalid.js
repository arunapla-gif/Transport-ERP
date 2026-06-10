const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function run() {
  const invalid = await prisma.legacyMaster.findMany({
    where: { status: 'FAILED_FETCH' }
  });

  let moved = 0;
  for (const r of invalid) {
    let uniqueName = r.oldName || 'UNKNOWN';
    let counter = 1;
    let saved = false;

    while (!saved) {
      try {
        await prisma.consignee.create({
          data: {
            name: uniqueName,
            address: r.oldAddress || null,
            phone: null,
            group: 'Retail',
            migrationType: 'RETAIL_NO_PHONE', // because they don't have phone numbers, just invalid 15-char GSTINs
            gstin: null // Do not save the invalid GSTIN
          }
        });
        saved = true;
      } catch (e) {
        if (e.code === 'P2002') {
          uniqueName = `${r.oldName || 'UNKNOWN'} (${counter})`;
          counter++;
        } else {
          throw e;
        }
      }
    }

    await prisma.legacyMaster.delete({ where: { id: r.id } });
    moved++;
  }

  console.log(`Successfully converted ${moved} invalid GSTIN records to Retail.`);
}

run().finally(() => prisma.$disconnect());
