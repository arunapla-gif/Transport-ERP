const axios = require('axios');

async function testBackend() {
  try {
    const response = await axios.post('http://localhost:5005/api/fastag/dl', {
      dlNumber: "HR4320190000409",
      dob: "1998-12-30"
    });
    console.log("Success:", JSON.stringify(response.data, null, 2));
  } catch (err) {
    if (err.response) {
      console.log("Error status:", err.response.status);
      console.log("Error data:", err.response.data);
    } else {
      console.log("Error:", err.message);
    }
  }
}

testBackend();
