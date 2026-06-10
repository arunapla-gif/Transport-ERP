const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function run() {
  const retailWithPhone = await prisma.consignee.findMany({
    where: { migrationType: 'RETAIL_WITH_PHONE' }
  });

  const phonePattern = /\b\d{10,}\b/g; 

  console.log(`Analyzing ${retailWithPhone.length} records in RETAIL_WITH_PHONE...`);
  let movedCount = 0;

  for (const c of retailWithPhone) {
    let newName = c.name;
    let newPhone = c.phone || '';
    let updated = false;

    // Find phone numbers in the name
    const match = newName.match(phonePattern);
    if (match) {
      for (const p of match) {
        // Append to phone field if not already there
        if (!newPhone.includes(p)) {
          newPhone = newPhone ? `${newPhone}, ${p}` : p;
        }
        // Remove from name
        newName = newName.replace(p, '');
      }
      // Clean up the name (remove dangling brackets, commas, dashes, extra spaces)
      newName = newName.replace(/[\[\(\{]\s*[\]\)\}]/g, ''); // empty brackets like ()
      newName = newName.replace(/[-,\s]+$/g, ''); // trailing dashes/commas
      newName = newName.replace(/^[-,\s]+/g, ''); // leading dashes/commas
      newName = newName.replace(/\s{2,}/g, ' ').trim(); // multiple spaces

      if (!newName) newName = "UNKNOWN RETAIL CUSTOMER"; // Fallback if name was literally just a phone number

      if (newName !== c.name) {
        let saveName = newName;
        let counter = 1;
        let saved = false;
        
        while (!saved) {
          try {
            await prisma.consignee.update({
              where: { id: c.id },
              data: { name: saveName, phone: newPhone }
            });
            saved = true;
            movedCount++;
          } catch (e) {
            if (e.code === 'P2002') {
              saveName = `${newName} (${counter})`;
              counter++;
            } else {
              throw e;
            }
          }
        }
      }
    }
  }

  console.log(`\n--- Moved Phone Numbers from Name to Phone Field: ${movedCount} records ---`);

  // Now check for duplicates (Same Name and Phone)
  const updatedRecords = await prisma.consignee.findMany({
    where: { migrationType: 'RETAIL_WITH_PHONE' }
  });

  const uniqueMap = {};
  for (const c of updatedRecords) {
    // Strip trailing digits in brackets like (1), (2) that we just added for uniqueness
    let baseName = c.name.replace(/\(\d+\)$/, '').trim();
    const cleanName = baseName.toLowerCase().replace(/[^a-z0-9]/g, '');
    const cleanPhone = (c.phone || '').replace(/[^0-9]/g, '');
    
    if (!cleanName && !cleanPhone) continue;

    // We consider it a duplicate if the Name matches AND either they share a phone number or one has no phone
    // Actually user said: "CHECK FOR DUPLICATE WITH NAME AND NUMBER"
    const key = `${cleanName}_${cleanPhone}`;
    if (!uniqueMap[key]) uniqueMap[key] = [];
    uniqueMap[key].push(c);
  }

  let duplicateGroups = 0;
  let totalDuplicates = 0;

  console.log(`\n--- Checking for Duplicates (Matching Name & Phone) ---`);
  for (const [key, records] of Object.entries(uniqueMap)) {
    if (records.length > 1) {
      duplicateGroups++;
      totalDuplicates += records.length;
      console.log(`\nDuplicate Group (${records.length} records):`);
      for (const r of records) {
        console.log(`  - ID: ${r.id} | Name: ${r.name} | Phone: ${r.phone} | City: ${r.city}`);
      }
    }
  }

  if (duplicateGroups === 0) {
    console.log(`\nZero duplicates found! Every combination of Name & Phone is unique.`);
  } else {
    console.log(`\nFound ${duplicateGroups} groups of duplicates (Total ${totalDuplicates} records).`);
  }
}

run()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
