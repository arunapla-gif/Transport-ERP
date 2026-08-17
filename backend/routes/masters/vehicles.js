const express = require('express');
const router = express.Router();
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const { cacheMiddleware } = require('../../middleware/cache');

router.get('/', cacheMiddleware(3600), async (req, res) => {
  try {
    const page = req.query.page ? parseInt(req.query.page) : null;
    const limit = req.query.limit ? parseInt(req.query.limit) : 50;
    const q = req.query.q || '';
    
    let whereClause = {};
    if (q) {
      whereClause.vehicleNo = { contains: q, mode: 'insensitive' };
    }

    if (!page) {
      const vehicles = await prisma.vehicle.findMany({ 
        where: whereClause,
        orderBy: { id: 'desc' },
        take: 500
      });
      return res.json(vehicles);
    }

    const skip = (page - 1) * limit;
    const [data, total] = await Promise.all([
      prisma.vehicle.findMany({
        where: whereClause,
        orderBy: { id: 'desc' },
        skip,
        take: limit
      }),
      prisma.vehicle.count({ where: whereClause })
    ]);

    res.json({
      data,
      total,
      hasMore: (skip + data.length) < total,
      nextCursor: (skip + data.length) < total ? page + 1 : null
    });
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch vehicles' });
  }
});

router.post('/', async (req, res) => {
  try {
    const data = { ...req.body };
    if (data.fitnessExpiry) data.fitnessExpiry = new Date(data.fitnessExpiry);
    else data.fitnessExpiry = null;
    
    if (data.insuranceExpiry) data.insuranceExpiry = new Date(data.insuranceExpiry);
    else data.insuranceExpiry = null;
    
    if (data.npExpiry) data.npExpiry = new Date(data.npExpiry);
    else data.npExpiry = null;
    
    const vehicle = await prisma.vehicle.create({ data });
    res.json(vehicle);
  } catch (error) {
    if (error.code === 'P2002') {
      return res.status(400).json({ error: 'Vehicle Number already exists' });
    }
    res.status(500).json({ error: 'Failed to create vehicle' });
  }
});

router.put('/:id', async (req, res) => {
  try {
    const data = { ...req.body };
    if (data.fitnessExpiry) data.fitnessExpiry = new Date(data.fitnessExpiry);
    else data.fitnessExpiry = null;
    
    if (data.insuranceExpiry) data.insuranceExpiry = new Date(data.insuranceExpiry);
    else data.insuranceExpiry = null;
    
    if (data.npExpiry) data.npExpiry = new Date(data.npExpiry);
    else data.npExpiry = null;

    const vehicle = await prisma.vehicle.update({
      where: { id: parseInt(req.params.id) },
      data,
    });
    res.json(vehicle);
  } catch (error) {
    if (error.code === 'P2002') {
      return res.status(400).json({ error: 'Vehicle Number already exists' });
    }
    res.status(500).json({ error: 'Failed to update vehicle' });
  }
});

router.delete('/:id', async (req, res) => {
  try {
    await prisma.vehicle.delete({ where: { id: parseInt(req.params.id) } });
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: 'Failed to delete vehicle' });
  }
});

module.exports = router;
