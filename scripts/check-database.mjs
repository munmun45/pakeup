import path from 'node:path';
import { fileURLToPath } from 'node:url';
import dotenv from 'dotenv';
import pg from 'pg';

const rootDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
dotenv.config({ path: path.join(rootDir, 'pakeup_admin', '.env') });

const client = new pg.Client({
  host: 'db.qrcagdixpysgnvfuhfpa.supabase.co',
  port: 5432,
  user: 'postgres',
  password: process.env.SUPABASE_DB_PASSWORD?.replace(/^"|"$/g, ''),
  database: 'postgres',
  ssl: { rejectUnauthorized: false },
});

await client.connect();

const tables = await client.query(`
  SELECT table_name FROM information_schema.tables
  WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
  ORDER BY table_name
`);

const types = await client.query(`
  SELECT typname FROM pg_type t
  JOIN pg_namespace n ON n.oid = t.typnamespace
  WHERE n.nspname = 'public' AND t.typtype = 'e'
  ORDER BY typname
`);

console.log('ENUMS:', types.rows.map((r) => r.typname).join(', ') || '(none)');
console.log('TABLES:', tables.rows.map((r) => r.table_name).join(', ') || '(none)');
console.log('COUNT tables:', tables.rows.length);

await client.end();
