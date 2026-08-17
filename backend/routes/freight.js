const express = require('express');
const router = express.Router();
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// ==============================
// FREIGHT BILL ENDPOINTS
// ==============================
router.get('/freight-bills', async (req, res) => {
  try {
    const bills = await prisma.freightBill.findMany({ orderBy: { id: 'desc' } });
    res.json(bills);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch Freight Bills' });
  }
});

router.post('/freight-bills', async (req, res) => {
  try {
    const billData = req.body;
    
    if (billData.date) billData.date = new Date(billData.date);
    if (billData.grossFreight) billData.grossFreight = parseFloat(billData.grossFreight);
    if (billData.advancePaid) billData.advancePaid = parseFloat(billData.advancePaid);
    if (billData.commission) billData.commission = parseFloat(billData.commission);
    if (billData.shortage) billData.shortage = parseFloat(billData.shortage);
    if (billData.tds) billData.tds = parseFloat(billData.tds);
    if (billData.netBalance) billData.netBalance = parseFloat(billData.netBalance);

    const bill = await prisma.freightBill.create({
      data: billData
    });
    res.status(201).json(bill);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to create Freight Bill' });
  }
});

module.exports = router;
