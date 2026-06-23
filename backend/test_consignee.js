const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  try {
    const consignees = await prisma.consignee.findMany({ 
      where: { branch: 'MAIN' },
      orderBy: { id: 'desc' } 
    });
    console.log("Count:", consignees.length);
  } catch (err) {
    console.error("ERROR:", err.message);
  }
}
main().finally(() => prisma.$disconnect());
