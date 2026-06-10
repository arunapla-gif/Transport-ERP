const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function run() {
  console.log('Starting Auto-Merge for Consignors...');
  
  const officialConsignors = await prisma.consignor.findMany({
    where: { gstin: { not: null } }
  });
  
  const dumbConsignors = await prisma.consignor.findMany({
    where: { gstin: null }
  });

  const normalize = (name) => name.toUpperCase()
    .replace(/[^A-Z0-9]/g, '')
    .replace(/AGENCIES|AGENCY|TRADERS|TRADING|ENTERPRISES|FIREWORKS|FIRE|WORKS|AND|CO|SRI|SREE|M\/S|THE|PVT|LTD/g, '');

  let mergedCount = 0;
  let gcsMovedCount = 0;

  for (const off of officialConsignors) {
    const normOff = normalize(off.name);
    if (normOff.length < 3) continue;

    for (const dumb of dumbConsignors) {
      const normDumb = normalize(dumb.name);
      if (normDumb.length < 3) continue;

      if (normOff === normDumb || normOff.includes(normDumb) || normDumb.includes(normOff)) {
        // We found a match! Let's do the merge.
        console.log(`[MERGING] '${dumb.name}' => '${off.name}' (${off.gstin})`);

        try {
          // 1. Move all GCs from Dumb to Official
          const updateRes = await prisma.gC.updateMany({
            where: { consignorId: dumb.id },
            data: { consignorId: off.id }
          });
          
          gcsMovedCount += updateRes.count;

          // 2. Delete the Dumb Profile
          await prisma.consignor.delete({
            where: { id: dumb.id }
          });

          mergedCount++;
          
          // Remove this dumb from the array so we don't merge it twice
          const dumbIndex = dumbConsignors.findIndex(d => d.id === dumb.id);
          if (dumbIndex !== -1) dumbConsignors.splice(dumbIndex, 1);
          
        } catch (err) {
          console.error(`Failed to merge ${dumb.name}:`, err.message);
        }
        break; 
      }
    }
  }

  console.log('-----------------------------------');
  console.log(`MERGE COMPLETE!`);
  console.log(`Deleted ${mergedCount} Duplicate Consignors.`);
  console.log(`Re-linked ${gcsMovedCount} Historical GCs to Official GSTIN Profiles!`);
  console.log('-----------------------------------');

  process.exit(0);
}

run();
