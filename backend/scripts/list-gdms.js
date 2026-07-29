const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function run() {
  try {
    const gdms = await prisma.gDM.findMany({
      take: 5,
      select: { gdmNumber: true }
    });
    console.log("Recent GDMs:", gdms);
  } catch(e) {
    console.error(e);
  } finally {
    await prisma.$disconnect();
  }
}
run();
