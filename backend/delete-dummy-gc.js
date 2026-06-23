const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function deleteDummy() {
  try {
    const gc = await prisma.gC.findUnique({ where: { gcNumber: 'AP-5000' } });
    if (gc) {
      await prisma.gCItem.deleteMany({ where: { gcId: gc.id } });
      await prisma.gcTrackingLog.deleteMany({ where: { gcId: gc.id } });
      await prisma.gC.delete({ where: { id: gc.id } });
      console.log('Dummy GC deleted');
    } else {
      console.log('Dummy GC not found');
    }
  } catch (err) {
    console.error(err);
  } finally {
    await prisma.$disconnect();
  }
}

deleteDummy();
