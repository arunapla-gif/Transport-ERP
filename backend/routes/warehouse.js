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
    const branch = req.user?.branch || req.headers['x-branch-id'] || 'MAIN';
    let whereClause = {};

    if (branch && branch !== 'ALL') {
      whereClause.branch = branch;
    }
    
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
      orderBy: { createdAt: 'desc' },
      take: limit
    });
    res.json(inwards);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to fetch inward entries' });
  }
});

router.post('/warehouse-inward', async (req, res) => {
  try {
    const branch = req.user?.branch || req.headers['x-branch-id'] || 'MAIN';
    const { consignorName, consigneeName, articles, godownNo, ewayBillNo, remarks, consigneeCity } = req.body;

    if (!consignorName || !consigneeName || !articles || !godownNo) {
      return res.status(400).json({ error: 'Consignor, Consignee, Articles, and Godown are required.' });
    }

    // Auto-retry with incremented receipt number to prevent concurrent collision
    let attempts = 0;
    let inward = null;
    while (attempts < 3) {
      try {
        const lastEntry = await prisma.warehouseInward.findFirst({
          orderBy: { receiptNo: 'desc' },
          where: { receiptNo: { not: null } }
        });
        const nextReceiptNo = lastEntry && lastEntry.receiptNo ? lastEntry.receiptNo + 1 : 1;

        inward = await prisma.warehouseInward.create({ 
          data: {
            consignorName,
            consigneeName,
            consigneeCity: consigneeCity || null,
            articles: parseInt(articles) || 1,
            godownNo,
            ewayBillNo: ewayBillNo || null,
            remarks: remarks || null,
            branch,
            receiptNo: nextReceiptNo
          } 
        });
        break;
      } catch (createErr) {
        if (createErr.code === 'P2002' && attempts < 2) {
          attempts++;
          continue;
        }
        throw createErr;
      }
    }

    res.json(inward);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to save inward entry' });
  }
});

router.put('/warehouse-inward/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { receiptNo, ...allowedUpdates } = req.body; // Protect receiptNo from arbitrary tampering
    const inward = await prisma.warehouseInward.update({
      where: { id: parseInt(id) },
      data: allowedUpdates
    });
    res.json(inward);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to update inward entry' });
  }
});

router.delete('/warehouse-inward/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const parsedId = parseInt(id);
    if (isNaN(parsedId) || parsedId <= 0) {
      return res.status(400).json({ error: 'Valid Inward ID is required' });
    }

    const deleted = await prisma.warehouseInward.delete({
      where: { id: parsedId }
    });
    res.json({ message: 'Warehouse inward entry deleted successfully', deleted });
  } catch (error) {
    console.error('Failed to delete warehouse inward:', error);
    res.status(500).json({ error: 'Failed to delete inward entry' });
  }
});

module.exports = router;
