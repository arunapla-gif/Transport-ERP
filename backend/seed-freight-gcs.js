const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function seed() {
  try {
    // Check if consignor and consignee exist, or create dummies
    let consignor = await prisma.consignor.findFirst();
    if (!consignor) {
      consignor = await prisma.consignor.create({ data: { name: 'Standard Fireworks' } });
    }
    
    let consignee = await prisma.consignee.findFirst();
    if (!consignee) {
      consignee = await prisma.consignee.create({ data: { name: 'Sri Balaji Agencies', station: 'Chennai' } });
    }

    // Seed 3 recent freight entries
    const entries = [
      {
        gcNumber: 'AP-5010',
        date: new Date(),
        status: 'Created',
        freightTotal: 1500.00,
        advancePaid: 500.00,
        balanceFreight: 1000.00,
        consignorId: consignor.id,
        consigneeId: consignee.id,
        goods: [{ articleCount: 20, units: 'Boxes', description: 'Assorted Crackers' }]
      },
      {
        gcNumber: 'AP-5011',
        date: new Date(),
        status: 'Created',
        freightTotal: 2450.00,
        advancePaid: 0.00,
        balanceFreight: 2450.00,
        consignorId: consignor.id,
        consigneeId: consignee.id,
        goods: [{ articleCount: 35, units: 'Cartons', description: 'Sparklers' }]
      },
      {
        gcNumber: 'BELL-5012',
        date: new Date(),
        status: 'Created',
        freightTotal: 850.00,
        advancePaid: 850.00,
        balanceFreight: 0.00,
        consignorId: consignor.id,
        consigneeId: consignee.id,
        goods: [{ articleCount: 10, units: 'Bags', description: 'Fancy Items' }]
      }
    ];

    for (const entry of entries) {
      const { goods, ...gcData } = entry;
      // Delete if exists
      await prisma.gC.deleteMany({ where: { gcNumber: entry.gcNumber } });

      await prisma.gC.create({
        data: {
          ...gcData,
          goods: {
            create: goods
          }
        }
      });
      console.log(`Seeded priced GC: ${entry.gcNumber}`);
    }

  } catch (err) {
    console.error('Error seeding freight GCs:', err);
  } finally {
    await prisma.$disconnect();
  }
}

seed();
