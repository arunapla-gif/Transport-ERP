const axios = require('axios');

async function testApi(trackingFor, paramKey) {
  try {
    const response = await axios.post(
      'https://fastagtracking.com/qiktrack/trackingApi',
      {
        company_id: '6a34b131bddbed7aa5d9a373',
        tracking_For: trackingFor,
        parameters: {
          [paramKey]: 'DL1420110012345',
          dob: '01-01-1990'
        }
      },
      { headers: { 'Content-Type': 'application/json' } }
    );
    console.log(`\n--- testing tracking_For: ${trackingFor} | param: ${paramKey} ---`);
    console.log(response.data);
  } catch (err) {
    console.error(`\n--- Error for ${trackingFor} ---`, err.message);
  }
}

async function run() {
  await testApi('SARATHI', 'dlnumber');
  await testApi('SARATHI', 'dl_number');
  await testApi('DL', 'dlnumber');
  await testApi('DL', 'dl_number');
  await testApi('DRIVING_LICENSE', 'dlnumber');
  await testApi('SARATHI', 'vehiclenumber');
}

run();
