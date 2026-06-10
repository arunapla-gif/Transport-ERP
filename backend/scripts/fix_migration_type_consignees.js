const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function run() {
  const consignees = await prisma.consignee.findMany();
  let oldData = 0, merged = 0, apiOnly = 0;
  
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
  await prisma.$disconnect();
}
run();
