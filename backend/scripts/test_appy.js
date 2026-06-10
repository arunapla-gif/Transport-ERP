const keySecret = process.env.APPYFLOW_KEY_SECRET || '7eWP3WelRNexYGJ172L3Hb8JNrY2';
async function test() {
  const gstin = '29DZZPK7645L1Z2'; // known good
  const res = await fetch(`https://appyflow.in/api/verifyGST?gstNo=${gstin}&key_secret=${keySecret}`);
  const data = await res.json();
  console.log('Testing known good GSTIN:', gstin);
  if (data.error) {
    console.log('Error:', data.message);
  } else {
    console.log('Success! Found company:', data.taxpayerInfo?.tradeNam);
  }
}
test();
