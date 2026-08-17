const express = require('express');
const router = express.Router();
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const { cacheMiddleware } = require('../../middleware/cache');

router.get('/', cacheMiddleware(86400), async (req, res) => {
  try {
    const godowns = await prisma.godown.findMany({ orderBy: { id: 'desc' } });
    res.json(godowns);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch godowns' });
  }
});

router.post('/', async (req, res) => {
  try {
    const { name } = req.body;
    const godown = await prisma.godown.create({ data: { name } });
    res.json(godown);
  } catch (error) {
    if (error.code === 'P2002') return res.status(400).json({ error: 'Godown name already exists' });
    res.status(500).json({ error: 'Failed to create godown' });
  }
});

router.put('/:id', async (req, res) => {
  try {
    const { name } = req.body;
    const godown = await prisma.godown.update({
      where: { id: parseInt(req.params.id) },
      data: { name },
    });
    res.json(godown);
  } catch (error) {
    if (error.code === 'P2002') return res.status(400).json({ error: 'Godown name already exists' });
    res.status(500).json({ error: 'Failed to update godown' });
  }
});

router.delete('/:id', async (req, res) => {
  try {
    await prisma.godown.delete({ where: { id: parseInt(req.params.id) } });
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: 'Failed to delete godown' });
  }
});

module.exports = router;
