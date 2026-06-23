const axios = require('axios');
const xml2js = require('xml2js');

async function testVahan() {
  try {
    const response = await axios.post(
      'https://fastagtracking.com/qiktrack/trackingApi',
      {
        company_id: '6a34b131bddbed7aa5d9a373',
        tracking_For: 'VAHAN',
        parameters: {
          vehiclenumber: 'TN95K5959'
        }
      },
      { headers: { 'Content-Type': 'application/json' } }
    );
    
    if (response.data.error === "true" || !response.data.response || response.data.response.length === 0) {
      console.log('API Error:', response.data.message);
      return;
    }

    const xmlData = response.data.response[0]?.response;
    const parser = new xml2js.Parser({ explicitArray: false });
    const result = await parser.parseStringPromise(xmlData);
    
    console.log(`\n--- SUCCESS for TN95K5959 ---`);
    console.log(result.VehicleDetails);
  } catch (err) {
    console.error(`\n--- Error ---`, err.message);
  }
}

testVahan();
