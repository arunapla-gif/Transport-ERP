const xlsx = require('xlsx');
const path = require('path');

function run() {
  const filePath = path.join(__dirname, '..', 'Book2.xlsx');
  try {
    const workbook = xlsx.readFile(filePath);
    const sheet = workbook.Sheets[workbook.SheetNames[0]];
    const data = xlsx.utils.sheet_to_json(sheet);
    
    let withGst = 0;
    let withoutGst = 0;

    data.forEach(row => {
      const gstin = row['GST NO'] || row['GSTIN'] || row['gst no'] || row['GST NO '];
      if (gstin && String(gstin).trim().length > 0) {
        withGst++;
      } else {
        withoutGst++;
      }
    });

    console.log(`Total Consignees in Excel: ${data.length}`);
    console.log(`With GSTIN: ${withGst}`);
    console.log(`Without GSTIN: ${withoutGst}`);
    
  } catch (err) {
    console.error(`Error reading Book2.xlsx:`, err.message);
  }
}

run();
