const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function run() {
  const retailConsignees = await prisma.consignee.findMany({
    where: { migrationType: 'RETAIL_IMPORT' }
  });

  const gstinPattern = /^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}[Z]{1}[0-9A-Z]{1}$/i;
  // Let's use a slightly more relaxed pattern just in case they made typos,
  // but a strict one first to find valid ones.
  const loosePattern = /\b[0-9]{2}[A-Za-z]{5}[0-9]{4}[A-Za-z]{1}[1-9A-Za-z]{1}[Zz]{1}[0-9A-Za-z]{1}\b/;
  
  let count = 0;
  const found = [];

  for (const c of retailConsignees) {
    if (!c.phone) continue;
    
    // Split phone by commas or spaces since it could be "9988776655, 33AA..."
    const parts = c.phone.split(/[,/\s]+/);
    let hasGstin = false;
    for (const part of parts) {
      const cleanPart = part.trim();
      if (cleanPart.length === 15 && loosePattern.test(cleanPart)) {
        hasGstin = true;
        break;
      }
    }
    
    if (hasGstin) {
      count++;
      found.push({ id: c.id, name: c.name, phone: c.phone });
    }
  }

  console.log(`Found ${count} retail consignees with a GSTIN hidden in the phone number.`);
  if (count > 0) {
    console.log("Samples:");
    console.log(found.slice(0, 5));
  }
}

run()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
