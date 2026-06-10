const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function run() {
  const legacyConsignors = await prisma.legacyMaster.findMany({ where: { status: 'APPROVED', partyType: 'CONSIGNOR' } });
  const consignors = await prisma.consignor.findMany();
  
  for (const c of consignors) {
    let type = 'API_ONLY';
    
    // 1. Did it come from legacy?
    let legacy = legacyConsignors.find(l => l.oldName === c.name || (c.gstin && l.oldGstin === c.gstin));
    
    if (legacy) {
      if (!legacy.apiName) {
        // API never fetched it
        type = 'OLD_DATA_ONLY';
      } else if (c.name === legacy.oldName && c.address === legacy.oldAddress) {
        // They explicitly clicked "Keep Old Data" despite API fetch
        type = 'OLD_DATA_ONLY';
      } else if (c.name.includes('(') && c.name.includes(')')) {
        // The name was literally physically MERGED: API NAME (OLD NAME)
        type = 'MERGED_NAME';
      } else {
        // It successfully fetched from API, and the name was clean, so it's just pure API Data
        type = 'API_ONLY';
      }
    } else {
      // Didn't come from legacy.
      if (!c.gstin) {
        type = 'OLD_DATA_ONLY'; // Manual but dumb
      } else if (c.name.includes('(') && c.name.includes(')')) {
        type = 'MERGED_NAME';
      }
    }
    
    await prisma.consignor.update({ where: { id: c.id }, data: { migrationType: type } });
  }

  const legacyConsignees = await prisma.legacyMaster.findMany({ where: { status: 'APPROVED', partyType: 'CONSIGNEE' } });
  const consignees = await prisma.consignee.findMany();
  
  for (const c of consignees) {
    let type = 'API_ONLY';
    let legacy = legacyConsignees.find(l => l.oldName === c.name || (c.gstin && l.oldGstin === c.gstin));
    
    if (legacy) {
      if (!legacy.apiName) {
        type = 'OLD_DATA_ONLY';
      } else if (c.name === legacy.oldName && c.address === legacy.oldAddress) {
        type = 'OLD_DATA_ONLY';
      } else if (c.name.includes('(') && c.name.includes(')')) {
        type = 'MERGED_NAME';
      } else {
        type = 'API_ONLY';
      }
    } else {
      if (!c.gstin) {
        type = 'OLD_DATA_ONLY';
      } else if (c.name.includes('(') && c.name.includes(')')) {
        type = 'MERGED_NAME';
      }
    }
    
    await prisma.consignee.update({ where: { id: c.id }, data: { migrationType: type } });
  }

  console.log('Fixed classification correctly!');
  await prisma.$disconnect();
}

run();
