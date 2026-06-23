const fs = require('fs');
const MDBReader = require('mdb-reader').default;

const mdbPath = '/Users/arun_ap/Desktop/TRANSPORT ERP/JellyAccounts/AP Lorry Transport/data/Masters.mdb';

try {
  const buffer = fs.readFileSync(mdbPath);
  const reader = new MDBReader(buffer);

  // Get table names
  const tableNames = reader.getTableNames();
  console.log("Tables found:", tableNames);

  // If there's a table that sounds like Consignors or Customers, print a few rows
  const targetTable = tableNames.find(t => t.toLowerCase().includes('consignor') || t.toLowerCase().includes('customer') || t.toLowerCase().includes('party'));
  
  if (targetTable) {
    console.log(`\nReading table: ${targetTable}`);
    const table = reader.getTable(targetTable);
    const rows = table.getData();
    console.log(`Found ${rows.length} rows.`);
    console.log("First 2 rows:", rows.slice(0, 2));
  }
} catch (err) {
  console.error("Error reading MS Access file:", err);
}
