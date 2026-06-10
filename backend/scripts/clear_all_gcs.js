const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  try {
    const items = await prisma.gCItem.deleteMany();
    console.log(`Deleted ${items.count} GC items.`);

    const gcs = await prisma.gC.deleteMany();
    console.log(`Deleted ${gcs.count} GCs.`);
  } catch (error) {
    console.error(error);
  } finally {
    await prisma.$disconnect();
  }
}

main();
