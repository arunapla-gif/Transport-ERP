require('dotenv').config();
const { Client } = require('pg');

function cleanPgUrl(rawUrl) {
  if (!rawUrl) return '';
  try {
    const u = new URL(rawUrl);
    u.searchParams.delete('pgbouncer');
    u.searchParams.delete('connection_limit');
    u.searchParams.delete('pool_timeout');
    u.searchParams.delete('sslmode');
    u.searchParams.delete('schema');
    return u.toString();
  } catch (_) {
    return rawUrl;
  }
}

async function bootstrapRailwayDb() {
  const targetRaw = process.env.DATABASE_URL;
  const sourceRaw = process.env.LEGACY_SUPABASE_URL;

  if (!targetRaw) {
    console.log('[DB Bootstrap] No DATABASE_URL set; skipping.');
    return;
  }
  if (!sourceRaw || cleanPgUrl(sourceRaw) === cleanPgUrl(targetRaw)) {
    console.log('[DB Bootstrap] No separate LEGACY_SUPABASE_URL configured; skipping one-time data migration.');
    return;
  }

  const target = new Client({
    connectionString: cleanPgUrl(targetRaw),
    ssl: targetRaw.includes('localhost') || targetRaw.includes('127.0.0.1')
      ? false
      : { rejectUnauthorized: false },
  });

  try {
    await target.connect();

    // Check if Railway Postgres already has data
    const checkRes = await target.query('SELECT COUNT(*)::int AS cnt FROM "Consignor"');
    const existingCount = checkRes.rows[0]?.cnt ?? 0;
    if (existingCount > 0) {
      console.log(`[DB Bootstrap] Railway PostgreSQL already initialized (${existingCount} consignors). Skipping migration.`);
      return;
    }

    console.log('[DB Bootstrap] Empty Railway PostgreSQL detected! Starting one-time migration from Supabase...');

    const source = new Client({
      connectionString: cleanPgUrl(sourceRaw),
      ssl: { rejectUnauthorized: false },
    });
    await source.connect();

    try {
      // List public base tables in target
      const targetTablesRes = await target.query(`
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = 'public'
          AND table_type = 'BASE TABLE'
          AND table_name != '_prisma_migrations'
        ORDER BY table_name;
      `);
      const targetTables = targetTablesRes.rows.map((r) => r.table_name);

      const sourceTablesRes = await source.query(`
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = 'public'
          AND table_type = 'BASE TABLE';
      `);
      const sourceTableSet = new Set(sourceTablesRes.rows.map((r) => r.table_name));

      // Disable FK triggers during bulk copy so circular/parent-child tables insert cleanly
      await target.query("SET session_replication_role = 'replica';");

      for (const table of targetTables) {
        if (!sourceTableSet.has(table)) {
          console.log(`  - Skipping ${table} (not in source DB)`);
          continue;
        }

        // Inspect target columns and JSON/JSONB types
        const colRes = await target.query(
          `SELECT column_name, udt_name
           FROM information_schema.columns
           WHERE table_schema = 'public' AND table_name = $1`,
          [table]
        );
        const targetColTypes = new Map(colRes.rows.map((c) => [c.column_name, c.udt_name]));

        const rowsRes = await source.query(`SELECT * FROM "${table}"`);
        const rows = rowsRes.rows;
        if (rows.length === 0) {
          console.log(`  - ${table}: 0 rows`);
          continue;
        }

        // Only copy columns that exist in both source and target
        const columns = Object.keys(rows[0]).filter((c) => targetColTypes.has(c));
        const quotedCols = columns.map((c) => `"${c}"`).join(', ');

        const batchSize = 200;
        for (let i = 0; i < rows.length; i += batchSize) {
          const batch = rows.slice(i, i + batchSize);
          const values = [];
          const rowPlaceholders = [];
          let paramIdx = 1;

          for (const row of batch) {
            const ph = [];
            for (const col of columns) {
              let val = row[col];
              const udt = targetColTypes.get(col);
              if (val !== null && val !== undefined && (udt === 'jsonb' || udt === 'json')) {
                val = typeof val === 'string' ? val : JSON.stringify(val);
                ph.push(`$${paramIdx++}::${udt}`);
              } else {
                ph.push(`$${paramIdx++}`);
              }
              values.push(val);
            }
            rowPlaceholders.push(`(${ph.join(', ')})`);
          }

          await target.query(
            `INSERT INTO "${table}" (${quotedCols}) VALUES ${rowPlaceholders.join(', ')} ON CONFLICT DO NOTHING`,
            values
          );
        }

        // Reset SERIAL / sequence on 'id' (or 'receiptNo') if present
        for (const seqCol of ['id', 'receiptNo']) {
          if (targetColTypes.has(seqCol)) {
            const seqRes = await target.query(
              `SELECT pg_get_serial_sequence($1, $2) AS seq`,
              [`"${table}"`, seqCol]
            );
            const seqName = seqRes.rows[0]?.seq;
            if (seqName) {
              await target.query(
                `SELECT setval($1, COALESCE((SELECT MAX("${seqCol}") FROM "${table}"), 1), (SELECT COUNT(*) > 0 FROM "${table}"))`,
                [seqName]
              );
            }
          }
        }

        console.log(`  - ${table}: migrated ${rows.length} rows`);
      }

      await target.query("SET session_replication_role = 'origin';");
      console.log('[DB Bootstrap] ✅ One-time migration from Supabase to Railway PostgreSQL complete!');
    } finally {
      await source.end().catch(() => {});
    }
  } catch (err) {
    console.error('[DB Bootstrap] Migration warning/error (non-fatal, server will continue):', err.message);
  } finally {
    await target.end().catch(() => {});
  }
}

bootstrapRailwayDb();
