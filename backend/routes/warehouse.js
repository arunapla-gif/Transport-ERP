const express = require('express');
const router = express.Router();
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// ==============================
// WAREHOUSE INWARD ENDPOINTS
// ==============================
router.get('/warehouse-inward', async (req, res) => {
  try {
    const { date } = req.query;
    let whereClause = {};
    
    if (date) {
      const startOfDay = new Date(date);
      startOfDay.setHours(0, 0, 0, 0);
      const endOfDay = new Date(date);
      endOfDay.setHours(23, 59, 59, 999);
      whereClause.createdAt = {
        gte: startOfDay,
        lte: endOfDay
      };
    } else {
      // Default to today if no date provided
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      whereClause.createdAt = {
        gte: today
      };
    }

    const page = req.query.page ? parseInt(req.query.page) : undefined;
    const limit = req.query.limit ? parseInt(req.query.limit) : 50;

    if (page) {
      const skip = (page - 1) * limit;
      const [inwards, total] = await Promise.all([
        prisma.warehouseInward.findMany({
          where: whereClause,
          orderBy: { createdAt: 'desc' },
          skip,
          take: limit
        }),
        prisma.warehouseInward.count({ where: whereClause })
      ]);
      return res.json({ data: inwards, total, page, totalPages: Math.ceil(total / limit) });
    }

    const inwards = await prisma.warehouseInward.findMany({
      where: whereClause,
      orderBy: { createdAt: 'desc' }
    });
    res.json(inwards);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to fetch inward entries' });
  }
});

router.post('/warehouse-inward', async (req, res) => {
  try {
    const lastEntry = await prisma.warehouseInward.findFirst({
      orderBy: { receiptNo: 'desc' },
      where: { receiptNo: { not: null } }
    });
    const nextReceiptNo = lastEntry && lastEntry.receiptNo ? lastEntry.receiptNo + 1 : 1;

    const inward = await prisma.warehouseInward.create({ 
      data: { ...req.body, receiptNo: nextReceiptNo } 
    });
    res.json(inward);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to save inward entry' });
  }
});

router.put('/warehouse-inward/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const inward = await prisma.warehouseInward.update({
      where: { id: parseInt(id) },
      data: req.body
    });
    res.json(inward);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to update inward entry' });
  }
});

module.exports = router;
