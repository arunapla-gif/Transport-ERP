const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function runTest() {
  try {
    console.log("1. Creating dummy Consignments...");
    const timestamp = Math.floor(Date.now() / 1000);
    
    let consignor = await prisma.consignor.findFirst();
    let consignee = await prisma.consignee.findFirst();

    const gc1 = await prisma.gC.create({
      data: {
        gcNumber: `AP-TEST-${timestamp}-1`,
        date: new Date(),
        consignor: { connect: { id: consignor.id } },
        consignee: { connect: { id: consignee.id } },
        invoiceNumber: `INV-${timestamp}-1`,
        invoiceValue: 50000,
        ewbRawData: { genGstin: consignor.gstin, validUpto: new Date(Date.now() + 86400000).toISOString() },
        goods: { create: [{ description: 'Test Goods 1', hsn: '3604', articleCount: 10 }] }
      },
      include: { consignor: true, consignee: true, goods: true }
    });

    const gc2 = await prisma.gC.create({
      data: {
        gcNumber: `BELL-TEST-${timestamp}-2`,
        date: new Date(),
        consignor: { connect: { id: consignor.id } },
        consignee: { connect: { id: consignee.id } },
        invoiceNumber: `INV-${timestamp}-2`,
        invoiceValue: 35000,
        ewbRawData: { genGstin: consignor.gstin, validUpto: new Date(Date.now() + 86400000).toISOString() },
        goods: { create: [{ description: 'Test Goods 2', hsn: '3604', articleCount: 5 }] }
      },
      include: { consignor: true, consignee: true, goods: true }
    });

    console.log("2. Creating dummy GDM...");
    let vehicle = await prisma.vehicle.findFirst({ where: { vehicleNumber: 'TN-99-TEST' } });
    if (!vehicle) {
      vehicle = await prisma.vehicle.create({ data: { vehicleNumber: 'TN-99-TEST', type: 'Truck' }});
    }

    const gdm = await prisma.gDM.create({
      data: {
        gdmNumber: `GDM-TEST-${timestamp}`,
        date: new Date(),
        vehicleId: vehicle.id,
        gcs: { connect: [{ id: gc1.id }, { id: gc2.id }] }
      }
    });

    console.log("3. Triggering Sandbox Bulk Heal...");
    const gcsToHeal = [
      { ...gc1, companyString: 'AP', ewbAge: 2 },
      { ...gc2, companyString: 'BELL', ewbAge: 20 }
    ];
    
    const healRes = await fetch('http://127.0.0.1:5005/api/ewaybill/bulk-heal', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ gcs: gcsToHeal, vehicleNo: 'TN99TEST', testMode: true })
    });
    
    const healData = await healRes.json();
    console.log(`Healed ${healData.healedGcs?.length || 0} GCs successfully.`);

    console.log("4. Triggering Sandbox CEWB Generation...");
    const ewbNos = healData.healedGcs.map(g => g.privateMark);
    const cewbRes = await fetch('http://127.0.0.1:5005/api/ewaybill/cewb?company=AP', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ 
        vehicleNo: 'TN99TEST', 
        fromPlace: 'Sivakasi', 
        transDocNo: 'TESTDOC', 
        transDocDate: new Date().toLocaleDateString('en-GB'),
        ewbNos: ewbNos,
        testMode: true
      })
    });
    
    const cewbData = await cewbRes.json();
    console.log(`CEWB Generated: ${cewbData.cEwbNo}`);
    
    console.log("5. Attaching CEWB to GDM...");
    await prisma.gDM.update({
      where: { id: gdm.id },
      data: { cewbNumber: cewbData.cEwbNo }
    });

    console.log(`\n✅ TEST COMPLETE! Sandbox CEWB ${cewbData.cEwbNo} is attached to GDM ${gdm.gdmNumber}.`);
    console.log(`👉 You can now go to the Print Hub and print this GDM to see the Official Layout!`);
    
  } catch (err) {
    console.error("Test failed:", err);
  } finally {
    await prisma.$disconnect();
  }
}

runTest();
