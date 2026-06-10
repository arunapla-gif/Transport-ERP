const xlsx = require('xlsx');

try {
  const workbook = xlsx.readFile('../gc 4.5-3.6.xlsx');
  const sheetName = workbook.SheetNames[0];
  const worksheet = workbook.Sheets[sheetName];
  const data = xlsx.utils.sheet_to_json(worksheet, { header: 1 });
  
  if (data.length > 0) {
    console.log("Headers:");
    console.log(data[0]);
    console.log("\nFirst row of data:");
    console.log(data[1]);
    console.log(`\nTotal rows: ${data.length}`);
  }
} catch (e) {
  console.error("Error reading file:", e.message);
}
