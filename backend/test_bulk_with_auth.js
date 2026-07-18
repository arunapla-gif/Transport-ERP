async function test() {
  try {
    // 1. Get Token
    const loginRes = await fetch('http://127.0.0.1:5005/api/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ accessPin: '0000' }) // try a pin
    });
    const loginData = await loginRes.json();
    if (!loginData.token) throw new Error("Login failed, token not received");
    
    const token = loginData.token;
    
    // 2. Run Bulk Heal
    const gcs = [{
      id: 99999,
      gcNumber: 'BELL-1234',
      invoiceValue: 1000,
      goods: [{ hsn: 3604, description: 'Crackers', articleCount: 1 }],
      consignor: { gstin: '33AAICA2420M1ZA', state: 'Tamil Nadu' },
      consignee: { gstin: '33AAICA2420M1ZA', state: 'Tamil Nadu' }
    }];
    
    const res = await fetch('http://127.0.0.1:5005/api/ewaybill/bulk-heal', {
      method: 'POST',
      headers: { 
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`
      },
      body: JSON.stringify({ gcs, vehicleNo: 'TN67AB1234' })
    });
    
    const data = await res.json();
    console.log(JSON.stringify(data, null, 2));
  } catch (e) {
    console.error(e);
  }
}
test();
