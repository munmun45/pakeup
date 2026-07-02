/**
 * Reset DB to admin-only table.
 * Usage: node scripts/reset-admin-only.mjs
 */

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import dotenv from 'dotenv';
import pg from 'pg';

const rootDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
dotenv.config({ path: path.join(rootDir, 'pakeup_admin', '.env') });

const password = process.env.SUPABASE_DB_PASSWORD?.replace(/^"|"$/g, '');
const sql = fs.readFileSync(
  path.join(rootDir, 'supabase', 'migrations', '20260702100000_admin_only.sql'),
  'utf8',
);

const client = new pg.Client({
  host: 'db.qrcagdixpysgnvfuhfpa.supabase.co',
  port: 5432,
  user: 'postgres',
  password,
  database: 'postgres',
  ssl: { rejectUnauthorized: false },
});

await client.connect();
console.log('Dropping all tables and creating admin-only schema...');
await client.query(sql);

const tables = await client.query(`
  SELECT table_name FROM information_schema.tables
  WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
  ORDER BY table_name
`);

const admin = await client.query('SELECT id FROM admin');
console.log('\n✅ Done!');
console.log('Tables:', tables.rows.map((r) => r.table_name).join(', '));
console.log('Default login → id: admin | pass: admin123');
await client.end();
