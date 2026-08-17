const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function checkPing() {
  console.log("Checking DB Connection Ping...");
  try {
    const directPrisma = new PrismaClient({
      datasources: {
        db: {
          url: "postgresql://postgres.gqfpfnqepdkletbbhwcx:IevuJqEtZ8V1eKhz@aws-1-ap-south-1.pooler.supabase.com:5432/postgres"
        }
      }
    });

    const start = Date.now();
    await directPrisma.$queryRaw`SELECT 1`;
    const ping = Date.now() - start;
    
    const start2 = Date.now();
    await directPrisma.$queryRaw`SELECT 1`;
    const ping2 = Date.now() - start2;
    
    console.log(`[DIRECT 5432] Boot: ${ping}ms | True DB Ping: ${ping2}ms`);
    await directPrisma.$disconnect();
    
    const poolPrisma = new PrismaClient({
      datasources: {
        db: {
          url: "postgresql://postgres.gqfpfnqepdkletbbhwcx:IevuJqEtZ8V1eKhz@aws-1-ap-south-1.pooler.supabase.com:6543/postgres?pgbouncer=true&connection_limit=20"
        }
      }
    });
    
    const start3 = Date.now();
    await poolPrisma.$queryRaw`SELECT 1`;
    const ping3 = Date.now() - start3;
    
    const start4 = Date.now();
    await poolPrisma.$queryRaw`SELECT 1`;
    const ping4 = Date.now() - start4;
    
    console.log(`[POOLER 6543] Boot: ${ping3}ms | True DB Ping: ${ping4}ms`);
    await poolPrisma.$disconnect();
  } catch (error) {
    console.error("Connection failed:", error.message);
  } finally {
    process.exit(0);
  }
}

checkPing();
