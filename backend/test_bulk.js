async function test() {
  const gcs = [{
    id: 99999,
    gcNumber: 'BELL-1234',
    invoiceValue: 1000,
    goods: [{ hsn: 3604, description: 'Crackers', articleCount: 1 }],
    consignor: { gstin: '33AAICA2420M1ZA', state: 'Tamil Nadu' },
    consignee: { gstin: '33AAICA2420M1ZA', state: 'Tamil Nadu' }
  }];
  
  try {
    const res = await fetch('http://127.0.0.1:5005/api/ewaybill/bulk-heal', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ gcs, vehicleNo: 'TN67AB1234' })
    });
    const data = await res.json();
    console.log(JSON.stringify(data, null, 2));
  } catch (e) {
    console.error(e);
  }
}
test();
