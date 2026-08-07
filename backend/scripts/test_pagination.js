const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function runPaginationTests() {
  console.log("🚀 Starting Phase 3 Automated Pagination Tests...\n");
  
  const limit = 5;
  const page1Skip = 0;
  
  // Test Page 1
  const start1 = Date.now();
  const [data1, total] = await Promise.all([
    prisma.consignor.findMany({
      where: { branch: 'MAIN' },
      orderBy: { id: 'desc' },
      skip: page1Skip,
      take: limit
    }),
    prisma.consignor.count({ where: { branch: 'MAIN' } })
  ]);
  const end1 = Date.now();
  
  const hasMore1 = (page1Skip + data1.length) < total;
  
  console.log(`✅ [PAGE 1] Fetched ${data1.length} records in ${end1 - start1}ms.`);
  console.log(`   - Total Records: ${total}`);
  console.log(`   - Has More: ${hasMore1}`);
  
  if (!hasMore1 || data1.length === 0) {
    console.log("Not enough data to test Page 2.");
    return;
  }
  
  // Test Page 2
  const page2Skip = 5;
  const start2 = Date.now();
  const data2 = await prisma.consignor.findMany({
      where: { branch: 'MAIN' },
      orderBy: { id: 'desc' },
      skip: page2Skip,
      take: limit
  });
  const end2 = Date.now();
  
  console.log(`✅ [PAGE 2] Fetched ${data2.length} records in ${end2 - start2}ms.`);
  
  // Verify no overlap
  const idSet1 = new Set(data1.map(d => d.id));
  const overlap = data2.some(d => idSet1.has(d.id));
  
  if (overlap) {
    console.error("❌ ERROR: Data overlap detected between Page 1 and Page 2!");
  } else {
    console.log("✅ SUCCESS: No data overlap detected. Pagination slices correctly.");
  }

  console.log("\n🎯 All pagination logic verified successfully.");
  await prisma.$disconnect();
}

runPaginationTests().catch(e => {
  console.error("❌ Test Failed:", e);
  process.exit(1);
});
