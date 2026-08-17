const express = require('express');
const router = express.Router();
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

router.get('/', async (req, res) => {
  try {
    const companies = await prisma.company.findMany({ orderBy: { id: 'desc' } });
    res.json(companies);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch companies' });
  }
});

router.post('/', async (req, res) => {
  try {
    const data = { ...req.body };
    delete data.id;
    const company = await prisma.company.create({ data });
    res.json(company);
  } catch (error) {
    console.error("Failed to create company:", error);
    if (error.code === 'P2002') return res.status(400).json({ error: 'GSTIN already exists' });
    res.status(500).json({ error: 'Failed to create company' });
  }
});

router.put('/:id', async (req, res) => {
  try {
    const data = { ...req.body };
    delete data.id;
    const company = await prisma.company.update({
      where: { id: parseInt(req.params.id) },
      data,
    });
    res.json(company);
  } catch (error) {
    console.error("Failed to update company:", error);
    if (error.code === 'P2002') return res.status(400).json({ error: 'GSTIN already exists' });
    res.status(500).json({ error: 'Failed to update company' });
  }
});

router.delete('/:id', async (req, res) => {
  try {
    await prisma.company.delete({ where: { id: parseInt(req.params.id) } });
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: 'Failed to delete company' });
  }
});

module.exports = router;
