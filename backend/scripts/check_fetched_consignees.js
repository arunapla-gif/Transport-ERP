const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function check() {
  const fetchedConsignees = await prisma.legacyMaster.findMany({
    where: { 
      partyType: 'CONSIGNEE',
      status: { in: ['READY', 'APPROVED'] }
    }
  });

  let withAddresses = [];
  let withDiffNames = [];

  for (const c of fetchedConsignees) {
    let hasAddrs = false;
    let hasDiffNames = false;

    // Check addresses
    if (c.apiAddresses && Array.isArray(c.apiAddresses) && c.apiAddresses.length > 0) {
      hasAddrs = true;
    } else if (typeof c.apiAddresses === 'string') {
      try {
        const arr = JSON.parse(c.apiAddresses);
        if (arr.length > 0) hasAddrs = true;
      } catch (e) {}
    }

    // Check names
    if (c.apiLegalName && c.apiLegalName !== c.apiName) {
      hasDiffNames = true;
    }
    
    let parsedTrade = [];
    if (c.apiTradeNames && Array.isArray(c.apiTradeNames)) {
      parsedTrade = c.apiTradeNames;
    } else if (typeof c.apiTradeNames === 'string') {
      try {
        parsedTrade = JSON.parse(c.apiTradeNames);
      } catch (e) {}
    }
    
    if (parsedTrade.length > 0 && parsedTrade[0] !== c.apiName) {
      hasDiffNames = true;
    }

    if (hasAddrs) withAddresses.push(c);
    if (hasDiffNames) withDiffNames.push(c);
  }

  console.log(`Total Fetched Consignees (READY/APPROVED): ${fetchedConsignees.length}`);
  console.log(`Consignees with Additional Addresses: ${withAddresses.length}`);
  if (withAddresses.length > 0) {
    console.log("Sample (Addresses):", withAddresses[0].apiName, "->", withAddresses[0].apiAddresses);
  }

  console.log(`Consignees with Different Legal/Trade Names: ${withDiffNames.length}`);
  if (withDiffNames.length > 0) {
    console.log("Sample (Names):");
    const sample = withDiffNames[0];
    console.log(`apiName: ${sample.apiName}`);
    console.log(`apiLegalName: ${sample.apiLegalName}`);
    console.log(`apiTradeNames: ${sample.apiTradeNames}`);
  }
}

check().finally(() => prisma.$disconnect());
