const fs = require('fs');
const { Client } = require('pg');

async function main() {
  const c = new Client({
    host: 'db.qrcagdixpysgnvfuhfpa.supabase.co',
    port: 5432,
    user: 'postgres',
    password: '5SC6F?MaS46k4P#',
    database: 'postgres',
    ssl: { rejectUnauthorized: false },
  });
  await c.connect();
  const sql = fs.readFileSync(
    '../supabase/migrations/20260708251000_drop_old_update_partner_overloads.sql',
    'utf8',
  );
  await c.query(sql);
  const r = await c.query(
    "SELECT pg_get_function_identity_arguments(oid) AS a FROM pg_proc WHERE proname = 'update_partner'",
  );
  console.log('update_partner overloads:', r.rows);
  await c.end();
}

main().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
