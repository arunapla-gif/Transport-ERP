const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  console.log("Seeding dummy trip for HR55AT4106...");

  const vehicleNumber = "HR55AT4106";

  // 1. Ensure Vehicle exists
  let vehicle = await prisma.vehicle.findUnique({
    where: { vehicleNumber }
  });

  if (!vehicle) {
    console.log(`Creating vehicle ${vehicleNumber}...`);
    vehicle = await prisma.vehicle.create({
      data: {
        vehicleNumber,
        type: "Truck 2 - axle",
        driverName: "Dummy Driver",
      }
    });
  } else {
    console.log(`Vehicle ${vehicleNumber} found.`);
  }

  // 2. Create an Active Trip
  const tripNumber = `TRIP-${Date.now()}`;
  console.log(`Creating trip ${tripNumber}...`);
  
  const trip = await prisma.trip.create({
    data: {
      tripNumber,
      status: "Active",
      vehicleId: vehicle.id,
      driverName: vehicle.driverName,
      lorryHire: 50000,
      advancePaid: 10000,
      balanceAmount: 40000,
      sourcedBy: "Direct"
    }
  });

  console.log("Successfully created dummy Active Trip!");
  console.log("Trip Details:", trip);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
