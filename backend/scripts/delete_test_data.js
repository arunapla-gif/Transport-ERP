const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function run() {
  try {
    console.log("Deleting test GDMs...");
    const gdms = await prisma.gDM.deleteMany({
      where: {
        gdmNumber: { startsWith: 'GDM-TEST-' }
      }
    });
    console.log("Deleted GDMs:", gdms.count);

    console.log("Deleting test GCs...");
    const gcs = await prisma.gC.deleteMany({
      where: {
        gcNumber: { contains: '-TEST-' }
      }
    });
    console.log("Deleted GCs:", gcs.count);

    console.log("Done.");
  } catch(e) {
    console.error(e);
  } finally {
    await prisma.$disconnect();
  }
}
run();
