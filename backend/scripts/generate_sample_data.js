const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  console.log("Fetching existing masters...");
  const consignors = await prisma.consignor.findMany({ take: 2 });
  const consignees = await prisma.consignee.findMany({ take: 2 });
  const vehicles = await prisma.vehicle.findMany({ take: 1 });

  if (consignors.length === 0 || consignees.length === 0 || vehicles.length === 0) {
    console.error("Missing master data. Please ensure Consignors, Consignees, and Vehicles exist.");
    return;
  }

  const cnor = consignors[0];
  const cnee = consignees[0];
  const vehicle = vehicles[0];

  console.log("Generating 3 sample GCs...");
  
  const gcs = [];
  for (let i = 1; i <= 3; i++) {
    const gc = await prisma.gC.create({
      data: {
        gcNumber: i === 3 ? 'BELL-200' + i : 'AP-100' + i,
        financialYear: '2026-2027',
        type: 'Regular',
        date: new Date(),
        time: '10:00',
        status: 'Created',
        consignorId: cnor.id,
        consigneeId: cnee.id,
        invoiceDate: new Date(),
        invoiceNumber: 'INV-00' + i,
        privateMark: i === 1 ? 'NO_EWB' : '1234567890' + i,
        invoiceValue: 5000 * i,
        godown: 'Main Godown',
        freightType: 'To Pay',
        freightTotal: 500 * i,
        freightFixed: 'Yes',
        goods: {
          create: [{
            articleCount: i * 2,
            units: 'Boxes',
            hsn: '4202',
            description: 'Sample Goods ' + i
          }]
        }
      }
    });
    gcs.push(gc);
  }

  console.log("Created GCs: " + gcs.map(g => g.gcNumber).join(', '));

  console.log("Creating a Draft GDM...");
  const gdm = await prisma.gDM.create({
    data: {
      gdmNumber: '1001',
      date: new Date(),
      time: '12:00',
      status: 'Created',
      vehicleId: vehicle.id,
      driverName: vehicle.driverName || 'Raju',
      driverPhone: vehicle.phone || '9876543210',
      fromLocation: 'Sivakasi',
      toName: 'AS PER BILLS',
      memoAmount: 1500,
    }
  });

  console.log("Created GDM: " + gdm.gdmNumber);

  console.log("Attaching GCs to GDM...");
  await prisma.gC.updateMany({
    where: { id: { in: gcs.map(g => g.id) } },
    data: { gdmId: gdm.id, status: 'In Transit' }
  });

  console.log("Sample Data Generation Complete!");
}

main()
  .catch(e => console.error(e))
  .finally(async () => await prisma.$disconnect());
