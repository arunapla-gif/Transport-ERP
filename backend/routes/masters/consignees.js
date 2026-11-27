const express = require('express');
const router = express.Router();
const prisma = require('../../db');
const { cacheMiddleware } = require('../../middleware/cache');

router.get('/', cacheMiddleware(3600), async (req, res) => {
  try {
    const branch = req.query.branch || 'MAIN';
    const page = req.query.page ? parseInt(req.query.page, 10) : null;
    const limit = req.query.limit ? parseInt(req.query.limit, 10) : 50;
    const q = req.query.q ? req.query.q.trim() : '';

    const branchCondition = (branch && branch !== 'ALL') ? {
      OR: [
        { branch: branch },
        { branch: 'ALL' },
        { branch: null }
      ]
    } : {};

    const searchCondition = q ? {
      OR: [
        { name: { contains: q, mode: 'insensitive' } },
        { legalName: { contains: q, mode: 'insensitive' } },
        { city: { contains: q, mode: 'insensitive' } },
        { gstin: { contains: q, mode: 'insensitive' } },
        { phone: { contains: q, mode: 'insensitive' } }
      ]
    } : {};

    const where = (branchCondition.OR && searchCondition.OR)
      ? { AND: [branchCondition, searchCondition] }
      : (branchCondition.OR ? branchCondition : searchCondition);

    if (!page) {
      const consignees = await prisma.consignee.findMany({
        where,
        orderBy: { id: 'desc' },
        ...(req.query.limit ? { take: limit } : {})
      });
      return res.json(consignees);
    }

    const skip = (page - 1) * limit;
    const [paginatedData, total] = await Promise.all([
      prisma.consignee.findMany({
        where,
        orderBy: { id: 'desc' },
        skip,
        take: limit
      }),
      prisma.consignee.count({ where })
    ]);

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

router.get('/duplicates', async (req, res) => {
  try {
    const rows = await prisma.consignee.findMany({
      select: {
        id: true,
        name: true,
        gstin: true,
        branch: true,
        city: true,
        isActive: true,
        migrationType: true,
        _count: { select: { gcs: true } }
      },
      orderBy: { id: 'asc' }
    });

    const byName = new Map();
    const byGstin = new Map();
    for (const r of rows) {
      const normKey = (r.name || '').trim().toUpperCase().replace(/[^A-Z0-9]/g, '');
      const gstinKey = (r.gstin || '').trim().toUpperCase();
      const item = {
        id: r.id,
        name: r.name,
        gstin: r.gstin || '',
        branch: r.branch || 'MAIN',
        city: r.city || '',
        isActive: r.isActive !== false,
        migrationType: r.migrationType || 'MANUAL',
        gcCount: r._count?.gcs || 0
      };
      if (normKey) {
        if (!byName.has(normKey)) byName.set(normKey, []);
        byName.get(normKey).push(item);
      }
      if (gstinKey.length >= 10) {
        if (!byGstin.has(gstinKey)) byGstin.set(gstinKey, []);
        byGstin.get(gstinKey).push(item);
      }
    }

    const dupGstin = [...byGstin.entries()]
      .filter(([, list]) => list.length > 1)
      .map(([key, items]) => ({ key, items }));
    const dupName = [...byName.entries()]
      .filter(([, list]) => list.length > 1)
      .map(([key, items]) => ({ key, items }));

    res.json({
      total: rows.length,
      activeCount: rows.filter(r => r.isActive !== false).length,
      dupGstinCount: dupGstin.length,
      dupNameCount: dupName.length,
      dupGstin,
      dupName
    });
  } catch (error) {
    console.error('Error checking duplicate consignees:', error);
    res.status(500).json({ error: 'Failed to check duplicate consignees' });
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
