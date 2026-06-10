const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

function normalizeString(str) {
  if (!str) return '';
  return str.toUpperCase()
    .replace(/[^A-Z0-9]/g, '')
    .replace(/M\/S/g, '')
    .replace(/TRADERS/g, '')
    .replace(/TRADING/g, '')
    .replace(/AGENCIES/g, '')
    .replace(/AGENCY/g, '')
    .replace(/COMPANY/g, '')
    .replace(/CO/g, '')
    .replace(/FIREWORKS/g, '')
    .replace(/CRACKERS/g, '');
}

async function mergeFuzzyDuplicates() {
  try {
    const consignors = await prisma.consignor.findMany({ select: { id: true, name: true, gstin: true, addresses: true, tradeNames: true, address: true, city: true, district: true, state: true, pincode: true, phone: true } });
    const consignees = await prisma.consignee.findMany({ select: { id: true, name: true, gstin: true, addresses: true, tradeNames: true, address: true, city: true, district: true, state: true, pincode: true, phone: true } });

    async function processMerge(data, modelName, gcRelationField) {
      console.log(`\n=== Merging ${modelName} ===`);
      const groups = {};
      data.forEach(item => {
        const norm = normalizeString(item.name);
        if (norm.length < 3) return; // Skip too short
        if (!groups[norm]) groups[norm] = [];
        groups[norm].push(item);
      });

      let mergedCount = 0;
      for (const [key, items] of Object.entries(groups)) {
        if (items.length > 1) {
          // Find the primary record (the one with a GSTIN, or longest name if neither have GSTIN)
          const withGstin = items.filter(i => i.gstin);
          let primary;
          if (withGstin.length > 0) {
             primary = withGstin[0];
          } else {
             items.sort((a, b) => b.name.length - a.name.length);
             primary = items[0];
          }

          const duplicates = items.filter(i => i.id !== primary.id);
          if (duplicates.length === 0) continue;

          console.log(`\nMerging ${duplicates.length} duplicates into PRIMARY: ${primary.name} (${primary.gstin || 'No GSTIN'})`);

          let newAddresses = Array.isArray(primary.addresses) ? [...primary.addresses] : [];
          let newTradeNames = Array.isArray(primary.tradeNames) ? [...primary.tradeNames] : [];

          for (const dumb of duplicates) {
            console.log(`  -> Consuming: ${dumb.name}`);

            const dumbTradeNames = Array.isArray(dumb.tradeNames) ? dumb.tradeNames : [];
            newTradeNames = [...new Set([...newTradeNames, ...dumbTradeNames])];
            
            // Add the name of the duplicate as a known trade name so future imports don't recreate it
            if (dumb.name && !newTradeNames.includes(dumb.name)) {
                newTradeNames.push(dumb.name);
            }

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

            // Reassign GCs
            await prisma.gC.updateMany({
              where: { [gcRelationField]: dumb.id },
              data: { [gcRelationField]: primary.id }
            });

            // Delete the duplicate
            if (modelName === 'Consignor') {
              await prisma.consignor.delete({ where: { id: dumb.id } });
            } else {
              await prisma.consignee.delete({ where: { id: dumb.id } });
            }
          }

          // Update primary
          const uniqueAddresses = [];
          const seen = new Set();
          for (const a of newAddresses) {
            const key = [a.address, a.city, a.pincode].join('|').toLowerCase();
            if (!seen.has(key)) {
              seen.add(key);
              uniqueAddresses.push(a);
            }
          }

          if (modelName === 'Consignor') {
            await prisma.consignor.update({
              where: { id: primary.id },
              data: { addresses: uniqueAddresses, tradeNames: newTradeNames }
            });
          } else {
            await prisma.consignee.update({
              where: { id: primary.id },
              data: { addresses: uniqueAddresses, tradeNames: newTradeNames }
            });
          }

          mergedCount++;
        }
      }
      console.log(`\nCompleted ${mergedCount} merge groups for ${modelName}.`);
    }

    await processMerge(consignors, 'Consignor', 'consignorId');
    await processMerge(consignees, 'Consignee', 'consigneeId');

  } catch (e) {
    console.error(e);
  } finally {
    await prisma.$disconnect();
  }
}

mergeFuzzyDuplicates();
