-- Add name, phone, notes to admin table

ALTER TABLE admin
  ADD COLUMN IF NOT EXISTS name TEXT,
  ADD COLUMN IF NOT EXISTS phone TEXT,
  ADD COLUMN IF NOT EXISTS notes TEXT;

UPDATE admin SET name = 'Super Admin' WHERE id = 'superadmin' AND (name IS NULL OR name = '');
UPDATE admin SET name = 'Admin User' WHERE id = 'admin' AND (name IS NULL OR name = '');

-- Login: include name
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
    'name', admin_row.name,
    'phone', admin_row.phone,
    'notes', admin_row.notes,
    'pages', pages
  );
END;
$$;

-- List admins with profile fields
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
        a.name,
        a.phone,
        a.notes,
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

DROP FUNCTION IF EXISTS create_admin_user(TEXT, TEXT, TEXT, TEXT[]);

CREATE OR REPLACE FUNCTION create_admin_user(
  caller_id TEXT,
  new_id TEXT,
  new_pass TEXT,
  page_keys TEXT[],
  admin_name TEXT DEFAULT NULL,
  admin_phone TEXT DEFAULT NULL,
  admin_notes TEXT DEFAULT NULL
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

  INSERT INTO admin (id, pass, role, name, phone, notes)
  VALUES (
    new_id,
    new_pass,
    'admin',
    NULLIF(trim(admin_name), ''),
    NULLIF(trim(admin_phone), ''),
    NULLIF(trim(admin_notes), '')
  );

  INSERT INTO admin_page_access (admin_id, page_key)
  SELECT new_id, pk
  FROM unnest(page_keys) AS pk
  WHERE pk IN (SELECT page_key FROM admin_pages WHERE page_key != 'manage_admins');

  RETURN json_build_object('id', new_id, 'role', 'admin');
END;
$$;

DROP FUNCTION IF EXISTS update_admin_access(TEXT, TEXT, TEXT[]);

CREATE OR REPLACE FUNCTION update_admin_user(
  caller_id TEXT,
  target_id TEXT,
  page_keys TEXT[],
  admin_name TEXT DEFAULT NULL,
  admin_phone TEXT DEFAULT NULL,
  admin_notes TEXT DEFAULT NULL
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
    RAISE EXCEPTION 'Only Super Admin can update admins';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM admin WHERE id = target_id AND role = 'admin') THEN
    RAISE EXCEPTION 'Can only update regular admin accounts';
  END IF;

  UPDATE admin
  SET
    name = NULLIF(trim(admin_name), ''),
    phone = NULLIF(trim(admin_phone), ''),
    notes = NULLIF(trim(admin_notes), '')
  WHERE id = target_id;

  DELETE FROM admin_page_access WHERE admin_id = target_id;

  INSERT INTO admin_page_access (admin_id, page_key)
  SELECT target_id, pk
  FROM unnest(page_keys) AS pk
  WHERE pk IN (SELECT page_key FROM admin_pages WHERE page_key != 'manage_admins');

  RETURN json_build_object('id', target_id, 'updated', true);
END;
$$;

GRANT EXECUTE ON FUNCTION create_admin_user(TEXT, TEXT, TEXT, TEXT[], TEXT, TEXT, TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION update_admin_user(TEXT, TEXT, TEXT[], TEXT, TEXT, TEXT) TO anon, authenticated, service_role;
