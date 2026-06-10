const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function run() {
  const allRetail = await prisma.consignee.findMany({
    where: { migrationType: { in: ['RETAIL_WITH_PHONE', 'RETAIL_NO_PHONE', 'RETAIL_IMPORT'] } }
  });

  console.log(`Deep cleaning ${allRetail.length} retail records...`);
  let movedCount = 0;
  let renameCount = 0;

  for (const c of allRetail) {
    let newName = c.name;
    let newPhone = c.phone || '';
    let needsUpdate = false;

    // 1. Extract embedded phone numbers (even with dashes or spaces)
    // We look for 8+ digits, potentially separated by spaces, dashes, or dots
    // e.g. 99 88 77 66 55 or 998-877-6655
    const loosePhoneRegex = /(?:(?:\+91|0)?[-.\s]*)(?:\d[-.\s]*){8,}\d/g;
    
    const matches = newName.match(loosePhoneRegex);
    if (matches) {
      for (const m of matches) {
        const cleanNumber = m.replace(/[^\d]/g, '');
        if (cleanNumber.length >= 8) {
          if (!newPhone.includes(cleanNumber)) {
            newPhone = newPhone ? `${newPhone}, ${cleanNumber}` : cleanNumber;
          }
          newName = newName.replace(m, '');
        }
      }
    }

    // 2. Remove "PH;", "PH:", "MOB:", etc.
    const junkRegex = /\b(?:PH|MOB|PHONE|MOBILE|CELL)[\s:;.-]*/gi;
    newName = newName.replace(junkRegex, '');

    // 3. General cleanup
    newName = newName.replace(/[\[\(\{]\s*[\]\)\}]/g, ''); // empty brackets
    newName = newName.replace(/[-_.,;:\s]+$/g, ''); // trailing junk
    newName = newName.replace(/^[-_.,;:\s]+/g, ''); // leading junk
    newName = newName.replace(/\s{2,}/g, ' ').trim(); // multiple spaces

    if (!newName) newName = "UNKNOWN RETAIL CUSTOMER";

    // Re-determine correct tab
    const cleanPhoneCheck = newPhone.replace(/\D/g, '');
    const targetType = cleanPhoneCheck.length >= 8 ? 'RETAIL_WITH_PHONE' : 'RETAIL_NO_PHONE';

    if (newName !== c.name || newPhone !== (c.phone || '') || targetType !== c.migrationType) {
      let saveName = newName;
      let counter = 1;
      let saved = false;
      
      while (!saved) {
        try {
          await prisma.consignee.update({
            where: { id: c.id },
            data: { name: saveName, phone: newPhone, migrationType: targetType }
          });
          saved = true;
          if (newName !== c.name) renameCount++;
          if (newPhone !== (c.phone || '')) movedCount++;
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

  console.log(`\n--- Deep Clean Complete ---`);
  console.log(`Extracted new phones: ${movedCount}`);
  console.log(`Cleaned up names (removed PH;/Junk): ${renameCount}`);

  // Now check for duplicates AGAIN
  const updatedRecords = await prisma.consignee.findMany({
    where: { migrationType: { in: ['RETAIL_WITH_PHONE', 'RETAIL_NO_PHONE'] } }
  });

  const uniqueMap = {};
  for (const c of updatedRecords) {
    let baseName = c.name.replace(/\(\d+\)$/, '').trim();
    const cleanName = baseName.toLowerCase().replace(/[^a-z0-9]/g, '');
    const cleanPhone = (c.phone || '').replace(/[^0-9]/g, '');
    
    if (!cleanName && !cleanPhone) continue;

    const key = `${cleanName}_${cleanPhone}`;
    if (!uniqueMap[key]) uniqueMap[key] = [];
    uniqueMap[key].push(c);
  }

  let duplicateGroups = 0;
  for (const [key, records] of Object.entries(uniqueMap)) {
    if (records.length > 1) {
      duplicateGroups++;
      console.log(`\nFound Duplicate Group: ${records[0].name} (${records.length} records)`);
    }
  }

  console.log(`\nTotal remaining duplicate groups: ${duplicateGroups}`);
}

run()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
