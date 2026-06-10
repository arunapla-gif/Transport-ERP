const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function run() {
  const retailConsignees = await prisma.consignee.findMany({
    where: { 
      migrationType: { in: ['RETAIL_IMPORT', 'RETAIL_WITH_PHONE', 'RETAIL_NO_PHONE'] } 
    }
  });

  const phonePattern = /\d{8,}/; // Look for 8 or more consecutive digits
  
  let withPhoneCount = 0;
  let noPhoneCount = 0;

  for (const c of retailConsignees) {
    let hasPhone = false;

    // Check phone field
    if (c.phone && phonePattern.test(c.phone.replace(/\D/g, ''))) {
      hasPhone = true;
    }
    
    // Check name field for numbers
    if (!hasPhone && c.name && phonePattern.test(c.name.replace(/[^0-9]/g, ''))) {
      hasPhone = true;
    }

    const newType = hasPhone ? 'RETAIL_WITH_PHONE' : 'RETAIL_NO_PHONE';
    
    if (c.migrationType !== newType) {
      await prisma.consignee.update({
        where: { id: c.id },
        data: { migrationType: newType }
      });
    }

    if (hasPhone) withPhoneCount++;
    else noPhoneCount++;
  }

  console.log(`--- Retail Splitting Complete ---`);
  console.log(`With Phone Numbers: ${withPhoneCount}`);
  console.log(`Without Phone Numbers: ${noPhoneCount}`);
}

run()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
