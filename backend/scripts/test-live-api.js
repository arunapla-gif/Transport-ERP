const jwt = require('jsonwebtoken');

const JWT_SECRET = 'super-secret-key-change-me'; // Since process.env.JWT_SECRET is not in .env, it defaults to this.
const token = jwt.sign({ role: 'admin', branch: 'ALL' }, JWT_SECRET, { expiresIn: '7d' });

console.log("Generated Token:", token);

async function test() {
  try {
    const res = await fetch('https://transport-erp-production.up.railway.app/api/gdms/AP-1001', {
      headers: {
        'Authorization': `Bearer ${token}`,
        'x-branch-id': 'MAIN'
      }
    });
    const data = await res.text();
    console.log("Status:", res.status);
    console.log("Response:", data);
  } catch(e) {
    console.error(e);
  }
}

test();
