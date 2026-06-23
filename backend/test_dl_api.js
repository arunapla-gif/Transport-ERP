const axios = require('axios');

async function testApi(stringifyParams) {
  try {
    const paramsObj = {
      dlnumber: 'HR-0619900012345',
      dob: '1990-01-01'
    };

    const payload = {
      company_id: '6a34b131bddbed7aa5d9a373',
      tracking_For: 'SARATHI',
      parameters: stringifyParams ? JSON.stringify(paramsObj) : paramsObj
    };
    
    const response = await axios.post(
      'https://fastagtracking.com/qiktrack/trackingApi',
      payload,
      { headers: { 'Content-Type': 'application/json' } }
    );
    console.log(`\n--- SUCCESS ---`);
    console.log(response.data);
  } catch (err) {
    if (err.response) {
      console.log(`\n--- Error ---`, err.response.data);
    } else {
      console.log(`\n--- Error ---`, err.message);
    }
  }
}

async function run() {
  await testApi(true); // Test with stringified parameters
}

run();
