-- PakeUp: Simple admin-only schema
-- Drops all public tables/types and creates one admin table.

DROP EXTENSION IF EXISTS postgis CASCADE;

DO $$ DECLARE r RECORD;
BEGIN
  FOR r IN (
    SELECT tablename FROM pg_tables
    WHERE schemaname = 'public'
      AND tablename NOT IN ('spatial_ref_sys')
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
    SELECT p.oid::regprocedure::text AS signature
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
  ) LOOP
    EXECUTE 'DROP FUNCTION IF EXISTS ' || r.signature || ' CASCADE';
  END LOOP;

  DROP SEQUENCE IF EXISTS booking_number_seq CASCADE;
END $$;

-- Admin table (id + pass + role)
CREATE TYPE admin_role AS ENUM ('super_admin', 'admin');

CREATE TABLE admin (
  id   TEXT PRIMARY KEY,
  pass TEXT NOT NULL,
  role admin_role NOT NULL DEFAULT 'admin'
);

-- Default logins
INSERT INTO admin (id, pass, role) VALUES
  ('superadmin', 'admin123', 'super_admin'),
  ('admin', 'admin123', 'admin');

-- Secure login check (returns id + role)
CREATE OR REPLACE FUNCTION verify_admin(login_id TEXT, login_pass TEXT)
RETURNS JSON
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT json_build_object(
    'id', id,
    'role', role::text
  )
  FROM admin
  WHERE id = login_id AND pass = login_pass
  LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION verify_admin(TEXT, TEXT) TO anon, authenticated, service_role;

-- Block direct reads from client apps
ALTER TABLE admin ENABLE ROW LEVEL SECURITY;
