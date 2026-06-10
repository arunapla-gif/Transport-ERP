const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function run() {
  const legacyConsignors = await prisma.legacyMaster.findMany({ where: { partyType: 'CONSIGNOR' } });
  const legacyCnorGstins = new Set(legacyConsignors.map(l => l.oldGstin).filter(Boolean));
  const legacyCnorNames = new Set(legacyConsignors.map(l => l.oldName).filter(Boolean));

  const consignors = await prisma.consignor.findMany();
  for (const c of consignors) {
    let type = 'API_ONLY';
    if (!c.gstin) {
      type = 'OLD_DATA_ONLY';
    } else if (legacyCnorGstins.has(c.gstin) || legacyCnorNames.has(c.name)) {
      type = 'MERGED_NAME';
    }
    
    await prisma.consignor.update({
      where: { id: c.id },
      data: { migrationType: type }
    });
  }

  const legacyConsignees = await prisma.legacyMaster.findMany({ where: { partyType: 'CONSIGNEE' } });
  const legacyCneeGstins = new Set(legacyConsignees.map(l => l.oldGstin).filter(Boolean));
  const legacyCneeNames = new Set(legacyConsignees.map(l => l.oldName).filter(Boolean));

  const consignees = await prisma.consignee.findMany();
  for (const c of consignees) {
    let type = 'API_ONLY';
    if (!c.gstin) {
      type = 'OLD_DATA_ONLY';
    } else if (legacyCneeGstins.has(c.gstin) || legacyCneeNames.has(c.name)) {
      type = 'MERGED_NAME';
    }
    
    await prisma.consignee.update({
      where: { id: c.id },
      data: { migrationType: type }
    });
  }

  console.log("Migration Types Fixed!");
  await prisma.$disconnect();
}
run();
