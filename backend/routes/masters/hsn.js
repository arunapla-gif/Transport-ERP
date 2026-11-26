const express = require('express');
const router = express.Router();
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

router.get('/', async (req, res) => {
  try {
    const query = req.query.q;
    if (query) {
      const hsn = await prisma.hSNMaster.findFirst({
        where: { hsnCode: query }
      });
      return res.json(hsn || { error: 'Not found' });
    }
    const hsnList = await prisma.hSNMaster.findMany({ orderBy: { hsnCode: 'asc' } });
    res.json(hsnList);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

router.post('/', async (req, res) => {
  try {
    const { hsnCode, description, gstRate } = req.body;
    const hsn = await prisma.hSNMaster.upsert({
      where: { hsnCode },
      update: { description, gstRate: parseFloat(gstRate) },
      create: { hsnCode, description, gstRate: parseFloat(gstRate) }
    });
    res.status(201).json(hsn);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

router.put('/:id', async (req, res) => {
  try {
    const { hsnCode, description, gstRate } = req.body;
    const hsn = await prisma.hSNMaster.update({
      where: { id: parseInt(req.params.id) },
      data: {
        hsnCode,
        description,
        gstRate: parseFloat(gstRate),
      },
    });
    res.json(hsn);
  } catch (error) {
    if (error.code === 'P2002') {
      return res.status(400).json({ error: 'HSN Code already exists' });
    }
    res.status(400).json({ error: error.message });
  }
});

router.delete('/:id', async (req, res) => {
  try {
    await prisma.hSNMaster.delete({
      where: { id: parseInt(req.params.id) },
    });
    res.json({ success: true });
  } catch (error) {
    res.status(400).json({ error: error.message || 'Failed to delete HSN' });
  }
});

module.exports = router;
