const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');
const rateLimit = require('express-rate-limit');
const bcrypt = require('bcryptjs');
const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();
const JWT_SECRET = process.env.JWT_SECRET || (process.env.NODE_ENV !== 'production' ? 'c7e954fa0f3a61c77843d1a3b83ef69b46e387c9d7495b5fa0b467ecbc337894' : null);
if (!JWT_SECRET) {
  console.error("FATAL ERROR: JWT_SECRET environment variable is strictly required.");
  process.exit(1);
}

const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20, // Strict brute-force protection for 4-digit PINs
  message: { error: "Too many login attempts. Please try again after 15 minutes." }
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
    
    if (!pin || typeof pin !== 'string' || pin.trim().length < 4 || pin.trim().length > 12) {
      return res.status(400).json({ error: 'Valid PIN code required' });
    }

    // Fallback/Bootstrap Admin PIN from .env (in case DB is locked out)
    const adminPin = process.env.OWNER_PIN;
    if (adminPin && pin === adminPin && (!userId || userId === 'admin')) {
      const token = jwt.sign({ role: 'admin', branch: 'ALL' }, JWT_SECRET, { expiresIn: '7d' });
      return res.json({ token, role: 'admin', branch: 'ALL', username: 'Super Admin' });
    }

    if (!userId) {
      return res.status(400).json({ error: 'User ID is required' });
    }

    const numericUserId = parseInt(userId, 10);
    if (isNaN(numericUserId) || numericUserId <= 0) {
      return res.status(400).json({ error: 'Invalid User ID format' });
    }

    const user = await prisma.user.findUnique({
      where: { id: numericUserId }
    });

    if (!user || user.status !== 'Active') {
      return res.status(401).json({ error: 'Invalid user or inactive account' });
    }

    // Support bcrypt with seamless auto-upgrade from legacy plaintext
    let isValid = false;
    const isBcrypt = user.pin && (user.pin.startsWith('$2a$') || user.pin.startsWith('$2b$'));
    if (isBcrypt) {
      isValid = bcrypt.compareSync(pin, user.pin);
    } else {
      // Legacy plaintext comparison
      isValid = (pin === user.pin);
      if (isValid) {
        // Transparently upgrade legacy plaintext PIN to bcrypt in background
        const hashedPin = bcrypt.hashSync(pin, 10);
        prisma.user.update({
          where: { id: user.id },
          data: { pin: hashedPin }
        }).catch(err => console.error('Failed to auto-upgrade user PIN to bcrypt:', err));
      }
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
