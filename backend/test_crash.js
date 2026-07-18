const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function test() {
  try {
    const vehicles = await prisma.vehicle.findMany({ orderBy: { id: 'desc' } });
    
    // Simulate what the frontend does
    // First it sets it to state
    const searchTerm = '';
    let foundObject = false;
    for (const v of vehicles) {
      for (const key of Object.keys(v)) {
        if (v[key] !== null && typeof v[key] === 'object' && !(v[key] instanceof Date)) {
          console.log(`React Crash Alert: vehicle ${v.id} has an OBJECT in property ${key}:`, v[key]);
          foundObject = true;
        }
      }
    }
    if (!foundObject) console.log("No React-crashing objects found in vehicles data.");

  } catch (err) {
    console.error("CRASH SIMULATED:", err);
  } finally {
    await prisma.$disconnect();
  }
}
test();
