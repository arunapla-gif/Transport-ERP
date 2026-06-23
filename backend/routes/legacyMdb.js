const express = require('express');
const router = express.Router();
const fs = require('fs');
const path = require('path');
const MDBReader = require('mdb-reader').default;

const MS_ACCESS_BASE_PATH = path.join(__dirname, '..', '..', 'JellyAccounts');

// Route to get list of companies (folders)
router.get('/companies', (req, res) => {
  try {
    const folders = fs.readdirSync(MS_ACCESS_BASE_PATH, { withFileTypes: true })
      .filter(dirent => dirent.isDirectory())
      .map(dirent => dirent.name);
    res.json({ companies: folders });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to read JellyAccounts folder' });
  }
});

// Helper to open MDB file based on company and file type
const getReader = (companyName, fileName) => {
  const filePath = path.join(MS_ACCESS_BASE_PATH, companyName, 'data', fileName);
  if (!fs.existsSync(filePath)) {
    throw new Error(`File not found: ${filePath}`);
  }
  const buffer = fs.readFileSync(filePath);
  return new MDBReader(buffer);
};

// Route to get unique financial years from Transactions.mdb
router.get('/:company/financial-years', (req, res) => {
  try {
    const reader = getReader(req.params.company, 'Transactions.mdb');
    const table = reader.getTable('ConsignmentDB');
    const data = table.getData();
    const years = [...new Set(data.map(r => r.DispatchYear || r.Financeyear).filter(Boolean))].sort().reverse();
    res.json({ years });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
});

// Route to get Consignors
router.get('/:company/consignors', (req, res) => {
  try {
    const reader = getReader(req.params.company, 'Masters.mdb');
    const table = reader.getTable('ConsignorDB');
    const data = table.getData();
    // Sort or filter if needed, just return top 100 for preview
    res.json({ data: data });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
});

// Route to get Consignees
router.get('/:company/consignees', (req, res) => {
  try {
    const reader = getReader(req.params.company, 'Masters.mdb');
    const table = reader.getTable('ConsigneeDB');
    const data = table.getData();
    res.json({ data: data });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
});

// Route to get Consignments (GCs)
router.get('/:company/transactions', (req, res) => {
  try {
    const transReader = getReader(req.params.company, 'Transactions.mdb');
    const table = transReader.getTable('ConsignmentDB');
    let data = table.getData();
    
    // Read Masters.mdb to get Consignor names
    let consignorMap = {};
    try {
      const mastersReader = getReader(req.params.company, 'Masters.mdb');
      const consignorTable = mastersReader.getTable('ConsignorDB');
      consignorTable.getData().forEach(c => {
        if (c.ConsignorID) {
          consignorMap[c.ConsignorID] = c.ConsignorName;
        }
      });
    } catch (e) {
      console.warn("Could not read Masters.mdb for joining Consignors", e.message);
    }

    // Filter by financial year if provided
    const fy = req.query.fy;
    if (fy) {
      data = data.filter(r => (r.DispatchYear || r.Financeyear) === fy);
    }

    // Map the names onto the transactions
    data = data.map(row => ({
      ...row,
      Fromname: row.Fromname || consignorMap[row.CustomerID] || null
    }));

    // Return all rows reversed (newest first)
    res.json({ data: data.reverse() }); 
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
});

// Route to get GDMs (Despatches)
router.get('/:company/gdms', (req, res) => {
  try {
    const reader = getReader(req.params.company, 'Transactions.mdb');
    const table = reader.getTable('DespatchDB');
    let data = table.getData();
    
    // Filter by financial year if provided
    const fy = req.query.fy;
    if (fy) {
      data = data.filter(r => r.FinancialYear === fy);
    }
    
    res.json({ data: data.reverse() });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
});

// Route to get Virtual Vehicles (extracted from GDMs)
router.get('/:company/vehicles', (req, res) => {
  try {
    const reader = getReader(req.params.company, 'Transactions.mdb');
    const table = reader.getTable('DespatchDB');
    let data = table.getData();
    
    // Filter by financial year if provided
    const fy = req.query.fy;
    if (fy) {
      data = data.filter(r => r.FinancialYear === fy);
    }
    
    // Extract unique vehicles
    const vehicleMap = {};
    data.forEach(row => {
      if (row.LorryNo) {
        const lorryNo = row.LorryNo.trim().toUpperCase();
        if (!vehicleMap[lorryNo]) {
          vehicleMap[lorryNo] = {
            LorryNo: lorryNo,
            LorryName: row.LorryName || '',
            DriverName: row.DriverName || '',
            Cell: row.Cell || row.Ownerno || ''
          };
        } else {
          // If we see it again, overwrite with the most recent driver/cell data if it exists
          if (row.DriverName) vehicleMap[lorryNo].DriverName = row.DriverName;
          if (row.Cell) vehicleMap[lorryNo].Cell = row.Cell;
        }
      }
    });
    
    const uniqueVehicles = Object.values(vehicleMap);
    res.json({ data: uniqueVehicles });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
