const axios = require('axios');

async function testAxisSandbox() {
    // ⚠️ Replace these with your actual Client ID and Secret from the Portal
    const CLIENT_ID = "a4cb180020e1978f36be546770f896e1";
    const CLIENT_SECRET = "9a8327d2083f91326019fcaaca386cd7";

    const url = "https://apiportal.axis.bank.in/gateway/api/v1/posting-notification";

    const payload = {
        "SubHeader": {
            "requestUUID": "TEST12345678",
            "serviceRequestId": "OCR",
            "serviceRequestVersion": "1.0",
            "channelId": "UAT"
        },
        "PostingNotificationRequestBody": {
            "UTR": "28062021",
            "Bene_acc_no": "NBSP123MHW987654321",
            "Req_type": "notification",
            "Req_dt_time": new Date().toISOString(),
            "Txn_amnt": "49999.99",
            "Corp_code": " NBSP ",
            "Pmode": "NEFT",
            "Sndr_acnt": "910910910910910",
            "Sndr_nm": "Arun Test Pvt Ltd",
            "Sndr_acnt1": "120120120120120",
            "Sndr_nm1": "Arun Test Pvt Ltd",
            "Sndr_ifsc": "HDFC0000522",
            "Tran_id": "12345"
        }
    };

    console.log("🚀 Sending Test Request to Axis Bank Sandbox...");
    
    try {
        const response = await axios.post(url, payload, {
            headers: {
                'X-IBM-Client-Id': CLIENT_ID,
                'X-IBM-Client-Secret': CLIENT_SECRET,
                'X-AXIS-TEST-ID': 1, // 1 = Success response in Sandbox
                'Content-Type': 'application/json'
            }
        });

        console.log("\n✅ SUCCESS: Sandbox responded!");
        console.log("Status:", response.status);
        console.log("Response Data:", JSON.stringify(response.data, null, 2));
    } catch (error) {
        console.log("\n❌ ERROR: Sandbox request failed!");
        if (error.response) {
            console.log("Status:", error.response.status);
            console.log("Error Data:", JSON.stringify(error.response.data, null, 2));
        } else {
            console.log("Error Message:", error.message);
        }
    }
}

testAxisSandbox();
