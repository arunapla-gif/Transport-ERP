const xlsx = require('xlsx');

function run() {
  const workbook = xlsx.readFile('/Users/arun_ap/Desktop/TRANSPORT ERP/Book1.xlsx');
  const sheet = workbook.Sheets[workbook.SheetNames[0]];
  const data = xlsx.utils.sheet_to_json(sheet);
  
  let gstinCount = 0;
  const uniqueGstins = new Set();
  const hiddenGstins = new Set();
  const strictPattern = /^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}[Z]{1}[0-9A-Z]{1}$/i;

  for (const row of data) {
    let hasGstin = false;

    // Check GSTIN column
    const gstin = row['GST NO'] || row['GSTIN'] || row['gst no'] || row['GST NO '];
    if (gstin && String(gstin).trim().length > 0) {
      hasGstin = true;
      uniqueGstins.add(String(gstin).trim().toUpperCase());
      gstinCount++;
    }

    // Check Phone column for hidden GSTIN
    if (!hasGstin) {
      const c1 = row['Contact1'] ? String(row['Contact1']).trim() : '';
      const c2 = row['Contact2'] ? String(row['Contact2']).trim() : '';
      const phone = [c1, c2].filter(Boolean).join(', ');
      
      const parts = phone.split(/[,/\s]+/);
      for (const part of parts) {
        const cleanPart = part.trim();
        if (cleanPart.length === 15 && strictPattern.test(cleanPart)) {
          hiddenGstins.add(cleanPart.toUpperCase());
          break;
        }
      }
    }
  }

  console.log(`Total rows with explicit GSTIN: ${gstinCount}`);
  console.log(`Unique explicit GSTINs: ${uniqueGstins.size}`);
  console.log(`Unique hidden GSTINs (in phone): ${hiddenGstins.size}`);
}

run();
