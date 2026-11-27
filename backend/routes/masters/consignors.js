const express = require('express');
const router = express.Router();
const prisma = require('../../db');
const { cacheMiddleware } = require('../../middleware/cache');

router.get('/', cacheMiddleware(3600), async (req, res) => {
  try {
    const branch = req.query.branch || 'MAIN';
    const page = req.query.page ? parseInt(req.query.page) : null;
    const limit = req.query.limit ? parseInt(req.query.limit) : 50;
    const q = req.query.q ? req.query.q.trim().toLowerCase() : '';
    
    const branchCondition = (branch && branch !== 'ALL') ? {
      OR: [
        { branch: branch },
        { branch: 'ALL' },
        { branch: null }
      ]
    } : {};

    let consignors = await prisma.consignor.findMany({ 
      where: branchCondition,
      orderBy: { id: 'desc' }
    });

    if (q) {
      consignors = consignors.filter(c => {
        const nameStr = (c.name || '').toLowerCase();
        const legalStr = (c.legalName || '').toLowerCase();
        const cityStr = (c.city || '').toLowerCase();
        const gstinStr = (c.gstin || '').toLowerCase();
        const phoneStr = (c.phone || '').toLowerCase();
        const addrStr = JSON.stringify(c.addresses || []).toLowerCase();
        return nameStr.includes(q) || legalStr.includes(q) || cityStr.includes(q) || gstinStr.includes(q) || phoneStr.includes(q) || addrStr.includes(q);
      });
    }

    const total = consignors.length;

    if (!page) {
      return res.json(consignors);
    }

    const skip = (page - 1) * limit;
    const paginatedData = consignors.slice(skip, skip + limit);

    res.json({
      data: paginatedData,
      total,
      hasMore: (skip + paginatedData.length) < total,
      nextCursor: (skip + paginatedData.length) < total ? page + 1 : null
    });
  } catch (error) {
    console.error('Error fetching consignors:', error);
    res.status(500).json({ error: 'Failed to fetch consignors' });
  }
});

router.get('/search', async (req, res) => {
  try {
    const { branch = 'MAIN', q = '' } = req.query;
    if (!q || q.trim() === '') return res.json([]);
    const results = await prisma.consignor.findMany({
      where: {
        branch,
        isActive: true,
        OR: [
          { name: { contains: q, mode: 'insensitive' } },
          { gstin: { contains: q, mode: 'insensitive' } }
        ]
      },
      take: 50,
      orderBy: { name: 'asc' }
    });
    res.json(results);
  } catch (error) {
    res.status(500).json({ error: 'Search failed' });
  }
});

router.post('/', async (req, res) => {
  try {
    const { name, branch = 'MAIN', ...rest } = req.body;
    const consignor = await prisma.consignor.upsert({
      where: { name_branch: { name, branch } },
      update: { ...rest, branch },
      create: { name, branch, ...rest }
    });
    res.json(consignor);
  } catch (error) {
    console.error("Error creating consignor:", error);
    if (error.code === 'P2002') {
      return res.status(400).json({ error: 'A Consignor with this Name already exists in this branch.' });
    }
    res.status(500).json({ error: error.message || 'Failed to create consignor' });
  }
});

router.put('/:id', async (req, res) => {
  try {
    const consignor = await prisma.consignor.update({
      where: { id: parseInt(req.params.id) },
      data: {
        ...req.body,
        stateCode: req.body.stateCode !== undefined ? req.body.stateCode : undefined
      },
    });
    res.json(consignor);
  } catch (error) {
    console.error("Error updating consignor:", error);
    if (error.code === 'P2002') {
      return res.status(400).json({ error: 'A Consignor with this verified Name already exists in this branch. Please delete this duplicate old record and use the existing one.' });
    }
    res.status(500).json({ error: error.message || 'Failed to update consignor' });
  }
});

router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    await prisma.consignor.update({
      where: { id: parseInt(id) },
      data: { isActive: false }
    });
    res.json({ message: 'Consignor archived successfully' });
  } catch (error) {
    res.status(500).json({ error: 'Failed to archive consignor' });
  }
});

router.put('/:id/restore', async (req, res) => {
  try {
    const { id } = req.params;
    const consignor = await prisma.consignor.update({
      where: { id: parseInt(id) },
      data: { isActive: true }
    });
    res.json(consignor);
  } catch (error) {
    res.status(500).json({ error: 'Failed to restore consignor' });
  }
});

module.exports = router;
