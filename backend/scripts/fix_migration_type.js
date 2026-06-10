const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function run() {
  const consignors = await prisma.consignor.findMany();
  let oldData = 0, merged = 0, apiOnly = 0;
  
  for (const c of consignors) {
    let type = 'MANUAL';
    if (!c.gstin) {
      type = 'OLD_DATA_ONLY';
      oldData++;
    } else if (c.name.includes('(') && c.name.includes(')')) {
      type = 'MERGED_NAME';
      merged++;
    } else {
      type = 'API_ONLY';
      apiOnly++;
    }
    await prisma.consignor.update({
      where: { id: c.id },
      data: { migrationType: type }
    });
  }
  
  console.log(`Consignors: Old: ${oldData}, Merged: ${merged}, API: ${apiOnly}`);
  
  const consignees = await prisma.consignee.findMany();
  oldData = 0; merged = 0; apiOnly = 0;
  
  for (const c of consignees) {
    let type = 'MANUAL';
    if (!c.gstin) {
      type = 'OLD_DATA_ONLY';
      oldData++;
    } else if (c.name.includes('(') && c.name.includes(')')) {
      type = 'MERGED_NAME';
      merged++;
    } else {
      type = 'API_ONLY';
      apiOnly++;
    }
    await prisma.consignee.update({
      where: { id: c.id },
      data: { migrationType: type }
    });
  }
  
  console.log(`Consignees: Old: ${oldData}, Merged: ${merged}, API: ${apiOnly}`);
  
}
run();
