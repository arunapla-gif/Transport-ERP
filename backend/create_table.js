const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  await prisma.$executeRawUnsafe(`
    CREATE TABLE IF NOT EXISTS "HSNMaster" (
        "id" SERIAL NOT NULL,
        "hsnCode" TEXT NOT NULL,
        "description" TEXT,
        "gstRate" DOUBLE PRECISION NOT NULL,
        "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
        "updatedAt" TIMESTAMP(3) NOT NULL,
        CONSTRAINT "HSNMaster_pkey" PRIMARY KEY ("id")
    );
  `);
  await prisma.$executeRawUnsafe(`
    CREATE UNIQUE INDEX IF NOT EXISTS "HSNMaster_hsnCode_key" ON "HSNMaster"("hsnCode");
  `);
  console.log('HSNMaster table created successfully');
}
main().catch(console.error).finally(() => prisma.$disconnect());
