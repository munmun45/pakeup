/**
 * Push PakeUp schema + seed to Supabase cloud.
 *
 * 1. Supabase Dashboard → Project Settings → Database → copy Database password
 * 2. Add to pakeup_admin/.env:
 *      SUPABASE_DB_PASSWORD=your-database-password
 * 3. Run: node scripts/setup-database.mjs
 */

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import dotenv from 'dotenv';
import pg from 'pg';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(__dirname, '..');

dotenv.config({ path: path.join(rootDir, 'pakeup_admin', '.env') });

const PROJECT_REF = 'qrcagdixpysgnvfuhfpa';
const REGION = 'ap-southeast-2';

const password = process.env.SUPABASE_DB_PASSWORD;
if (!password || password.includes('paste-your')) {
  console.error(`
❌ Missing SUPABASE_DB_PASSWORD in pakeup_admin/.env

Get it from:
  Supabase Dashboard → Project Settings → Database → Database password

Then add to pakeup_admin/.env:
  SUPABASE_DB_PASSWORD=your-password-here

Or paste supabase/setup_all.sql in SQL Editor (no password needed).
`);
  process.exit(1);
}

const hosts = [
  `aws-0-${REGION}.pooler.supabase.com`,
  `db.${PROJECT_REF}.supabase.co`,
];

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

async function tryConnect(host, port, user) {
  const client = new pg.Client({
    host,
    port,
    user,
    password,
    database: 'postgres',
    ssl: { rejectUnauthorized: false },
    connectionTimeoutMillis: 15000,
  });
  await client.connect();
  return client;
}

async function main() {
  console.log('Connecting to Supabase PostgreSQL...');

  let client;
  const attempts = [
    { host: hosts[0], port: 6543, user: `postgres.${PROJECT_REF}` },
    { host: hosts[0], port: 5432, user: `postgres.${PROJECT_REF}` },
    { host: hosts[1], port: 5432, user: 'postgres' },
  ];

  for (const attempt of attempts) {
    try {
      console.log(`  Trying ${attempt.user}@${attempt.host}:${attempt.port}`);
      client = await tryConnect(attempt.host, attempt.port, attempt.user);
      console.log('  Connected.');
      break;
    } catch (e) {
      console.log(`  Failed: ${e.message}`);
    }
  }

  if (!client) {
    console.error('\n❌ Could not connect. Check your database password.');
    process.exit(1);
  }

  try {
    console.log('\nCreating tables, enums, RLS policies, and seed data...');
    await client.query(sql);
    console.log('\n✅ Database setup complete!');
    console.log(`
Next steps:
  1. Supabase → Authentication → Add user (admin@pakeup.com)
  2. Run in SQL Editor:

     UPDATE profiles
     SET role = 'admin', full_name = 'Super Admin'
     WHERE id = (SELECT id FROM auth.users WHERE email = 'admin@pakeup.com');

  3. flutter run -d windows  (in pakeup_admin)
`);
  } catch (e) {
    console.error('\n❌ SQL error:', e.message);
    if (e.message.includes('already exists')) {
      console.log('\nSome objects already exist. Tables may be partially created.');
      console.log('Use SQL Editor to drop schema public cascade and retry, or run setup_all.sql manually.');
    }
    process.exit(1);
  } finally {
    await client.end();
  }
}

main();
