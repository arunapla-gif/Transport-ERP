const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function runTests() {
  console.log("=== Testing GC Pagination ===");
  const gcTotal = await prisma.gC.count();
  const limit = 2;
  const page = 1;
  const skip = (page - 1) * limit;
  const gcs = await prisma.gC.findMany({ skip, take: limit, orderBy: { id: 'desc' } });
  console.log(`Total GCs in DB: ${gcTotal}`);
  console.log(`Page ${page} Limit ${limit} Returned: ${gcs.length} GCs`);
  if (gcs.length > 0) {
    console.log("Pagination query succeeds.");
  }

  console.log("\n=== Testing GDM Pagination ===");
  const gdmTotal = await prisma.gDM.count();
  const gdms = await prisma.gDM.findMany({ skip, take: limit, orderBy: { id: 'desc' } });
  console.log(`Total GDMs in DB: ${gdmTotal}`);
  console.log(`Page ${page} Limit ${limit} Returned: ${gdms.length} GDMs`);
  if (gdms.length > 0) {
    console.log("Pagination query succeeds.");
  }
  
  await prisma.$disconnect();
}

runTests();
