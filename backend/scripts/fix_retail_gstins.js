require('dotenv').config();
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
  const retailConsignees = await prisma.consignee.findMany({
    where: { migrationType: 'RETAIL_IMPORT' }
  });

  const loosePattern = /\b[0-9]{2}[A-Za-z]{5}[0-9]{4}[A-Za-z]{1}[1-9A-Za-z]{1}[Zz]{1}[0-9A-Za-z]{1}\b/;
  
  const toProcess = [];
  for (const c of retailConsignees) {
    if (!c.phone) continue;
    const parts = c.phone.split(/[,/\s]+/);
    for (const part of parts) {
      const cleanPart = part.trim();
      if (cleanPart.length === 15 && loosePattern.test(cleanPart)) {
        toProcess.push({ record: c, gstin: cleanPart.toUpperCase() });
        break;
      }
    }
  }

  console.log(`Found ${toProcess.length} retail consignees to upgrade to API Data.`);

  const allConsignees = await prisma.consignee.findMany({ select: { name: true } });
  const existingNames = new Set(allConsignees.map(c => c.name.toLowerCase()));

  for (const item of toProcess) {
    const { record, gstin } = item;
    console.log(`\nFetching ${gstin} for ${record.name}...`);
    
    try {
      const keySecret = process.env.APPYFLOW_KEY_SECRET || '7eWP3WelRNexYGJ172L3Hb8JNrY2';
      const response = await fetch(`https://appyflow.in/api/verifyGST?gstNo=${gstin}&key_secret=${keySecret}`);
      
      if (!response.ok) throw new Error('API request failed');
      const data = await response.json();
      
      if (data.error) throw new Error(data.message || 'Invalid GSTIN');
      const info = data.taxpayerInfo;
      if (!info) throw new Error('No taxpayer info');

      const addr = info.pradr?.addr || {};
      const companyName = info.tradeNam || info.lgnm || '';
      
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

      // Handle duplicate name
      let uniqueName = companyName || record.name;
      let counter = 1;
      
      // Since we are UPDATING an existing record, if the name is the same as its own current name, that's fine.
      // But if the API name belongs to a DIFFERENT record, we must make it unique.
      if (uniqueName.toLowerCase() !== record.name.toLowerCase()) {
        while (existingNames.has(uniqueName.toLowerCase())) {
          if (counter === 1 && apiCity) {
            uniqueName = `${companyName} (${apiCity})`;
          } else {
            uniqueName = `${companyName} (${counter})`;
          }
          counter++;
        }
        existingNames.add(uniqueName.toLowerCase());
      } else {
        uniqueName = record.name; // Keep existing unique name
      }

      // Remove the GSTIN from the phone field
      let cleanPhone = record.phone.replace(new RegExp(gstin, 'ig'), '').replace(/[,/\s]+$/, '').replace(/^[,/\s]+/, '').trim();
      if (!cleanPhone) cleanPhone = null;

      await prisma.consignee.update({
        where: { id: record.id },
        data: {
          name: uniqueName,
          gstin: gstin,
          phone: cleanPhone,
          address: apiAddress,
          city: apiCity,
          district: apiDistrict,
          state: apiState,
          pincode: apiPincode,
          addresses: apiAddresses,
          legalName: info.lgnm || '',
          tradeNames: info.tradeNam ? [info.tradeNam] : [],
          group: null, // Remove from Retail
          migrationType: 'API_ONLY' // Move to API Data tab!
        }
      });
      console.log(`[SUCCESS] Upgraded ${record.name} -> ${uniqueName}`);
      
      // Delay to avoid crashing Neon
      await new Promise(r => setTimeout(r, 200));
      
    } catch (err) {
      console.log(`[FAILED] ${gstin} - ${err.message}`);
    }
  }

  console.log("\n--- Upgrade Complete ---");
}

run()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
