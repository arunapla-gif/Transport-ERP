const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function run() {
  // Find all legacy master records that have an invalid GSTIN length (not 15)
  const fakeGstins = await prisma.legacyMaster.findMany({
    where: {
      partyType: 'CONSIGNEE'
    }
  });

  const invalidRecords = fakeGstins.filter(r => r.oldGstin && r.oldGstin.length !== 15);

  console.log(`Found ${invalidRecords.length} records in Legacy Master that have fake/invalid GSTINs (e.g. Phone numbers in GSTIN column).`);

  let movedToRetailCount = 0;

  for (const r of invalidRecords) {
    // Treat oldGstin as phone
    const phoneNum = r.oldGstin.replace(/[^0-9]/g, '');
    let migrationType = 'RETAIL_NO_PHONE';
    if (phoneNum.length >= 8) {
      migrationType = 'RETAIL_WITH_PHONE';
    }

    // Insert into Consignee as retail
    // Check if name already exists
    let uniqueName = r.oldName || 'UNKNOWN';
    let counter = 1;
    let saved = false;

    while (!saved) {
      try {
        await prisma.consignee.create({
          data: {
            name: uniqueName,
            address: r.oldAddress || null,
            phone: phoneNum || null,
            group: 'Retail',
            migrationType: migrationType
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

    // Delete from LegacyMaster
    await prisma.legacyMaster.delete({ where: { id: r.id } });
    movedToRetailCount++;
  }

  console.log(`\nSuccessfully moved ${movedToRetailCount} invalid GSTIN records back to Retail Consignees.`);
}

run()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
