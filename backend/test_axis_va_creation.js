const axios = require('axios');
const crypto = require('crypto');

async function testVirtualAccountCreation() {
    // Using the credentials verified earlier
    const CLIENT_ID = "a4cb180020e1978f36be546770f896e1";
    const CLIENT_SECRET = "9a8327d2083f91326019fcaaca386cd7";

    const url = "https://apiportal.axis.bank.in/gateway/api/v1/cra/virtual-master/update-virtual-account-details";

    const payload = {
        "Data": {
            "ouId": "GAXISINDIA",
            "customerId": "849000096",
            "corporateIdentificationId": "P00FIN",
            "clientCode": "ARUN",
            "virtualAccountNumber": "ARUN0000001",
            "nm": "Arun Transport ERP",
            "emailId": "test@transport.com",
            "sms": "9999999999",
            "creditorAccountReference": "913020000050652", // Actual Corporate Bank Account (Masked in docs)
            "currency": "INR",
            "status": "A", // Active
            "actionValue": "1" // 1 = Create
        },
        "Meta": {}
    };

    console.log("🚀 Sending Virtual Account Creation Request to Sandbox...");
    
    try {
        const response = await axios.post(url, payload, {
            headers: {
                'X-IBM-Client-Id': CLIENT_ID,
                'X-IBM-Client-Secret': CLIENT_SECRET,
                'x-fapi-channel-id': 'UAT',
                'x-fapi-epoch-millis': Date.now().toString(),
                'x-fapi-uuid': crypto.randomUUID().replace(/-/g, ''),
                'x-fapi-serviceId': 'CRA',
                'x-fapi-serviceVersion': '2.0',
                'x-axis-test-id': 1, // 1 = Success response in Sandbox
                'Content-Type': 'application/json'
            }
        });

        console.log("\n✅ SUCCESS: Virtual Account Master API responded!");
        console.log("Status:", response.status);
        console.log("Response Data:", JSON.stringify(response.data, null, 2));
    } catch (error) {
        console.log("\n❌ ERROR: Virtual Account Creation failed!");
        if (error.response) {
            console.log("Status:", error.response.status);
            console.log("Error Data:", JSON.stringify(error.response.data, null, 2));
        } else {
            console.log("Error Message:", error.message);
        }
    }
}

testVirtualAccountCreation();
