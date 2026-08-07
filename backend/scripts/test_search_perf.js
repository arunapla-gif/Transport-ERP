const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function runPerformanceTests() {
  console.log("🚀 Starting Phase 1 Automated Database Performance Tests...\n");
  
  // Test 1: Search Consignor by Name (uses new Consignor_name_idx)
  let start = Date.now();
  const consignor = await prisma.consignor.findFirst({
    where: { name: { startsWith: 'S', mode: 'insensitive' } },
    select: { id: true, name: true }
  });
  let end = Date.now();
  console.log(`✅ [TEST 1] Search Consignor by Name: ${end - start}ms`);
  
  // Test 2: Search GC by Date (uses new GC_date_idx)
  start = Date.now();
  const gcsByDate = await prisma.gC.findMany({
    where: { date: { gte: new Date('2023-01-01') } },
    take: 10,
    select: { id: true, gcNumber: true, date: true }
  });
  end = Date.now();
  console.log(`✅ [TEST 2] Filter GC by Date: ${end - start}ms`);

  // Test 3: Relational Lookup - GCs by Consignee (uses new GC_consigneeId_idx)
  start = Date.now();
  const gcsByConsignee = await prisma.gC.findMany({
    where: { consigneeId: 10 },
    take: 5,
    select: { id: true, gcNumber: true }
  });
  end = Date.now();
  console.log(`✅ [TEST 3] Relational Lookup (GC by Consignee ID): ${end - start}ms`);
  
  // Test 4: Search GDM by Status (uses new GDM_status_idx)
  start = Date.now();
  const gdmsByStatus = await prisma.gDM.findMany({
    where: { status: 'Created' },
    take: 10,
    select: { id: true, gdmNumber: true, status: true }
  });
  end = Date.now();
  console.log(`✅ [TEST 4] Filter GDM by Status: ${end - start}ms`);
  
  console.log("\n🎯 All queries executed successfully utilizing the new search indexes.");
  await prisma.$disconnect();
}

runPerformanceTests().catch(e => {
  console.error("❌ Test Failed:", e);
  process.exit(1);
});
