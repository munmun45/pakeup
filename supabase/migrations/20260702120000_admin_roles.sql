-- Add admin roles: super_admin and admin

DO $$ BEGIN
  CREATE TYPE admin_role AS ENUM ('super_admin', 'admin');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE admin
  ADD COLUMN IF NOT EXISTS role admin_role NOT NULL DEFAULT 'admin';

-- Super admin account
INSERT INTO admin (id, pass, role)
VALUES ('superadmin', 'admin123', 'super_admin')
ON CONFLICT (id) DO UPDATE
  SET pass = EXCLUDED.pass, role = EXCLUDED.role;

-- Regular admin account
INSERT INTO admin (id, pass, role)
VALUES ('admin', 'admin123', 'admin')
ON CONFLICT (id) DO UPDATE
  SET pass = EXCLUDED.pass, role = EXCLUDED.role;

-- Return id + role on login
DROP FUNCTION IF EXISTS verify_admin(TEXT, TEXT);

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
