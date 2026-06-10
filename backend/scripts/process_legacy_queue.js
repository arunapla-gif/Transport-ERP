const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function run() {
  const pendingRecords = await prisma.legacyMaster.findMany({
    where: { 
      partyType: 'CONSIGNEE',
      status: { in: ['PENDING', 'FAILED_FETCH'] }
    }
  });

  const validRecords = pendingRecords.filter(r => r.oldGstin && r.oldGstin.length === 15);
  
  console.log(`Found ${validRecords.length} pending/failed records with 15-char GSTINs to fetch...`);
  
  const keySecret = process.env.APPYFLOW_KEY_SECRET || '7eWP3WelRNexYGJ172L3Hb8JNrY2';
  
  let successCount = 0;
  let failCount = 0;

  for (const record of validRecords) {
    const gstin = record.oldGstin.trim().toUpperCase();
    console.log(`\nFetching ${gstin} (${record.oldName})...`);

    try {
      const wbResponse = await fetch(`https://appyflow.in/api/verifyGST?gstNo=${gstin}&key_secret=${keySecret}`);
      
      if (!wbResponse.ok) {
        throw new Error(`HTTP Error ${wbResponse.status}`);
      }
      
      const wbData = await wbResponse.json();
      
      if (wbData.error) {
         throw new Error(wbData.message || 'Invalid GST');
      }
      
      const info = wbData.taxpayerInfo;
      if (!info) throw new Error('No taxpayer info found');

      const addr = info.pradr?.addr || {};
      const companyName = info.tradeNam || info.lgnm || '';
      
      const cleanAddressParts = (parts) => {
        let joined = parts.filter(Boolean).join(', ');
        if (!companyName) return joined;
        try {
          const cleanName = companyName.replace(/[^a-zA-Z0-9 ]/g, '').trim();
          if (cleanName) {
            const regexPattern = cleanName.split(/\s+/).join('\\s*[^a-zA-Z0-9]*\\s*');
            const re = new RegExp(regexPattern, 'gi');
            joined = joined.replace(re, '').replace(/^[,\\s]+/, '').replace(/[,\\s]+$/, '').trim();
          }
        } catch(e){}
        return joined;
      };

      const building = cleanAddressParts([addr.bno, addr.bnm, addr.st, addr.loc]);
      const city = addr.dst || '';
      const state = info.pradr?.addr?.stcd || '';
      const pincode = addr.pncd || '';
      
      const tradeNames = [];
      if (info.tradeNam && info.lgnm && info.tradeNam.toUpperCase() !== info.lgnm.toUpperCase()) {
        tradeNames.push(info.lgnm);
      }

      const allAddresses = [];
      if (info.adadr && Array.isArray(info.adadr)) {
        info.adadr.forEach(ad => {
          if (ad.addr) {
            allAddresses.push({
              address: cleanAddressParts([ad.addr.bno, ad.addr.bnm, ad.addr.st, ad.addr.loc]),
              city: ad.addr.dst || city,
              district: ad.addr.dst || city,
              state: ad.addr.stcd || state,
              pincode: ad.addr.pncd || pincode,
              phone: ''
            });
          }
        });
      }

      await prisma.legacyMaster.update({
        where: { id: record.id },
        data: {
          apiName: companyName,
          apiLegalName: info.lgnm,
          apiTradeNames: tradeNames,
          apiAddress: building,
          apiCity: city,
          apiDistrict: city,
          apiState: state,
          apiPincode: pincode,
          apiAddresses: allAddresses,
          status: 'READY',
          provider: 'AppyFlow'
        }
      });
      
      successCount++;
      console.log(`  -> SUCCESS! Found: ${companyName}`);
    } catch (e) {
      failCount++;
      console.log(`  -> FAILED: ${e.message}`);
      await prisma.legacyMaster.update({
        where: { id: record.id },
        data: { status: 'FAILED_FETCH' }
      });
    }

    // Delay to prevent hitting rate limits
    await new Promise(r => setTimeout(r, 100));
  }

  console.log(`\n--- Fetch Complete ---`);
  console.log(`Successfully Fetched: ${successCount}`);
  console.log(`Invalid/Failed: ${failCount}`);

  if (successCount > 0) {
    console.log(`\nMigrating ${successCount} READY records directly into Live Consignee DB...`);
    const readyRecords = await prisma.legacyMaster.findMany({
      where: { partyType: 'CONSIGNEE', status: 'READY' }
    });

    let migrated = 0;
    for (const r of readyRecords) {
      let uniqueName = r.apiName || r.oldName;
      let counter = 1;
      let saved = false;

      while (!saved) {
        try {
          await prisma.consignee.create({
            data: {
              name: uniqueName,
              gstin: r.oldGstin.toUpperCase(),
              address: r.apiAddress || r.oldAddress,
              city: r.apiCity || r.oldCity,
              district: r.apiDistrict,
              state: r.apiState,
              pincode: r.apiPincode,
              phone: r.oldPhone,
              tradeNames: r.apiTradeNames || [],
              addresses: r.apiAddresses || [],
              group: 'Normal',
              migrationType: 'API_ONLY'
            }
          });
          saved = true;
          migrated++;
          // Re-link GC records
          if (r.oldId) {
             await prisma.gC.updateMany({
               where: { consigneeId: Number(r.oldId) },
               data: { consigneeId: r.id }
             });
          }
          await prisma.legacyMaster.delete({ where: { id: r.id } });
        } catch (e) {
          if (e.code === 'P2002') {
            uniqueName = `${r.apiName || r.oldName} (${counter})`;
            counter++;
          } else {
            console.error(`Error migrating ${uniqueName}:`, e.message);
            break;
          }
        }
      }
    }
    console.log(`Successfully migrated ${migrated} records to the Live Database!`);
  }
}

run()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
