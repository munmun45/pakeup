-- Admin page access control

CREATE TABLE IF NOT EXISTS admin_pages (
  page_key   TEXT PRIMARY KEY,
  label      TEXT NOT NULL,
  sort_order INT NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS admin_page_access (
  admin_id  TEXT NOT NULL REFERENCES admin(id) ON DELETE CASCADE,
  page_key  TEXT NOT NULL REFERENCES admin_pages(page_key) ON DELETE CASCADE,
  PRIMARY KEY (admin_id, page_key)
);

INSERT INTO admin_pages (page_key, label, sort_order) VALUES
  ('dashboard', 'Dashboard', 1),
  ('users', 'Users', 2),
  ('salons', 'Salons', 3),
  ('bookings', 'Bookings', 4),
  ('payments', 'Payments', 5),
  ('commissions', 'Commissions', 6),
  ('coupons', 'Coupons', 7),
  ('ai_monitor', 'AI Monitor', 8),
  ('ads', 'Ads', 9),
  ('affiliates', 'Affiliates', 10),
  ('moderation', 'Moderation', 11),
  ('reports', 'Reports', 12),
  ('notifications', 'Notifications', 13),
  ('settings', 'Settings', 14),
  ('manage_admins', 'Manage Admins', 15)
ON CONFLICT (page_key) DO NOTHING;

-- Default access for existing admin user
INSERT INTO admin_page_access (admin_id, page_key)
SELECT 'admin', page_key FROM admin_pages
WHERE page_key IN ('dashboard', 'users', 'salons', 'bookings')
ON CONFLICT DO NOTHING;

-- Login: return id, role, and allowed pages
CREATE OR REPLACE FUNCTION verify_admin(login_id TEXT, login_pass TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  admin_row admin%ROWTYPE;
  pages JSON;
BEGIN
  SELECT * INTO admin_row
  FROM admin
  WHERE id = login_id AND pass = login_pass;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  IF admin_row.role = 'super_admin' THEN
    SELECT COALESCE(json_agg(page_key ORDER BY sort_order), '[]'::json)
    INTO pages
    FROM admin_pages;
  ELSE
    SELECT COALESCE(json_agg(a.page_key ORDER BY p.sort_order), '[]'::json)
    INTO pages
    FROM admin_page_access a
    JOIN admin_pages p ON p.page_key = a.page_key
    WHERE a.admin_id = admin_row.id;
  END IF;

  RETURN json_build_object(
    'id', admin_row.id,
    'role', admin_row.role::text,
    'pages', pages
  );
END;
$$;

-- List all admins with their page access (super admin only)
CREATE OR REPLACE FUNCTION list_admin_users(caller_id TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM admin WHERE id = caller_id AND role = 'super_admin'
  ) THEN
    RAISE EXCEPTION 'Only Super Admin can view admin users';
  END IF;

  RETURN (
    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json)
    FROM (
      SELECT
        a.id,
        a.role::text AS role,
        COALESCE(
          (
            SELECT json_agg(ap.page_key ORDER BY p.sort_order)
            FROM admin_page_access ap
            JOIN admin_pages p ON p.page_key = ap.page_key
            WHERE ap.admin_id = a.id
          ),
          '[]'::json
        ) AS pages
      FROM admin a
      ORDER BY a.role DESC, a.id
    ) t
  );
END;
$$;

-- Create admin with page access (super admin only)
CREATE OR REPLACE FUNCTION create_admin_user(
  caller_id TEXT,
  new_id TEXT,
  new_pass TEXT,
  page_keys TEXT[]
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM admin WHERE id = caller_id AND role = 'super_admin'
  ) THEN
    RAISE EXCEPTION 'Only Super Admin can create admins';
  END IF;

  IF new_id IS NULL OR trim(new_id) = '' THEN
    RAISE EXCEPTION 'Admin ID is required';
  END IF;

  IF new_pass IS NULL OR length(new_pass) < 4 THEN
    RAISE EXCEPTION 'Password must be at least 4 characters';
  END IF;

  IF EXISTS (SELECT 1 FROM admin WHERE id = new_id) THEN
    RAISE EXCEPTION 'Admin ID already exists';
  END IF;

  INSERT INTO admin (id, pass, role) VALUES (new_id, new_pass, 'admin');

  INSERT INTO admin_page_access (admin_id, page_key)
  SELECT new_id, pk
  FROM unnest(page_keys) AS pk
  WHERE pk IN (SELECT page_key FROM admin_pages WHERE page_key != 'manage_admins');

  RETURN json_build_object('id', new_id, 'role', 'admin');
END;
$$;

-- Update page access for an admin (super admin only)
CREATE OR REPLACE FUNCTION update_admin_access(
  caller_id TEXT,
  target_id TEXT,
  page_keys TEXT[]
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM admin WHERE id = caller_id AND role = 'super_admin'
  ) THEN
    RAISE EXCEPTION 'Only Super Admin can update access';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM admin WHERE id = target_id AND role = 'admin') THEN
    RAISE EXCEPTION 'Can only update regular admin accounts';
  END IF;

  DELETE FROM admin_page_access WHERE admin_id = target_id;

  INSERT INTO admin_page_access (admin_id, page_key)
  SELECT target_id, pk
  FROM unnest(page_keys) AS pk
  WHERE pk IN (SELECT page_key FROM admin_pages WHERE page_key != 'manage_admins');

  RETURN json_build_object('id', target_id, 'updated', true);
END;
$$;

-- Delete admin (super admin only, cannot delete super_admin)
CREATE OR REPLACE FUNCTION delete_admin_user(caller_id TEXT, target_id TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM admin WHERE id = caller_id AND role = 'super_admin'
  ) THEN
    RAISE EXCEPTION 'Only Super Admin can delete admins';
  END IF;

  IF target_id = caller_id THEN
    RAISE EXCEPTION 'Cannot delete your own account';
  END IF;

  IF EXISTS (SELECT 1 FROM admin WHERE id = target_id AND role = 'super_admin') THEN
    RAISE EXCEPTION 'Cannot delete Super Admin accounts';
  END IF;

  DELETE FROM admin WHERE id = target_id AND role = 'admin';

  RETURN json_build_object('deleted', target_id);
END;
$$;

-- List all available pages
CREATE OR REPLACE FUNCTION list_admin_pages()
RETURNS JSON
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(json_agg(json_build_object(
    'page_key', page_key,
    'label', label,
    'sort_order', sort_order
  ) ORDER BY sort_order), '[]'::json)
  FROM admin_pages
  WHERE page_key != 'manage_admins';
$$;

GRANT EXECUTE ON FUNCTION verify_admin(TEXT, TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION list_admin_users(TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION create_admin_user(TEXT, TEXT, TEXT, TEXT[]) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION update_admin_access(TEXT, TEXT, TEXT[]) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION delete_admin_user(TEXT, TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION list_admin_pages() TO anon, authenticated, service_role;
