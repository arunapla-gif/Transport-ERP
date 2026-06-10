const xlsx = require('xlsx');
const path = require('path');

function analyzeFile(filename) {
  const filePath = path.join(__dirname, '..', filename);
  console.log(`\n--- Analyzing ${filename} ---`);
  try {
    const workbook = xlsx.readFile(filePath);
    console.log(`Sheets: ${workbook.SheetNames.join(', ')}`);
    const sheet = workbook.Sheets[workbook.SheetNames[0]];
    const data = xlsx.utils.sheet_to_json(sheet, { header: 1 });
    console.log(`Rows: ${data.length}`);
    if (data.length > 0) {
      console.log('Headers:', data[0]);
    }
    if (data.length > 1) {
      console.log('First Data Row:', data[1]);
    }
  } catch (err) {
    console.error(`Error reading ${filename}:`, err.message);
  }
}

analyzeFile('Book1.xlsx');
analyzeFile('Book2.xlsx');
