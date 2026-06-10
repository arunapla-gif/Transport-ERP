const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function run() {
  try {
    const readyRecords = await prisma.legacyMaster.findMany({
      where: { partyType: 'CONSIGNOR', status: 'READY' }
    });

    let combinedCount = 0;
    let exactCount = 0;

    for (const record of readyRecords) {
      if (record.oldName && record.apiName) {
        const cleanApi = (record.apiName || '').toUpperCase().replace(/[^A-Z0-9]/g, '');
        const cleanOld = (record.oldName || '').toUpperCase().replace(/[^A-Z0-9]/g, '');
        
        if (cleanApi && cleanOld && cleanApi !== cleanOld && !cleanApi.includes(cleanOld) && !cleanOld.includes(cleanApi)) {
          combinedCount++;
        } else {
          exactCount++;
        }
      }
    }

    console.log(`Out of ${readyRecords.length} READY records:`);
    console.log(`- ${exactCount} are identical or very similar (will NOT be combined).`);
    console.log(`- ${combinedCount} are significantly different (WILL be combined).`);

  } catch (err) {
    console.error(err);
  } finally {
    await prisma.$disconnect();
  }
}

run();
