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

async function findDuplicates() {
  try {
    const consignors = await prisma.consignor.findMany({ select: { id: true, name: true, gstin: true } });
    const consignees = await prisma.consignee.findMany({ select: { id: true, name: true, gstin: true } });

    function analyze(data, label) {
      console.log(`\n=== Analyzing ${label} (${data.length} total) ===`);
      
      const groups = {};
      data.forEach(item => {
        const norm = normalizeString(item.name);
        if (norm.length < 3) return; // Skip too short
        if (!groups[norm]) groups[norm] = [];
        groups[norm].push(item);
      });

      let duplicateCount = 0;
      for (const [key, items] of Object.entries(groups)) {
        if (items.length > 1) {
          duplicateCount++;
          console.log(`\nPotential Match Group:`);
          items.forEach(i => console.log(`  - ID: ${i.id} | Name: "${i.name}" | GSTIN: ${i.gstin || 'None'}`));
        }
      }
      console.log(`\nFound ${duplicateCount} potential duplicate groups in ${label}.`);
    }

    analyze(consignors, 'Consignors');
    analyze(consignees, 'Consignees');

  } catch (e) {
    console.error(e);
  } finally {
    await prisma.$disconnect();
  }
}

findDuplicates();
