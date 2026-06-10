const xlsx = require('xlsx');
const path = require('path');

const filePath = path.join(__dirname, '..', 'gc 4.5-3.6.xlsx');
const workbook = xlsx.readFile(filePath);
const sheetName = workbook.SheetNames[0];
const sheet = workbook.Sheets[sheetName];
const data = xlsx.utils.sheet_to_json(sheet);

const first20 = data.slice(0, 20).map(row => ({
  GC_No: row['GC No'],
  Date: row['GC Date'],
  Consignor: row['Consignor'],
  Consignee: row['Consingee'],
  Lorry: row['Despatch Lorry']
}));

console.log(JSON.stringify(first20, null, 2));
