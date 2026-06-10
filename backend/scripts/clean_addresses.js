const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

const cleanAddress = (address, companyName) => {
  if (!address || !companyName) return address;
  
  try {
    const cleanName = companyName.replace(/[^a-zA-Z0-9 ]/g, '').trim();
    if (cleanName) {
      const regexPattern = cleanName.split(/\s+/).join('\\s*[^a-zA-Z0-9]*\\s*');
      const regex = new RegExp('^' + regexPattern + '\\s*[^a-zA-Z0-9]*\\s*', 'i');
      return address.replace(regex, '').trim();
    }
  } catch (e) {
    // Ignore error
  }
  return address;
};

async function run() {
  console.log("Cleaning Consignors...");
  const consignors = await prisma.consignor.findMany();
  let updatedConsignors = 0;
  for (const c of consignors) {
    const cleaned = cleanAddress(c.address, c.name);
    if (cleaned !== c.address) {
      await prisma.consignor.update({ where: { id: c.id }, data: { address: cleaned } });
      updatedConsignors++;
    }
  }
  console.log(`Updated ${updatedConsignors} consignor addresses.`);

  console.log("Cleaning Consignees...");
  const consignees = await prisma.consignee.findMany();
  let updatedConsignees = 0;
  for (const c of consignees) {
    const cleaned = cleanAddress(c.address, c.name);
    if (cleaned !== c.address) {
      await prisma.consignee.update({ where: { id: c.id }, data: { address: cleaned } });
      updatedConsignees++;
    }
  }
  console.log(`Updated ${updatedConsignees} consignee addresses.`);
  
  // Clear the master cache just in case
  console.log("Database clean up complete. Please reload your page.");
}

run()
  .catch(e => console.error(e))
  .finally(() => prisma.$disconnect());
