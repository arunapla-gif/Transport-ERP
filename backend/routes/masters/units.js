const express = require('express');
const router = express.Router();
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const { cacheMiddleware } = require('../../middleware/cache');

router.get('/', cacheMiddleware(86400), async (req, res) => {
  try {
    const units = await prisma.unitMaster.findMany({ 
      orderBy: [
        { category: 'asc' },
        { id: 'asc' }
      ] 
    });
    res.json(units);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

router.post('/', async (req, res) => {
  try {
    const { category, description, code, color, hsn, goodsDesc } = req.body;
    const unit = await prisma.unitMaster.create({
      data: { category, description, code, color: color || 'slate', hsn, goodsDesc }
    });
    res.status(201).json(unit);
  } catch (error) {
    if (error.code === 'P2002') return res.status(400).json({ error: 'This unit combination already exists.' });
    res.status(400).json({ error: error.message });
  }
});

router.put('/:id', async (req, res) => {
  try {
    const { category, description, code, color, hsn, goodsDesc } = req.body;
    const unit = await prisma.unitMaster.update({
      where: { id: parseInt(req.params.id) },
      data: { category, description, code, color, hsn, goodsDesc }
    });
    res.json(unit);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

router.delete('/:id', async (req, res) => {
  try {
    await prisma.unitMaster.delete({ where: { id: parseInt(req.params.id) } });
    res.status(204).send();
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

module.exports = router;
