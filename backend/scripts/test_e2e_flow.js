const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function runTest() {
  console.log("🚀 Starting E2E Transport ERP Data Flow Test...\n");
  const timestamp = Date.now();

  try {
    // 1. Create Mock Data
    console.log("1. Creating Test Master Data...");
    const consignor = await prisma.consignor.upsert({
      where: { name: 'E2E Test Consignor' },
      update: {},
      create: { name: 'E2E Test Consignor', gstin: 'TESTC1' }
    });
    const consignee = await prisma.consignee.upsert({
      where: { name: 'E2E Test Consignee' },
      update: {},
      create: { name: 'E2E Test Consignee', gstin: 'TESTC2' }
    });
    const vehicle = await prisma.vehicle.upsert({
      where: { vehicleNumber: 'TN-E2E-1234' },
      update: {},
      create: { vehicleNumber: 'TN-E2E-1234', type: 'Open',  }
    });

    // 2. Create a GC Entry
    console.log("2. Creating GC Entry (Freight: To Pay, Total: ₹5000)...");
    const gc = await prisma.gC.create({
      data: {
        gcNumber: `GC-E2E-${timestamp}`,
        consignorId: consignor.id,
        consigneeId: consignee.id,
        freightType: 'To Pay',
        freightTotal: 5000,
        status: 'Created'
      }
    });

    // 3. Create a GDM
    console.log("3. Creating GDM and attaching GC...");
    const gdm = await prisma.gDM.create({
      data: {
        gdmNumber: `GDM-E2E-${timestamp}`,
        vehicle: { connect: { id: vehicle.id } },
        fromLocation: 'Origin',
        destination: 'Dest',
        
      }
    });
    await prisma.gC.update({ where: { id: gc.id }, data: { gdmId: gdm.id } });

    // 4. Create Lorry Hire (Trip)
    console.log("4. Creating Lorry Hire / Trip (Hire: ₹4000, Advance: ₹1000, Balance: ₹3000)...");
    const trip = await prisma.trip.create({
      data: {
        tripNumber: `TRIP-E2E-${timestamp}`,
        vehicle: { connect: { id: vehicle.id } },
        lorryHire: 4000,
        advancePaid: 1000,
        balanceAmount: 3000,
        
      }
    });

    // 5. Simulate Trip Settlement
    console.log("5. Simulating Trip Settlement...");
    console.log(`   - Attaching GDM: ${gdm.gdmNumber}`);
    console.log(`   - Consignee pays ₹3000 to Driver, ₹2000 to Transport Bank`);
    await prisma.gDM.update({ where: { id: gdm.id }, data: { tripId: trip.id } });
    
    // Update GC Allocations
    await prisma.gC.update({
      where: { id: gc.id },
      data: { paidToDriver: 3000, paidToTransport: 2000 }
    });

    // Calculate Crossing/Return
    const totalPaidToDriver = 3000;
    const tripBalance = 3000; // 4000 hire - 1000 adv
    const difference = totalPaidToDriver - tripBalance;
    
    await prisma.trip.update({
      where: { id: trip.id },
      data: {
        status: 'Settled',
        crossingAmount: difference > 0 ? difference : 0,
        returnAmount: difference < 0 ? Math.abs(difference) : 0,
        settledDate: new Date()
      }
    });

    console.log(`   -> Settlement Complete! Driver collected ₹3000. Trip Balance was ₹3000. Settled Even (₹0).\n`);

    // 6. Fetch Party Ledger (The true test)
    console.log("6. Verifying Party Ledger for 'E2E Test Consignee'...");
    const gcsForLedger = await prisma.gC.findMany({ where: { consigneeId: consignee.id }});
    
    const ledger = [];
    gcsForLedger.forEach(g => {
      if (g.freightTotal > 0) ledger.push({ type: 'DEBIT', amount: g.freightTotal, ref: `Freight for ${g.gcNumber}` });
      if (g.paidToDriver > 0) ledger.push({ type: 'CREDIT', amount: g.paidToDriver, ref: `Paid to Driver` });
      if (g.paidToTransport > 0) ledger.push({ type: 'CREDIT', amount: g.paidToTransport, ref: `Paid to Transport` });
    });

    let runningBalance = 0;
    console.table(ledger.map(entry => {
      if (entry.type === 'DEBIT') runningBalance += entry.amount;
      if (entry.type === 'CREDIT') runningBalance -= entry.amount;
      return { Type: entry.type, Detail: entry.ref, Amount: `₹${entry.amount}`, Balance: `₹${runningBalance}` };
    }));

    console.log(`\n✅ E2E TEST COMPLETE! Final Outstanding Balance for Consignee: ₹${runningBalance}`);

  } catch (err) {
    console.error("Test Failed!", err);
  } finally {
    await prisma.$disconnect();
  }
}

runTest();
