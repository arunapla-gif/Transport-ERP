const http = require('http');

const API_URL = 'http://localhost:5005/api';

const makeRequest = (method, path, body = null) => {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'localhost',
      port: 5005,
      path: `/api${path}`,
      method: method,
      headers: {
        'Content-Type': 'application/json',
      },
    };

    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          resolve(JSON.parse(data));
        } else {
          reject(new Error(`Status ${res.statusCode}: ${data}`));
        }
      });
    });

    req.on('error', reject);
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
};

async function runStressTest() {
  console.log("🚀 Starting ERP Backend Stress Test...");
  const startTime = Date.now();

  try {
    // 1. Create Consignors
    console.log("Creating 20 Consignors...");
    const consignorPromises = Array.from({ length: 20 }).map((_, i) => 
      makeRequest('POST', '/consignors', {
        name: `STRESS CONSIGNOR ${Date.now()}-${i}`,
        gstin: `22AAAAA0000A1Z${i % 10}`,
        city: 'Stress City'
      })
    );
    const consignors = await Promise.all(consignorPromises);
    console.log(`✅ 20 Consignors created.`);

    // 2. Create Consignees
    console.log("Creating 20 Consignees...");
    const consigneePromises = Array.from({ length: 20 }).map((_, i) => 
      makeRequest('POST', '/consignees', {
        name: `STRESS CONSIGNEE ${Date.now()}-${i}`,
        gstin: `33BBBBB0000B1Z${i % 10}`,
        city: 'Stress Town'
      })
    );
    const consignees = await Promise.all(consigneePromises);
    console.log(`✅ 20 Consignees created.`);

    // 3. Create a Vehicle
    const vehicle = await makeRequest('POST', '/vehicles', {
      vehicleNumber: `TN-STRESS-${Math.floor(Math.random() * 9999)}`,
      driverName: 'Stress Tester'
    });
    console.log(`✅ 1 Vehicle created.`);

    // 4. Create GCs
    console.log("Rapid-firing 100 GC Entries concurrently...");
    const gcPromises = Array.from({ length: 100 }).map((_, i) => {
      const mode = i % 2 === 0 ? 'A' : 'B';
      const prefix = mode === 'A' ? 'AP' : 'BELL';
      return makeRequest('POST', '/gcs', {
        gcNumber: `${prefix}-STRESS-${Date.now()}-${i}`,
        financialYear: '2026-2027',
        consignorId: consignors[Math.floor(Math.random() * consignors.length)].id,
        consigneeId: consignees[Math.floor(Math.random() * consignees.length)].id,
        date: new Date().toISOString().split('T')[0],
        invoiceValue: 5000 + i,
        goods: [{ articles: 10, units: 'Boxes', description: 'Stress Test Goods' }]
      });
    });
    
    const startGcTime = Date.now();
    const gcs = await Promise.all(gcPromises);
    console.log(`✅ 100 GCs created in ${Date.now() - startGcTime}ms!`);

    // 5. Create GDMs grouping the GCs
    console.log("Grouping GCs into 20 GDMs concurrently...");
    const gdmPromises = [];
    for (let i = 0; i < 20; i++) {
      const gdmGcs = gcs.slice(i * 5, (i + 1) * 5).map(g => g.id);
      gdmPromises.push(makeRequest('POST', '/gdms', {
        gdmNumber: `GDM-STRESS-${Date.now()}-${i}`,
        date: new Date().toISOString().split('T')[0],
        vehicleId: vehicle.id,
        fromLocation: 'Stress Hub',
        toName: 'Multiple',
        gcIds: gdmGcs
      }));
    }
    
    const startGdmTime = Date.now();
    await Promise.all(gdmPromises);
    console.log(`✅ 20 GDMs created in ${Date.now() - startGdmTime}ms!`);

    const totalTime = (Date.now() - startTime) / 1000;
    console.log(`\n🎉 STRESS TEST COMPLETE in ${totalTime.toFixed(2)} seconds!`);
    console.log(`No crashes, no failed requests. The backend is rock solid.`);
    
  } catch (error) {
    console.error("❌ STRESS TEST FAILED:", error.message);
  }
}

runStressTest();
