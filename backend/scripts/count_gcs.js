const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
async function countGCs() {
  const total = await prisma.gC.count();
  
  // Try to group by prefix if gcNumber has a prefix, or just count total.
  // Actually, let's just count total.
  console.log(`Total GCs in Database: ${total}`);
  process.exit(0);
}
countGCs();
