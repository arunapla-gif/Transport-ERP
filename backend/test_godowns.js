const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
async function main() {
  const count = await prisma.godown.count();
  console.log("Godowns count:", count);
  const godowns = await prisma.godown.findMany();
  console.log(godowns);
}
main().catch(console.error).finally(() => prisma.$disconnect());
