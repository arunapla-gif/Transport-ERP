const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function run() {
  const legacyConsignors = await prisma.legacyMaster.findMany({ where: { status: 'APPROVED', partyType: 'CONSIGNOR' } });
  const consignors = await prisma.consignor.findMany();
  
  let fixedCnor = 0;
  for (const c of consignors) {
    // Find matching legacy record. Prefer match by oldName first, then oldGstin.
    let legacy = legacyConsignors.find(l => l.oldName === c.name || (c.gstin && l.oldGstin === c.gstin));
    
    let type = 'API_ONLY';
    if (legacy) {
      if (!legacy.apiName) {
        // API was never fetched for this record, must be OLD DATA
        type = 'OLD_DATA_ONLY';
      } else {
        // API was fetched. Did they use it?
        if (c.name === legacy.oldName && c.address === legacy.oldAddress) {
          type = 'OLD_DATA_ONLY';
        } else {
          type = 'MERGED_NAME';
        }
      }
    } else {
      if (!c.gstin) {
        type = 'OLD_DATA_ONLY';
      }
    }
    
    await prisma.consignor.update({ where: { id: c.id }, data: { migrationType: type } });
    fixedCnor++;
  }
  
  const legacyConsignees = await prisma.legacyMaster.findMany({ where: { status: 'APPROVED', partyType: 'CONSIGNEE' } });
  const consignees = await prisma.consignee.findMany();
  
  let fixedCnee = 0;
  for (const c of consignees) {
    let legacy = legacyConsignees.find(l => l.oldName === c.name || (c.gstin && l.oldGstin === c.gstin));
    
    let type = 'API_ONLY';
    if (legacy) {
      if (!legacy.apiName) {
        type = 'OLD_DATA_ONLY';
      } else {
        if (c.name === legacy.oldName && c.address === legacy.oldAddress) {
          type = 'OLD_DATA_ONLY';
        } else {
          type = 'MERGED_NAME';
        }
      }
    } else {
      if (!c.gstin) {
        type = 'OLD_DATA_ONLY';
      }
    }
    
    await prisma.consignee.update({ where: { id: c.id }, data: { migrationType: type } });
    fixedCnee++;
  }
  
  console.log(`Fixed ${fixedCnor} consignors and ${fixedCnee} consignees based on precise legacy matching.`);
  await prisma.$disconnect();
}
run();
