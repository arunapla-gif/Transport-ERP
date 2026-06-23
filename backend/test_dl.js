const axios = require('axios');

async function testDL() {
  try {
    const response = await axios.post(
      'https://fastagtracking.com/qiktrack/tracking-Api',
      {
        company_id: '6a34b131bddbed7aa5d9a373',
        tracking_For: 'SARATHI',
        parameters: {
          dlnumber: 'HR4320190000409',
          dob: '1998-12-30'
        }
      },
      { headers: { 'Content-Type': 'application/json' } }
    );

    console.log("Status:", response.status);
    console.log("Data:", JSON.stringify(response.data, null, 2));

    const rawData = response.data.response[0]?.response;
    if (!rawData || !rawData.personalInformation) {
       console.log("Mapping error: missing personalInformation");
    } else {
       console.log("Mapping Success!");
    }
  } catch (error) {
    if (error.response) {
      console.log("Error Status:", error.response.status);
      console.log("Error Data:", error.response.data);
    } else {
      console.log("Error Message:", error.message);
    }
  }
}

testDL();
