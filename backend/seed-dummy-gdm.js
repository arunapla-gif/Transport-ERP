const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function seed() {
  try {
    let vehicle = await prisma.vehicle.findFirst();
    if (!vehicle) {
      vehicle = await prisma.vehicle.create({
        data: { vehicleNumber: 'TN-11-AA-1111', type: 'Truck' }
      });
    }

    const gdm = await prisma.gDM.create({
      data: {
        gdmNumber: '1001',
        date: new Date(),
        time: '12:00 PM',
        status: 'Created',
        fromLocation: 'Sivakasi',
        toName: 'AS PER BILLS',
        vehicleId: vehicle.id,
        driverName: 'Ramu',
        cewbNumber: 'CEWB-9988776655',
        gcs: {
          connect: [{ gcNumber: 'AP-5000' }]
        }
      }
    });

    console.log('Dummy GDM Created:', gdm.gdmNumber);
  } catch (err) {
    console.error('Error creating dummy:', err.message);
  } finally {
    await prisma.$disconnect();
  }
}

seed();
