const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');
const rateLimit = require('express-rate-limit');
const bcrypt = require('bcryptjs');
const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();
const JWT_SECRET = process.env.JWT_SECRET || (process.env.NODE_ENV !== 'production' ? 'super-secret-key-change-me' : null);

const loginLimiter = rateLimit({
  windowMs: 10 * 60 * 1000,
  max: 5,
  message: { error: "Too many login attempts, please try again after 10 minutes." }
});

// Fetch active users for the login screen selection (Safe, no passwords exposed)
router.get('/public/users', async (req, res) => {
  try {
    const users = await prisma.user.findMany({
      where: { status: 'Active' },
      select: { id: true, username: true, role: true, branch: true }
    });
    res.json(users);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch users' });
  }
});

router.post('/login', loginLimiter, async (req, res) => {
  try {
    const { userId, pin } = req.body;
    
    // Fallback/Bootstrap Admin PIN from .env (in case DB is locked out)
    const adminPin = process.env.OWNER_PIN;
    if (adminPin && pin === adminPin && (!userId || userId === 'admin')) {
      const token = jwt.sign({ role: 'admin', branch: 'ALL' }, JWT_SECRET, { expiresIn: '7d' });
      return res.json({ token, role: 'admin', branch: 'ALL', username: 'Super Admin' });
    }

    if (!userId) {
      return res.status(400).json({ error: 'User ID is required' });
    }

    const user = await prisma.user.findUnique({
      where: { id: parseInt(userId, 10) }
    });

    if (!user || user.status !== 'Active') {
      return res.status(401).json({ error: 'Invalid user or inactive account' });
    }

    // Support both plaintext (legacy) and bcrypt for migration transition
    let isValid = false;
    if (user.pin.startsWith('$2a$') || user.pin.startsWith('$2b$')) {
      isValid = bcrypt.compareSync(pin, user.pin);
    } else {
      // Legacy plaintext comparison
      isValid = (pin === user.pin);
    }

    if (!isValid) {
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
