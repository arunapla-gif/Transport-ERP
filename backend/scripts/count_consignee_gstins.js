const xlsx = require('xlsx');
const path = require('path');

const workbook = xlsx.readFile(path.join(__dirname, '..', 'Book1.xlsx'));
const sheet = workbook.Sheets[workbook.SheetNames[0]];
const data = xlsx.utils.sheet_to_json(sheet);

let withGstin = 0;
let withoutGstin = 0;

for (const row of data) {
  const gstin = String(row['GSTIN'] || '').trim();
  if (gstin && gstin.length >= 10) {
    withGstin++;
  } else {
    withoutGstin++;
  }
}

console.log(`Total Consignees: ${data.length}`);
console.log(`With GSTIN: ${withGstin}`);
console.log(`Without GSTIN: ${withoutGstin}`);
