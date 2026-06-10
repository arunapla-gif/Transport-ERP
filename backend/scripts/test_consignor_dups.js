const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
async function run() {
  const c2 = await prisma.consignor.count();
  console.log(`Active Consignors: ${c2}`);
  
  const gcs = await prisma.gC.count({ where: { consignorId: { not: null } } });
  console.log(`GCs with Consignors: ${gcs}`);

  const consignorsWithoutGcs = await prisma.consignor.count({
    where: { gcs: { none: {} } }
  });
  console.log(`Consignors without GCs: ${consignorsWithoutGcs}`);

  process.exit(0);
}
run();
