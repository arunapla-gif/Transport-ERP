const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function check() {
  const gc = await prisma.gC.findUnique({ where: { gcNumber: 'AP-5000' } });
  console.log(JSON.stringify(gc, null, 2));
  await prisma.$disconnect();
}

check();
