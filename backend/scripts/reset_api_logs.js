const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function run() {
  console.log('Resetting ApiUsageLog table...');
  
  // Clear existing logs
  await prisma.apiUsageLog.deleteMany({});
  console.log('Old logs deleted.');
  
  console.log('Inserting new test logs with ₹0.10 pricing...');
  
  await prisma.apiUsageLog.create({
    data: { provider: 'WhiteBooks', apiName: 'E-Way Bill Fetch', status: 'Success', cost: 0.10 }
  });
  
  await prisma.apiUsageLog.create({
    data: { provider: 'Neon DB', apiName: 'Database Read', status: 'Success', cost: 0.0 }
  });
  
  await prisma.apiUsageLog.create({
    data: { provider: 'Google Vision', apiName: 'OCR Scan', status: 'Success', cost: 0.0 }
  });
  
  console.log('New logs inserted successfully! The dashboard will now reflect the exact subscription pricing.');
}

run().catch(console.error).finally(() => prisma.$disconnect());
