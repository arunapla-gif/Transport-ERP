const { PrismaClient } = require('@prisma/client');

const neonUrl = 'postgresql://neondb_owner:npg_8XNhi2mROYlf@ep-withered-resonance-ao3somz9.c-2.ap-southeast-1.aws.neon.tech/neondb?sslmode=require&connect_timeout=30&pool_timeout=60&connection_limit=5';
const supabaseUrl = 'postgresql://postgres.gqfpfnqepdkletbbhwcx:IevuJqEtZ8V1eKhz@aws-1-ap-south-1.pooler.supabase.com:6543/postgres?pgbouncer=true';

async function migrateData() {
  const neon = new PrismaClient({ datasources: { db: { url: neonUrl } } });
  const supabase = new PrismaClient({ datasources: { db: { url: supabaseUrl } } });

  try {
    console.log("Connecting to databases...");
    await neon.$connect();
    await supabase.$connect();

    // Disable Foreign Key checks on Supabase
    console.log("Disabling foreign key constraints on Supabase...");
    await supabase.$executeRawUnsafe("SET session_replication_role = 'replica';");

    // Get all tables in Neon 'public' schema
    const tablesRes = await neon.$queryRawUnsafe(`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public' 
      AND table_type = 'BASE TABLE'
      AND table_name != '_prisma_migrations';
    `);
    
    const tables = tablesRes.map(r => r.table_name);
    console.log(`Found ${tables.length} tables to migrate.`);

    // TRUNCATE ALL TABLES FIRST to prevent cascading deletes from wiping out inserts
    for (const table of tables) {
      await supabase.$executeRawUnsafe(`TRUNCATE TABLE "${table}" CASCADE`);
    }

    for (const table of tables) {
      console.log(`Migrating table: ${table}...`);
      
      const rows = await neon.$queryRawUnsafe(`SELECT * FROM "${table}"`);
      if (rows.length === 0) {
        console.log(`  - 0 rows, skipping.`);
        continue;
      }

      const columns = Object.keys(rows[0]);
      
      // Insert in batches of 500
      const batchSize = 500;
      for (let i = 0; i < rows.length; i += batchSize) {
        const batch = rows.slice(i, i + batchSize);
        
        let valuesStr = [];
        let flatValues = [];
        let valIndex = 1;
        
        for (const row of batch) {
          const rowPlaceholders = [];
          for (const col of columns) {
            let val = row[col];
            if (val !== null && typeof val === 'object' && !(val instanceof Date)) {
              rowPlaceholders.push(`$${valIndex++}::jsonb`);
              flatValues.push(JSON.stringify(val));
            } else {
              rowPlaceholders.push(`$${valIndex++}`);
              flatValues.push(val);
            }
          }
          valuesStr.push(`(${rowPlaceholders.join(', ')})`);
        }
        
        const insertQuery = `
          INSERT INTO "${table}" ("${columns.join('", "')}")
          VALUES ${valuesStr.join(', ')}
        `;
        
        // Prisma requires parameters to be passed dynamically to executeRawUnsafe, but wait!
        // Prisma $executeRawUnsafe doesn't take an array of bindings easily like pg does.
        // It's safer to use $executeRaw with Prisma.sql, or we can just construct a literal query since we trust the data.
        // Actually, $executeRawUnsafe(query, ...values) works in Prisma!
        await supabase.$executeRawUnsafe(insertQuery, ...flatValues);
      }
      console.log(`  - Migrated ${rows.length} rows.`);
    }

    // Re-enable Foreign Key checks
    console.log("Re-enabling foreign key constraints...");
    await supabase.$executeRawUnsafe("SET session_replication_role = 'origin';");

    console.log("MIGRATION COMPLETE!");

  } catch (err) {
    console.error("Migration failed:", err);
  } finally {
    await neon.$disconnect();
    await supabase.$disconnect();
  }
}

migrateData();
