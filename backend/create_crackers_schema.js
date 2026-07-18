const { Client } = require('pg');

async function createSchema() {
  const client = new Client({
    connectionString: 'postgresql://postgres.gqfpfnqepdkletbbhwcx:IevuJqEtZ8V1eKhz@aws-1-ap-south-1.pooler.supabase.com:5432/postgres'
  });

  try {
    await client.connect();
    console.log('Connected to database.');
    await client.query('CREATE SCHEMA IF NOT EXISTS crackers;');
    console.log('Successfully created schema "crackers".');
  } catch (error) {
    console.error('Error creating schema:', error);
  } finally {
    await client.end();
  }
}

createSchema();
