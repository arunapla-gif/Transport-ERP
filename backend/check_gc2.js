const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  try {
    const gc = await prisma.gC.findFirst({
      where: { gcNumber: 'BELL-1555' },
      include: {
        consignor: true,
        consignee: true,
        goods: true,
      }
    });
    console.log("SUCCESS");
  } catch (err) {
    console.error("ERROR:", err.message);
  }
}
main().finally(() => prisma.$disconnect());
