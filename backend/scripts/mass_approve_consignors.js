const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function run() {
  try {
    console.log("Fetching all READY Consignors from Staging...");
    
    const readyRecords = await prisma.legacyMaster.findMany({
      where: { 
        partyType: 'CONSIGNOR', 
        status: 'READY',
      }
    });

    if (readyRecords.length === 0) {
      console.log("No READY Consignors found in Staging. They might already be APPROVED.");
      return;
    }
    
    console.log(`Found ${readyRecords.length} Consignors ready to migrate. Applying 'Merge Name' strategy...`);

    let successCount = 0;
    let failCount = 0;

    for (const record of readyRecords) {
      // Create a safely merged name
      const finalName = record.apiName ? `${record.apiName} (${record.oldName})` : record.oldName;
      
      try {
        // Upsert by name so it doesn't fail on duplicates
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

        // Mark as APPROVED in Staging
        await prisma.legacyMaster.update({
          where: { id: record.id },
          data: { status: 'APPROVED' }
        });
        
        successCount++;
        process.stdout.write('.');
      } catch (err) {
        console.error(`\nFailed to migrate ${finalName}: ${err.message}`);
        failCount++;
      }
    }
    
    console.log(`\n\n✅ Mass Migration Complete!`);
    console.log(`Successfully migrated and approved: ${successCount} Consignors.`);
    if (failCount > 0) console.log(`Failed to migrate: ${failCount}`);

  } catch (err) {
    console.error("Migration script failed:", err);
  } finally {
    await prisma.$disconnect();
  }
}

run();
