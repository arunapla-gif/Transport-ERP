const xlsx = require('xlsx');
const path = require('path');

console.log("=== Book1.xlsx (Consignees) ===");
try {
  const wb1 = xlsx.readFile(path.join(__dirname, '..', 'Book1.xlsx'));
  const sheet1 = wb1.Sheets[wb1.SheetNames[0]];
  console.log(xlsx.utils.sheet_to_json(sheet1).slice(0, 2));
} catch(e) { console.log("Failed", e.message); }

console.log("\n=== Book2.xlsx (Consignors) ===");
try {
  const wb2 = xlsx.readFile(path.join(__dirname, '..', 'Book2.xlsx'));
  const sheet2 = wb2.Sheets[wb2.SheetNames[0]];
  console.log(xlsx.utils.sheet_to_json(sheet2).slice(0, 2));
} catch(e) { console.log("Failed", e.message); }
