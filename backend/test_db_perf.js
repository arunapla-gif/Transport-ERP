const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function test() {
  console.log("Connecting to Database...");
  
  // 1. OLD WAY: Full Include
  const startOld = Date.now();
  const gcsOld = await prisma.gC.findMany({
    take: 100, relationLoadStrategy: 'join',
    orderBy: { id: 'desc' },
    include: {
      consignor: true,
      consignee: true,
      goods: true,
      gdm: {
        include: { vehicle: true }
      }
    }
  });
  const timeOld = Date.now() - startOld;
  const sizeOld = Buffer.byteLength(JSON.stringify(gcsOld));

  console.log(`[OLD METHOD] Time: ${timeOld}ms | Size: ${(sizeOld / 1024).toFixed(2)} KB`);

  // 2. NEW WAY: Select
  const startNew = Date.now();
  const gcsNew = await prisma.gC.findMany({
    take: 100, relationLoadStrategy: 'join',
    orderBy: { id: 'desc' },
    include: {
      consignor: { select: { id: true, name: true, city: true, gstin: true, phone: true } },
      consignee: { select: { id: true, name: true, city: true, gstin: true, phone: true } },
      goods: true,
      gdm: {
        select: { id: true, gdmNumber: true, vehicle: { select: { vehicleNumber: true } } }
      }
    }
  });
  const timeNew = Date.now() - startNew;
  const sizeNew = Buffer.byteLength(JSON.stringify(gcsNew));

  console.log(`[NEW METHOD] Time: ${timeNew}ms | Size: ${(sizeNew / 1024).toFixed(2)} KB`);
  
  console.log(`\nIMPROVEMENT: Payload size reduced by ${(((sizeOld - sizeNew) / sizeOld) * 100).toFixed(1)}%`);
  
  process.exit(0);
}

test();
