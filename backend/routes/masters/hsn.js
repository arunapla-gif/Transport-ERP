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

module.exports = router;
