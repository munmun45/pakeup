import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import pg from 'pg';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const sqlPath = path.join(
  __dirname,
  '..',
  'migrations',
  '20260707130000_fix_inventory_rpc_ambiguity.sql',
);

const password = encodeURIComponent(process.env.SUPABASE_DB_PASSWORD ?? '');
const connectionString =
  process.env.DATABASE_URL ??
  `postgresql://postgres:${password}@db.qrcagdixpysgnvfuhfpa.supabase.co:5432/postgres`;

const sql = fs.readFileSync(sqlPath, 'utf8');
const client = new pg.Client({ connectionString, ssl: { rejectUnauthorized: false } });

try {
  await client.connect();
  await client.query(sql);
  console.log('Applied inventory RPC fix successfully.');
} catch (err) {
  console.error('Failed to apply fix:', err.message);
  process.exit(1);
} finally {
  await client.end();
}
