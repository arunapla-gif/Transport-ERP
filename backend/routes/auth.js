const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');
const rateLimit = require('express-rate-limit');
const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();
const JWT_SECRET = process.env.JWT_SECRET || 'super-secret-key-change-me';

const loginLimiter = rateLimit({
  windowMs: 10 * 60 * 1000,
  max: 5,
  message: { error: "Too many login attempts, please try again after 10 minutes." }
});

router.post('/login', loginLimiter, async (req, res) => {
  try {
    const { pin } = req.body;
    
    // Fallback/Bootstrap Admin PIN from .env (in case DB is locked out)
    const adminPin = process.env.OWNER_PIN;
    if (adminPin && pin === adminPin) {
      const token = jwt.sign({ role: 'admin', branch: 'ALL' }, JWT_SECRET, { expiresIn: '7d' });
      return res.json({ token, role: 'admin', branch: 'ALL', username: 'Super Admin' });
    }

    const user = await prisma.user.findFirst({
      where: { pin, status: 'Active' }
    });

    if (!user) {
      return res.status(401).json({ error: 'Invalid PIN code' });
    }

    const token = jwt.sign({ userId: user.id, role: user.role, branch: user.branch }, JWT_SECRET, { expiresIn: '7d' });
    
    // Create Session
    await prisma.session.create({
      data: {
        userId: user.id,
        token: token
      }
    });

    return res.json({ token, role: user.role, branch: user.branch, username: user.username, permissions: user.permissions });
  } catch (err) {
    console.error("Login error:", err);
    res.status(500).json({ error: 'Internal server error during login' });
  }
});

module.exports = router;
