const axios = require('axios');

async function testFastag() {
  try {
    const response = await axios.post(
      'https://fastagtracking.com/qiktrack/trackingApi',
      {
        company_id: '6a34b131bddbed7aa5d9a373',
        tracking_For: 'FASTAG',
        parameters: {
          vehiclenumber: 'TN95K5959'
        }
      },
      { headers: { 'Content-Type': 'application/json' } }
    );
    console.log(response.data);
  } catch (err) {
    if (err.response) {
      console.log(`\n--- Error 404 Body ---`);
      console.log(err.response.data);
    } else {
      console.error(`\n--- Error ---`, err.message);
    }
  }
}

testFastag();
