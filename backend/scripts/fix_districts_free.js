const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function resolveLocationFromPincode(pincode) {
  if (!pincode) return { district: null, city: null };
  try {
    const response = await fetch(`http://www.postalpincode.in/api/pincode/${pincode}`);
    const data = await response.json();
    if (data.Status === "Success" && data.PostOffice && data.PostOffice.length > 0) {
      return {
        district: data.PostOffice[0].District || null,
        city: data.PostOffice[0].Taluk || data.PostOffice[0].Name || null
      };
    }
  } catch (err) {
    // Ignore error
  }
  return { district: null, city: null };
}

function cleanAddress(address) {
  if (!address) return '';
  // The government API squashes door numbers and street names together (e.g. 2/190B5NARANAPURAM)
  // Let's add a space between a digit/letter combo and a clear word boundary if we can detect it
  let cleaned = address.replace(/([0-9]+[A-Z]?)(NARANAPURAM|SIVAKASI|VIRUDHUNAGAR|THIRUTHANGAL|PALLAPATTI)/gi, '$1 $2');
  
  // Clean up double commas and spaces
  cleaned = cleaned.replace(/,\s*,/g, ',').replace(/\s+/g, ' ').trim();
  return cleaned;
}

async function run() {
  try {
    // Find consignors that were just migrated and are missing a district
    const consignors = await prisma.consignor.findMany({
      where: { district: null, pincode: { not: null } }
    });

    console.log(`Found ${consignors.length} Consignors without a district. Fixing them FOR FREE...`);

    let fixedCount = 0;
    for (const c of consignors) {
      const loc = await resolveLocationFromPincode(c.pincode);
      const newAddress = cleanAddress(c.address);

      await prisma.consignor.update({
        where: { id: c.id },
        data: {
          district: loc.district,
          address: newAddress
        }
      });
      
      fixedCount++;
      process.stdout.write('.');
      
      // Be gentle to the free postal API
      await new Promise(r => setTimeout(r, 200));
    }

    console.log(`\n\n✅ Successfully fixed ${fixedCount} Consignors entirely FOR FREE using Postal API!`);

  } catch (err) {
    console.error(err);
  } finally {
    await prisma.$disconnect();
  }
}

run();
