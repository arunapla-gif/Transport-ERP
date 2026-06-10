const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function run() {
  const result = await prisma.legacyMaster.deleteMany({
    where: { status: 'APPROVED' }
  });

  console.log(`Successfully purged ${result.count} APPROVED records from the Legacy Migration Queue.`);
}

run().finally(() => prisma.$disconnect());
