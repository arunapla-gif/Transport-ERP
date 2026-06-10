const xlsx = require('xlsx');
const path = require('path');

const filePath = path.join(__dirname, '..', 'gc 4.5-3.6.xlsx');
const workbook = xlsx.readFile(filePath);
const sheetName = workbook.SheetNames[0];
const sheet = workbook.Sheets[sheetName];
const data = xlsx.utils.sheet_to_json(sheet).slice(0, 100);

let consignors = {};
let consignees = {};
let dates = {};
let lorries = {};

data.forEach(row => {
  const cnor = String(row['Consignor']).trim();
  const cnee = String(row['Consingee']).trim();
  const date = String(row['GC Date']).trim();
  const lorry = String(row['Despatch Lorry']).trim();
  
  consignors[cnor] = (consignors[cnor] || 0) + 1;
  consignees[cnee] = (consignees[cnee] || 0) + 1;
  dates[date] = (dates[date] || 0) + 1;
  if(lorry && lorry !== 'undefined') lorries[lorry] = (lorries[lorry] || 0) + 1;
});

console.log("=== TOP 5 CONSIGNORS ===");
console.log(Object.entries(consignors).sort((a,b)=>b[1]-a[1]).slice(0, 5));

console.log("\n=== TOP 5 CONSIGNEES ===");
console.log(Object.entries(consignees).sort((a,b)=>b[1]-a[1]).slice(0, 5));

console.log("\n=== DATE DISTRIBUTION ===");
console.log(dates);

console.log("\n=== UNIQUE LORRIES ===");
console.log(Object.keys(lorries).length);

console.log("\n=== TOTAL CONSIGNORS / CONSIGNEES ===");
console.log(Object.keys(consignors).length, "Consignors");
console.log(Object.keys(consignees).length, "Consignees");
