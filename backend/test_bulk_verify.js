const ewbNo = "522014329109"; // A known active EWB
fetch('http://localhost:5005/api/ewaybill/bulk-verify', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ ewbs: [{ ewbNo, company: 'AP' }] })
}).then(res => res.json()).then(console.log).catch(console.error);
