const { Client } = require('pg');

async function testConnection(url, name) {
  const client = new Client({ connectionString: url });
  try {
    await client.connect();
    console.log(`[SUCCESS] ${name} connected!`);
    await client.end();
    return true;
  } catch (e) {
    console.error(`[FAILED] ${name}:`, e.message);
    return false;
  }
}

async function run() {
  const pass = 'IevuJqEtZ8V1eKhz';
  const ref = 'gqfpfnqepdkletbbhwcx';
  
  // 1. Try pooler on main domain
  await testConnection(`postgresql://postgres.${ref}:${pass}@aws-0-ap-south-1.pooler.supabase.com:6543/postgres?pgbouncer=true`, "Mumbai Pooler");
  await testConnection(`postgresql://postgres.${ref}:${pass}@aws-0-ap-southeast-1.pooler.supabase.com:6543/postgres?pgbouncer=true`, "Singapore Pooler");
  
  // 2. Try Supabase new pooler proxy on main domain
  await testConnection(`postgresql://postgres.${ref}:${pass}@db.${ref}.supabase.co:6543/postgres`, "Main Domain Port 6543 UserRef");
  await testConnection(`postgresql://postgres:${pass}@db.${ref}.supabase.co:6543/postgres`, "Main Domain Port 6543 PlainUser");
  
  // 3. Try standard port with direct IPV6 resolution (if possible)
}

run();
