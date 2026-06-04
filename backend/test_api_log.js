const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function run() {
  console.log('Inserting test logs...');
  
  await prisma.apiUsageLog.create({
    data: { provider: 'WhiteBooks', apiName: 'E-Way Bill Fetch', status: 'Success', cost: 1.0 }
  });
  
  await prisma.apiUsageLog.create({
    data: { provider: 'Neon DB', apiName: 'Database Read', status: 'Success', cost: 0.0 }
  });
  
  await prisma.apiUsageLog.create({
    data: { provider: 'Google Vision', apiName: 'OCR Scan', status: 'Success', cost: 0.0 }
  });
  
  console.log('Logs inserted successfully!');
  
  const statsResponse = await fetch('http://localhost:5000/api/usage/stats');
  if (statsResponse.ok) {
    const data = await statsResponse.json();
    console.log('Stats fetched via API:', JSON.stringify(data, null, 2));
  } else {
    console.error('Failed to fetch stats from running server');
  }
}

run().catch(console.error).finally(() => prisma.$disconnect());
