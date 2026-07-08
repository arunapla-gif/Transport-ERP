const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  console.log("Starting Uppercase Migration...");

  // 1. Update Consignors
  console.log("\nChecking Consignors...");
  const consignors = await prisma.consignor.findMany();

  let consignorsUpdated = 0;
  for (const c of consignors) {
    if (c.gstin && c.gstin !== c.gstin.toUpperCase()) {
      await prisma.consignor.update({
        where: { id: c.id },
        data: { gstin: c.gstin.toUpperCase() }
      });
      consignorsUpdated++;
    }
  }
  console.log(`✅ Updated ${consignorsUpdated} Consignors to uppercase.`);

  // 2. Update Consignees
  console.log("\nChecking Consignees...");
  const consignees = await prisma.consignee.findMany();

  let consigneesUpdated = 0;
  for (const c of consignees) {
    if (c.gstin && c.gstin !== c.gstin.toUpperCase()) {
      await prisma.consignee.update({
        where: { id: c.id },
        data: { gstin: c.gstin.toUpperCase() }
      });
      consigneesUpdated++;
    }
  }
  console.log(`✅ Updated ${consigneesUpdated} Consignees to uppercase.`);

  // 3. Update Vehicles
  console.log("\nChecking Vehicles...");
  const vehicles = await prisma.vehicle.findMany();

  let vehiclesUpdated = 0;
  for (const v of vehicles) {
    if (v.vehicleNumber && v.vehicleNumber !== v.vehicleNumber.toUpperCase()) {
      await prisma.vehicle.update({
        where: { id: v.id },
        data: { vehicleNumber: v.vehicleNumber.toUpperCase() }
      });
      vehiclesUpdated++;
    }
  }
  console.log(`✅ Updated ${vehiclesUpdated} Vehicles to uppercase.`);

  console.log("\n🎉 Migration Complete!");
}

main()
  .catch(e => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
