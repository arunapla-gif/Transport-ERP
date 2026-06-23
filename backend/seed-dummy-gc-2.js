const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function seed() {
  try {
    const gc = await prisma.gC.create({
      data: {
        gcNumber: 'BELL-5001',
        type: 'Outward',
        date: new Date(Date.now() - 86400000 * 2), // 2 days ago
        time: '14:30 PM',
        status: 'In Transit',
        godown: 'Branch A',
        ewbNumber: '987654321098',
        ewbRawData: {
          fromGstin: '33AAAPL9999A1Z5',
          totInvValue: 125000,
          docDate: '13/06/2026'
        },
        goods: {
          create: [
            { articleCount: 120, units: 'Cartons', hsn: '4011', description: 'Tyres' }
          ]
        },
        gdm: {
          create: {
            gdmNumber: 'GDM-1001',
            date: new Date(Date.now() - 86400000), // 1 day ago
            status: 'Dispatched',
            destination: 'Chennai',
            vehicle: {
              create: {
                vehicleNumber: 'TN-39-BT-4455',
                type: 'Lorry',
                ownerName: 'Transport Corp'
              }
            }
          }
        },
        trackingLogs: {
          create: [
            {
              actionType: 'EWB_FETCHED',
              timestamp: new Date(Date.now() - 86400000 * 2),
              description: 'E-Way Bill 987654321098 fetched and raw data securely stored.',
              metaData: {
                fromGstin: '33AAAPL9999A1Z5',
                totInvValue: 125000,
                docDate: '13/06/2026'
              }
            },
            {
              actionType: 'GDM_LOADED',
              timestamp: new Date(Date.now() - 86400000),
              description: 'Assigned to GDM-1001 for dispatch on Vehicle TN-39-BT-4455.'
            }
          ]
        }
      }
    });
    console.log('Dummy GC 2 Created:', gc.gcNumber);
  } catch (err) {
    console.error('Error creating dummy GC 2:', err.message);
  } finally {
    await prisma.$disconnect();
  }
}

seed();
