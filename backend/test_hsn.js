const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  try {
    const data = await prisma.hSNMaster.findMany();
    console.log("SUCCESS! HSNMaster table found. Rows:", data.length);
  } catch (err) {
    console.error("ERROR:", err.message);
  } finally {
    await prisma.$disconnect();
  }
}
main();
