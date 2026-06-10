const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function run() {
  const records = await prisma.consignee.findMany({
    where: { 
      gstin: { not: null, not: '' },
      legalName: null 
    }
  });

  console.log(`Found ${records.length} Consignees missing Legal Name/Trade Names. Backfilling now...`);

  const keySecret = process.env.APPYFLOW_KEY_SECRET || '7eWP3WelRNexYGJ172L3Hb8JNrY2';
  let successCount = 0;

  for (const record of records) {
    const gstin = record.gstin.trim().toUpperCase();
    if (gstin.length !== 15) continue;

    try {
      const wbResponse = await fetch(`https://appyflow.in/api/verifyGST?gstNo=${gstin}&key_secret=${keySecret}`);
      if (!wbResponse.ok) continue;
      
      const wbData = await wbResponse.json();
      if (wbData.error || !wbData.taxpayerInfo) continue;
      
      const info = wbData.taxpayerInfo;
      const tradeNames = [];
      if (info.tradeNam && info.lgnm && info.tradeNam.toUpperCase() !== info.lgnm.toUpperCase()) {
        tradeNames.push(info.lgnm);
      }

      await prisma.consignee.update({
        where: { id: record.id },
        data: {
          legalName: info.lgnm || null,
          tradeNames: tradeNames
        }
      });
      
      successCount++;
      process.stdout.write('.');
    } catch (e) {
      process.stdout.write('x');
    }

    // Delay to prevent hitting rate limits
    await new Promise(r => setTimeout(r, 100));
  }

  console.log(`\nSuccessfully backfilled ${successCount} records!`);
}

run().finally(() => prisma.$disconnect());
