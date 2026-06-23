const axios = require('axios');

async function testVahan(endpoint) {
  try {
    const response = await axios.post(
      `https://fastagtracking.com/qiktrack/${endpoint}`,
      {
        company_id: '6a34b131bddbed7aa5d9a373',
        tracking_For: 'VAHAN',
        parameters: {
          vehiclenumber: 'TN95K5959'
        }
      },
      { headers: { 'Content-Type': 'application/json' } }
    );
    console.log(`\n--- SUCCESS for ${endpoint} ---`);
    console.log("Error status:", response.data.error);
    console.log("Message:", response.data.message);
  } catch (err) {
    if (err.response) {
      console.log(`\n--- Error for ${endpoint} ---`, err.response.status, err.response.data);
    } else {
      console.log(`\n--- Error ---`, err.message);
    }
  }
}

async function run() {
  await testVahan('trackingApi');
  await testVahan('tracking-Api');
}

run();
