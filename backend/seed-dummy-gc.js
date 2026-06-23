const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function seed() {
  try {
    const gc = await prisma.gC.create({
      data: {
        gcNumber: 'AP-5000',
        type: 'Outward',
        date: new Date(Date.now() - 3600000), // 1 hour ago
        time: '10:00 AM',
        status: 'Created',
        godown: 'Main Branch',
        ewbNumber: '123456789012',
        ewbRawData: {
          fromGstin: '33AAAPL1234A1Z5',
          totInvValue: 50000,
          ewayBillDate: new Date(Date.now() - 86400000).toLocaleString('en-IN') // 1 day ago
        },
        goods: {
          create: [
            { articleCount: 50, units: 'Boxes', hsn: '3401', description: 'Soap' }
          ]
        },
        trackingLogs: {
          create: [
            {
              actionType: 'EWB_FETCHED',
              timestamp: new Date(Date.now() - 3600000), // 1 hr ago
              description: 'E-Way Bill 123456789012 fetched and raw data securely stored.',
              metaData: {
                fromGstin: '33AAAPL1234A1Z5',
                totInvValue: 50000,
                docDate: '14/06/2026'
              }
            }
          ]
        }
      }
    });
    console.log('Dummy GC Created:', gc.gcNumber);
  } catch (err) {
    console.error('Error creating dummy GC:', err.message);
  } finally {
    await prisma.$disconnect();
  }
}

seed();
