/**
 * Reset partial schema and run full PakeUp setup.
 * Usage: node scripts/setup-database-fresh.mjs
 */

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import dotenv from 'dotenv';
import pg from 'pg';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(__dirname, '..');

dotenv.config({ path: path.join(rootDir, 'pakeup_admin', '.env') });

const password = process.env.SUPABASE_DB_PASSWORD?.replace(/^"|"$/g, '');
if (!password) {
  console.error('Missing SUPABASE_DB_PASSWORD in pakeup_admin/.env');
  process.exit(1);
}

const client = new pg.Client({
  host: 'db.qrcagdixpysgnvfuhfpa.supabase.co',
  port: 5432,
  user: 'postgres',
  password,
  database: 'postgres',
  ssl: { rejectUnauthorized: false },
});

const migrationPath = path.join(
  rootDir,
  'supabase',
  'migrations',
  '20260702000001_initial_schema.sql',
);
const seedPath = path.join(rootDir, 'supabase', 'seed.sql');
const sql = [
  fs.readFileSync(migrationPath, 'utf8'),
  fs.readFileSync(seedPath, 'utf8'),
].join('\n\n');

const cleanupSql = `
DO $$ DECLARE r RECORD;
BEGIN
  FOR r IN (
    SELECT tablename FROM pg_tables WHERE schemaname = 'public'
  ) LOOP
    EXECUTE 'DROP TABLE IF EXISTS public.' || quote_ident(r.tablename) || ' CASCADE';
  END LOOP;

  FOR r IN (
    SELECT typname FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'public' AND t.typtype = 'e'
  ) LOOP
    EXECUTE 'DROP TYPE IF EXISTS public.' || quote_ident(r.typname) || ' CASCADE';
  END LOOP;

  FOR r IN (
    SELECT proname, oidvectortypes(proargtypes) AS args
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND proname IN ('handle_new_user', 'set_updated_at', 'generate_booking_number', 'is_admin')
  ) LOOP
    EXECUTE 'DROP FUNCTION IF EXISTS public.' || quote_ident(r.proname) || '(' || r.args || ') CASCADE';
  END LOOP;

  DROP SEQUENCE IF EXISTS booking_number_seq CASCADE;
END $$;
`;

async function main() {
  await client.connect();
  console.log('Connected to Supabase PostgreSQL.');

  console.log('Cleaning partial schema (enums/functions without tables)...');
  await client.query(cleanupSql);

  console.log('Creating all tables, policies, and seed data...');
  await client.query(sql);

  const tables = await client.query(`
    SELECT COUNT(*)::int AS count FROM information_schema.tables
    WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
  `);

  console.log(`\n✅ Done! ${tables.rows[0].count} tables created.`);
  console.log(`
Next:
  1. Supabase → Authentication → Add user (admin@pakeup.com)
  2. SQL Editor:

     UPDATE profiles
     SET role = 'admin', full_name = 'Super Admin'
     WHERE id = (SELECT id FROM auth.users WHERE email = 'admin@pakeup.com');
`);

  await client.end();
}

main().catch((e) => {
  console.error('❌ Error:', e.message);
  process.exit(1);
});
