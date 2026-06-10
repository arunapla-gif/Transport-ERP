const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function run() {
  const updatedRecords = await prisma.consignee.findMany({
    where: { migrationType: 'RETAIL_WITH_PHONE' }
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

  let mergedCount = 0;

  for (const [key, records] of Object.entries(uniqueMap)) {
    if (records.length <= 1) continue;

    records.sort((a, b) => a.name.length - b.name.length);
    const primary = records[0];
    const duplicates = records.slice(1);

    console.log(`\nMerging ${duplicates.length} duplicates into PRIMARY: ${primary.name}`);

    let newAddresses = Array.isArray(primary.addresses) ? [...primary.addresses] : [];

    for (const dumb of duplicates) {
      console.log(`  -> Consuming duplicate: ${dumb.name}`);

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

      const dumbAddresses = Array.isArray(dumb.addresses) ? dumb.addresses : [];
      newAddresses = [...newAddresses, ...dumbAddresses];

      await prisma.gC.updateMany({
        where: { consigneeId: dumb.id },
        data: { consigneeId: primary.id }
      });

      await prisma.consignee.delete({
        where: { id: dumb.id }
      });
    }

    const uniqueAddresses = [];
    const seen = new Set();
    for (const a of newAddresses) {
      const addrKey = [a.address, a.city, a.pincode].join('|').toLowerCase();
      if (!seen.has(addrKey)) {
        seen.add(addrKey);
        uniqueAddresses.push(a);
      }
    }

    // Update primary record, keep in RETAIL_WITH_PHONE
    await prisma.consignee.update({
      where: { id: primary.id },
      data: {
        addresses: uniqueAddresses
      }
    });

    mergedCount++;
    console.log(`  [SUCCESS] Primary updated and duplicates deleted.`);
  }

  console.log(`\n--- Completed! Successfully merged duplicates for ${mergedCount} Retail Customers. ---`);
}

run()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
