const express = require('express');
const router = express.Router();
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
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

    let consignees = await prisma.consignee.findMany({ 
      where: branchCondition,
      orderBy: { id: 'desc' }
    });

    if (q) {
      consignees = consignees.filter(c => {
        const nameStr = (c.name || '').toLowerCase();
        const legalStr = (c.legalName || '').toLowerCase();
        const cityStr = (c.city || '').toLowerCase();
        const gstinStr = (c.gstin || '').toLowerCase();
        const phoneStr = (c.phone || '').toLowerCase();
        const addrStr = JSON.stringify(c.addresses || []).toLowerCase();
        return nameStr.includes(q) || legalStr.includes(q) || cityStr.includes(q) || gstinStr.includes(q) || phoneStr.includes(q) || addrStr.includes(q);
      });
    }

    const total = consignees.length;

    if (!page) {
      return res.json(consignees);
    }

    const skip = (page - 1) * limit;
    const paginatedData = consignees.slice(skip, skip + limit);

    res.json({
      data: paginatedData,
      total,
      hasMore: (skip + paginatedData.length) < total,
      nextCursor: (skip + paginatedData.length) < total ? page + 1 : null
    });
  } catch (error) {
    console.error('Error fetching consignees:', error);
    res.status(500).json({ error: 'Failed to fetch consignees' });
  }
});

router.get('/search', async (req, res) => {
  try {
    const { branch = 'MAIN', q = '' } = req.query;
    if (!q || q.trim() === '') return res.json([]);
    const results = await prisma.consignee.findMany({
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
    const { name, branch = 'MAIN', stateCode, ...rest } = req.body;
    const consignee = await prisma.consignee.upsert({
      where: { name_branch: { name, branch } },
      update: { ...rest, branch, stateCode: stateCode || null },
      create: { name, branch, stateCode: stateCode || null, ...rest }
    });
    res.json(consignee);
  } catch (error) {
    console.error("Error creating consignee:", error);
    if (error.code === 'P2002') {
      return res.status(400).json({ error: 'A Consignee with this Name already exists in this branch.' });
    }
    res.status(500).json({ error: error.message || 'Failed to create consignee' });
  }
});

router.put('/:id', async (req, res) => {
  try {
    const consignee = await prisma.consignee.update({
      where: { id: parseInt(req.params.id) },
      data: {
        ...req.body,
        stateCode: req.body.stateCode !== undefined ? req.body.stateCode : undefined
      },
    });
    res.json(consignee);
  } catch (error) {
    console.error("Error updating consignee:", error);
    if (error.code === 'P2002') {
      return res.status(400).json({ error: 'A Consignee with this verified Name already exists in this branch. Please delete this duplicate old record and use the existing one.' });
    }
    res.status(500).json({ error: error.message || 'Failed to update consignee' });
  }
});

router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    await prisma.consignee.update({
      where: { id: parseInt(id) },
      data: { isActive: false }
    });
    res.json({ message: 'Consignee archived successfully' });
  } catch (error) {
    res.status(500).json({ error: 'Failed to archive consignee' });
  }
});

router.put('/:id/restore', async (req, res) => {
  try {
    const { id } = req.params;
    const consignee = await prisma.consignee.update({
      where: { id: parseInt(id) },
      data: { isActive: true }
    });
    res.json(consignee);
  } catch (error) {
    res.status(500).json({ error: 'Failed to restore consignee' });
  }
});

module.exports = router;
