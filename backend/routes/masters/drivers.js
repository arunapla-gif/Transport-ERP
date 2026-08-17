const express = require('express');
const router = express.Router();
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

router.get('/', async (req, res) => {
  try {
    const page = req.query.page ? parseInt(req.query.page) : null;
    const limit = req.query.limit ? parseInt(req.query.limit) : 50;
    const q = req.query.q || '';
    
    let whereClause = {};
    if (q) {
      whereClause.OR = [
        { name: { contains: q, mode: 'insensitive' } },
        { phone: { contains: q, mode: 'insensitive' } },
        { licenseNo: { contains: q, mode: 'insensitive' } }
      ];
    }

    if (!page) {
      const drivers = await prisma.driver.findMany({ 
        where: whereClause,
        orderBy: { updatedAt: 'desc' },
        take: 2000
      });
      return res.json(drivers);
    }

    const skip = (page - 1) * limit;
    const [data, total] = await Promise.all([
      prisma.driver.findMany({
        where: whereClause,
        orderBy: { updatedAt: 'desc' },
        skip,
        take: limit
      }),
      prisma.driver.count({ where: whereClause })
    ]);

    res.json({
      data,
      total,
      hasMore: (skip + data.length) < total,
      nextCursor: (skip + data.length) < total ? page + 1 : null
    });
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch drivers' });
  }
});

router.post('/', async (req, res) => {
  try {
    const data = { ...req.body };
    delete data.id;
    const driver = await prisma.driver.create({ data });
    res.json(driver);
  } catch (error) {
    console.error("Failed to create driver:", error);
    if (error.code === 'P2002') return res.status(400).json({ error: 'License Number already exists' });
    res.status(500).json({ error: 'Failed to create driver' });
  }
});

router.put('/:id', async (req, res) => {
  try {
    const data = { ...req.body };
    delete data.id;
    const driver = await prisma.driver.update({
      where: { id: parseInt(req.params.id) },
      data,
    });
    res.json(driver);
  } catch (error) {
    console.error("Failed to update driver:", error);
    if (error.code === 'P2002') return res.status(400).json({ error: 'License Number already exists' });
    res.status(500).json({ error: 'Failed to update driver' });
  }
});

router.delete('/:id', async (req, res) => {
  try {
    await prisma.driver.delete({ where: { id: parseInt(req.params.id) } });
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: 'Failed to delete driver' });
  }
});

module.exports = router;
