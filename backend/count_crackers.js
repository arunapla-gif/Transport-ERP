const { Client } = require('pg');

async function countData() {
  const client = new Client({
    connectionString: 'postgresql://postgres.gqfpfnqepdkletbbhwcx:IevuJqEtZ8V1eKhz@aws-1-ap-south-1.pooler.supabase.com:5432/postgres'
  });

  try {
    await client.connect();
    
    // Check tables in 'crackers' schema
    const res1 = await client.query('SELECT count(*) FROM crackers."User"');
    console.log('Crackers Users:', res1.rows[0].count);

    const res2 = await client.query('SELECT count(*) FROM crackers."Product"');
    console.log('Crackers Products:', res2.rows[0].count);
    
    const res3 = await client.query('SELECT count(*) FROM crackers."Employee"');
    console.log('Crackers Employees:', res3.rows[0].count);

  } catch (error) {
    console.error('Error:', error);
  } finally {
    await client.end();
  }
}

countData();
