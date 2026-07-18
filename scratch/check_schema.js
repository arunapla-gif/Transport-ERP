const { Client } = require('pg');

async function checkSchema() {
  const client = new Client({
    connectionString: 'postgresql://postgres.gqfpfnqepdkletbbhwcx:IevuJqEtZ8V1eKhz@aws-1-ap-south-1.pooler.supabase.com:5432/postgres'
  });

  try {
    await client.connect();
    
    // Check tables in 'crackers' schema
    const res1 = await client.query(`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'crackers';
    `);
    console.log('Tables in crackers schema:', res1.rows.map(r => r.table_name));

    // Check tables in 'public' schema
    const res2 = await client.query(`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public';
    `);
    console.log('Tables in public schema:', res2.rows.map(r => r.table_name));
    
  } catch (error) {
    console.error('Error:', error);
  } finally {
    await client.end();
  }
}

checkSchema();
