const xlsx = require('xlsx');
const path = require('path');

function analyzeFile(filename) {
    try {
        console.log(`\n--- Analyzing ${filename} ---`);
        const workbook = xlsx.readFile(filename);
        const sheetName = workbook.SheetNames[0];
        console.log(`Sheet Name: ${sheetName}`);
        
        const worksheet = workbook.Sheets[sheetName];
        const data = xlsx.utils.sheet_to_json(worksheet, { header: 1 });
        
        console.log('Headers:');
        console.log(data[0]);
        console.log('\nFirst 3 rows:');
        for (let i = 1; i <= 3 && i < data.length; i++) {
            console.log(data[i]);
        }
    } catch (e) {
        console.error(`Error reading ${filename}: ${e.message}`);
    }
}

analyzeFile(path.join(__dirname, '../Book1.xlsx'));
analyzeFile(path.join(__dirname, '../Book2.xlsx'));
