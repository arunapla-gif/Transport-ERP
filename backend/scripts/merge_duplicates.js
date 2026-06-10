const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function run() {
  const consignees = await prisma.consignee.findMany({
    where: {
      gstin: { not: null },
      migrationType: { in: ['API_ONLY', 'MANUAL'] }
    }
  });

  const gstinMap = {};
  for (const c of consignees) {
    if (!c.gstin || c.gstin.trim() === '') continue;
    const gstin = c.gstin.toUpperCase();
    if (!gstinMap[gstin]) gstinMap[gstin] = [];
    gstinMap[gstin].push(c);
  }

  let mergedCount = 0;

  for (const [gstin, records] of Object.entries(gstinMap)) {
    if (records.length <= 1) continue;

    // Pick the primary record (the one with the shortest name, which is likely the original official one without (2) or (City))
    records.sort((a, b) => a.name.length - b.name.length);
    const primary = records[0];
    const duplicates = records.slice(1);

    console.log(`\nMerging ${duplicates.length} duplicates into PRIMARY: ${primary.name} (${gstin})`);

    let newAddresses = Array.isArray(primary.addresses) ? [...primary.addresses] : [];
    let newTradeNames = Array.isArray(primary.tradeNames) ? [...primary.tradeNames] : [];

    for (const dumb of duplicates) {
      console.log(`  -> Consuming duplicate: ${dumb.name}`);

      // Harvest dumb record's tradeNames
      const dumbTradeNames = Array.isArray(dumb.tradeNames) ? dumb.tradeNames : [];
      newTradeNames = [...new Set([...newTradeNames, ...dumbTradeNames])];

      // Harvest dumb record's primary address/city if it's different
      const addrString = [dumb.address, dumb.city, dumb.state, dumb.pincode].filter(Boolean).join(', ').toLowerCase();
      const primaryAddrString = [primary.address, primary.city, primary.state, primary.pincode].filter(Boolean).join(', ').toLowerCase();
      
      if (addrString && addrString !== primaryAddrString) {
        newAddresses.push({
          address: dumb.address || '',
          city: dumb.city || '',
          district: dumb.district || '',
          state: dumb.state || '',
          pincode: dumb.pincode || '',
          phone: dumb.phone || ''
        });
      }

      // Harvest any additional addresses the dumb record had
      const dumbAddresses = Array.isArray(dumb.addresses) ? dumb.addresses : [];
      newAddresses = [...newAddresses, ...dumbAddresses];

      // Reassign GC records
      await prisma.gC.updateMany({
        where: { consigneeId: dumb.id },
        data: { consigneeId: primary.id }
      });

      // Delete the dumb record
      await prisma.consignee.delete({
        where: { id: dumb.id }
      });
    }

    // Deduplicate addresses based on exact string match of full address
    const uniqueAddresses = [];
    const seen = new Set();
    for (const a of newAddresses) {
      const key = [a.address, a.city, a.pincode].join('|').toLowerCase();
      if (!seen.has(key)) {
        seen.add(key);
        uniqueAddresses.push(a);
      }
    }

    // Update the primary record
    await prisma.consignee.update({
      where: { id: primary.id },
      data: {
        addresses: uniqueAddresses,
        tradeNames: newTradeNames,
        migrationType: 'MERGED_NAME'
      }
    });

    mergedCount++;
    console.log(`  [SUCCESS] Primary updated and duplicates deleted.`);
  }

  console.log(`\n--- Completed! Successfully merged duplicates for ${mergedCount} GSTINs. ---`);
}

run()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
