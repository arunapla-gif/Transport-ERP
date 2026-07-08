const { PrismaClient } = require('@prisma/client');
const { resolveStateCode } = require('../utils/stateCodeHelper');

const prisma = new PrismaClient();

async function main() {
  console.log("Starting State Code Cleanup...");

  // 1. Process Consignors
  console.log("\n--- Processing Consignors ---");
  const consignors = await prisma.consignor.findMany();
  let cnorFixed = 0;

  for (const cnor of consignors) {
    if (cnor.stateCode) {
      // Check if it's already a valid number string like "33"
      const parsed = parseInt(cnor.stateCode, 10);
      if (isNaN(parsed)) {
        // It's a string like "Tamil Nadu"
        const resolved = resolveStateCode(cnor.gstin, cnor.state, cnor.stateCode);
        if (resolved) {
          await prisma.consignor.update({
            where: { id: cnor.id },
            data: { stateCode: resolved.toString().padStart(2, '0') }
          });
          console.log(`[Consignor] ID ${cnor.id} (${cnor.name}): Changed '${cnor.stateCode}' -> '${resolved.toString().padStart(2, '0')}'`);
          cnorFixed++;
        } else {
          console.log(`[Consignor] ID ${cnor.id} (${cnor.name}): Could not resolve '${cnor.stateCode}'`);
        }
      }
    } else if (cnor.state) {
        // If stateCode is missing, try to generate it from state or GSTIN
        const resolved = resolveStateCode(cnor.gstin, cnor.state, null);
        if (resolved) {
            await prisma.consignor.update({
                where: { id: cnor.id },
                data: { stateCode: resolved.toString().padStart(2, '0') }
            });
            console.log(`[Consignor] ID ${cnor.id} (${cnor.name}): Added missing stateCode '${resolved.toString().padStart(2, '0')}' based on state '${cnor.state}' or GSTIN`);
            cnorFixed++;
        }
    }
  }

  // 2. Process Consignees
  console.log("\n--- Processing Consignees ---");
  const consignees = await prisma.consignee.findMany();
  let cneeFixed = 0;

  for (const cnee of consignees) {
    if (cnee.stateCode) {
      const parsed = parseInt(cnee.stateCode, 10);
      if (isNaN(parsed)) {
        const resolved = resolveStateCode(cnee.gstin, cnee.state, cnee.stateCode);
        if (resolved) {
          await prisma.consignee.update({
            where: { id: cnee.id },
            data: { stateCode: resolved.toString().padStart(2, '0') }
          });
          console.log(`[Consignee] ID ${cnee.id} (${cnee.name}): Changed '${cnee.stateCode}' -> '${resolved.toString().padStart(2, '0')}'`);
          cneeFixed++;
        } else {
          console.log(`[Consignee] ID ${cnee.id} (${cnee.name}): Could not resolve '${cnee.stateCode}'`);
        }
      }
    } else if (cnee.state) {
        const resolved = resolveStateCode(cnee.gstin, cnee.state, null);
        if (resolved) {
            await prisma.consignee.update({
                where: { id: cnee.id },
                data: { stateCode: resolved.toString().padStart(2, '0') }
            });
            console.log(`[Consignee] ID ${cnee.id} (${cnee.name}): Added missing stateCode '${resolved.toString().padStart(2, '0')}' based on state '${cnee.state}' or GSTIN`);
            cneeFixed++;
        }
    }
  }

  console.log(`\nCleanup Complete! Fixed ${cnorFixed} Consignors and ${cneeFixed} Consignees.`);
}

main()
  .catch(e => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
