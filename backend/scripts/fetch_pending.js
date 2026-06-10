const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

const cleanAddressParts = (parts, companyName) => {
  let joined = parts.filter(Boolean).join(', ');
  if (!companyName) return joined;
  try {
    const cleanName = companyName.replace(/[^a-zA-Z0-9 ]/g, '').trim();
    if (cleanName) {
      const regexPattern = cleanName.split(/\s+/).join('\\s*[^a-zA-Z0-9]*\\s*');
      const regex = new RegExp('^' + regexPattern + '\\s*[^a-zA-Z0-9]*\\s*', 'i');
      joined = joined.replace(regex, '');
    }
  } catch (e) {}
  return joined;
};

async function run() {
  const pending = await prisma.legacyMaster.findMany({
    where: { partyType: 'CONSIGNEE', status: 'PENDING' }
  });

  console.log(`Found ${pending.length} pending consignees. Starting fetch...`);

  for (const record of pending) {
    const gstin = record.oldGstin.trim();
    try {
      console.log(`Fetching ${gstin}...`);
      const keySecret = process.env.APPYFLOW_KEY_SECRET || '7eWP3WelRNexYGJ172L3Hb8JNrY2';
      const response = await fetch(`https://appyflow.in/api/verifyGST?gstNo=${gstin}&key_secret=${keySecret}`);
      
      if (!response.ok) throw new Error('Network response not ok');
      const data = await response.json();
      
      if (data.error) throw new Error(data.message || 'Invalid GST');
      
      const info = data.taxpayerInfo;
      if (!info) throw new Error('No taxpayer info');

      const addr = info.pradr?.addr || {};
      const companyName = info.tradeNam || info.lgnm || '';
      
      const apiLegalName = info.lgnm || '';
      const rawTradeName = info.tradeNam || '';
      const apiTradeNames = rawTradeName ? [rawTradeName] : [];
      
      const apiName = companyName;
      const apiAddress = cleanAddressParts([addr.bno, addr.bnm, addr.st, addr.flno], companyName);
      const apiCity = addr.loc || addr.city || '';
      const apiDistrict = addr.dst || '';
      const apiState = addr.stcd || '';
      const apiPincode = addr.pncd || addr.pincode || '';
      
      const apiAddresses = (info.adadr || []).map(a => {
        const adr = a.addr || {};
        return {
          address: cleanAddressParts([adr.bno, adr.bnm, adr.st, adr.flno], companyName),
          city: adr.loc || adr.city || '',
          district: adr.dst || '',
          state: adr.stcd || '',
          pincode: adr.pncd || adr.pincode || ''
        };
      });

      await prisma.legacyMaster.update({
        where: { id: record.id },
        data: {
          apiName, apiAddress, apiCity, apiDistrict, apiState, apiPincode, 
          apiAddresses, apiLegalName, apiTradeNames, 
          provider: 'APPYFLOW', status: 'READY'
        }
      });
      console.log(`[SUCCESS] ${gstin} updated to READY.`);
    } catch (error) {
      console.log(`[FAILED] ${gstin} - ${error.message}`);
      await prisma.legacyMaster.update({
        where: { id: record.id },
        data: { status: 'FAILED_FETCH' }
      });
    }
    
    // small delay to prevent rate limit
    await new Promise(r => setTimeout(r, 500));
  }
  console.log("Done fetching!");
}

run()
  .catch(e => console.error(e))
  .finally(() => prisma.$disconnect());
