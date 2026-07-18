const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function test() {
  try {
    const v = await prisma.vehicle.findMany();
    console.log("Vehicles:", v.length);
    console.log(v[0]);

    const gcRaw = await prisma.$queryRawUnsafe('SELECT * FROM "GC"');
    console.log("Raw GCs:", gcRaw.length);

    const gdmRaw = await prisma.$queryRawUnsafe('SELECT * FROM "GDM"');
    console.log("Raw GDMs:", gdmRaw.length);
  } catch (e) {
    console.error(e);
  } finally {
    await prisma.$disconnect();
  }
}
test();
