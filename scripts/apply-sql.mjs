/**
 * Apply a SQL migration file to Supabase.
 * Usage: node scripts/apply-sql.mjs supabase/migrations/20260702120000_admin_roles.sql
 */

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import dotenv from 'dotenv';
import pg from 'pg';

const rootDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
dotenv.config({ path: path.join(rootDir, 'pakeup_admin', '.env') });

const file = process.argv[2];
if (!file) {
  console.error('Usage: node scripts/apply-sql.mjs <sql-file>');
  process.exit(1);
}

const password = process.env.SUPABASE_DB_PASSWORD?.replace(/^"|"$/g, '');
const sql = fs.readFileSync(path.join(rootDir, file), 'utf8');

const client = new pg.Client({
  host: 'db.qrcagdixpysgnvfuhfpa.supabase.co',
  port: 5432,
  user: 'postgres',
  password,
  database: 'postgres',
  ssl: { rejectUnauthorized: false },
});

await client.connect();
console.log(`Applying ${file}...`);
await client.query(sql);

const rows = await client.query('SELECT id, role FROM admin ORDER BY id');
console.log('\n✅ Admin accounts:');
for (const row of rows.rows) {
  console.log(`  - ${row.id} (${row.role})`);
}

await client.end();
