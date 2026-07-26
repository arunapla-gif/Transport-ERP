const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function run() {
  try {
    console.log("Fixing Database Sequences...");
    await prisma.$executeRawUnsafe(`SELECT setval(pg_get_serial_sequence('"GDM"', 'id'), (SELECT COALESCE(MAX(id), 0) + 1 FROM "GDM"), false);`);
    await prisma.$executeRawUnsafe(`SELECT setval(pg_get_serial_sequence('"GC"', 'id'), (SELECT COALESCE(MAX(id), 0) + 1 FROM "GC"), false);`);
    console.log("Sequences fixed!");

    // 1. Get any vehicle
    let vehicle = await prisma.vehicle.findFirst();

    // 2. Get some GCs to attach
    const gcs = await prisma.gC.findMany({ take: 3 });

    // 3. Create the GDM using Prisma now that sequences are fixed
    const gdmNumber = `GDM-TEST-${Math.floor(Date.now()/1000)}`;
    const newGdm = await prisma.gDM.create({
      data: {
        gdmNumber: gdmNumber,
        date: new Date(),
        time: '10:00 AM',
        vehicleId: vehicle.id,
        status: 'Created',
        gcs: {
          connect: gcs.map(g => ({ id: g.id }))
        }
      }
    });

    console.log(`✅ Success! Created Pending GDM: ${newGdm.gdmNumber}`);
    console.log(`It has ${gcs.length} GCs attached.`);
    console.log(`Go to Govt Compliance, toggle Sandbox, and you will see it!`);
  } catch (err) {
    console.error("Failed:", err);
  } finally {
    await prisma.$disconnect();
  }
}
run();
