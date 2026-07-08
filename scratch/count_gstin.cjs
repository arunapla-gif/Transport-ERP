const xlsx = require('xlsx');
const path = require('path');

function analyzeFile(filename) {
    try {
        const workbook = xlsx.readFile(filename);
        const sheetName = workbook.SheetNames[0];
        const worksheet = workbook.Sheets[sheetName];
        const data = xlsx.utils.sheet_to_json(worksheet);
        
        let totalRecords = data.length;
        let withGstin = 0;
        let uniqueGstins = new Set();
        
        data.forEach(row => {
            const gstin = row['GSTIN'];
            if (gstin && typeof gstin === 'string' && gstin.trim().length > 0) {
                withGstin++;
                uniqueGstins.add(gstin.trim());
            }
        });
        
        console.log(`\n--- Analysis for ${path.basename(filename)} ---`);
        console.log(`Total Records: ${totalRecords}`);
        console.log(`Records with GSTIN: ${withGstin}`);
        console.log(`Unique GSTINs: ${uniqueGstins.size}`);
        
    } catch (e) {
        console.error(`Error reading ${filename}: ${e.message}`);
    }
}

analyzeFile(path.join(__dirname, '../Book2.xlsx'));
