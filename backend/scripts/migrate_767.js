const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function run() {
  try {
    const readyRecords = await prisma.legacyMaster.findMany({
      where: { partyType: 'CONSIGNOR', status: 'READY' }
    });

    let migratedCount = 0;
    let skippedCount = 0;

    console.log(`Analyzing ${readyRecords.length} READY records...`);

    for (const record of readyRecords) {
      if (record.oldName && record.apiName) {
        const cleanApi = (record.apiName || '').toUpperCase().replace(/[^A-Z0-9]/g, '');
        const cleanOld = (record.oldName || '').toUpperCase().replace(/[^A-Z0-9]/g, '');
        
        const isMismatch = cleanApi && cleanOld && cleanApi !== cleanOld && !cleanApi.includes(cleanOld) && !cleanOld.includes(cleanApi);
        
        if (!isMismatch) {
          // They are similar enough, so we migrate them!
          const finalName = record.apiName || record.oldName;

          try {
            await prisma.consignor.upsert({
              where: { name: finalName || 'Unknown' },
              update: {
                address: record.apiAddress || record.oldAddress,
                city: record.apiCity || record.oldCity,
                state: record.apiState,
                pincode: record.apiPincode,
                gstin: record.oldGstin,
                phone: record.oldPhone
              },
              create: {
                name: finalName || 'Unknown',
                address: record.apiAddress || record.oldAddress,
                city: record.apiCity || record.oldCity,
                state: record.apiState,
                pincode: record.apiPincode,
                gstin: record.oldGstin,
                phone: record.oldPhone
              }
            });

            // Mark as approved in LegacyMaster
            await prisma.legacyMaster.update({
              where: { id: record.id },
              data: { status: 'APPROVED' }
            });

            migratedCount++;
            process.stdout.write('.');
          } catch (err) {
            console.error(`\nFailed to migrate ${finalName}: ${err.message}`);
          }
        } else {
          // This is a mismatch (one of the 94), so we skip it.
          skippedCount++;
        }
      }
    }

    console.log(`\n\n✅ Mass Migration Complete!`);
    console.log(`Successfully migrated: ${migratedCount} matching records.`);
    console.log(`Safely skipped: ${skippedCount} mismatched records for later review.`);

  } catch (err) {
    console.error("Migration failed:", err);
  } finally {
    await prisma.$disconnect();
  }
}

run();
