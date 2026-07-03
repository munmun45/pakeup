-- Admin active / inactive status

ALTER TABLE admin
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true;

UPDATE admin SET is_active = true WHERE is_active IS NULL;

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

  IF NOT admin_row.is_active THEN
    RETURN json_build_object('error', 'deactivated');
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
        a.is_active,
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

CREATE OR REPLACE FUNCTION set_admin_active(
  caller_id TEXT,
  target_id TEXT,
  active BOOLEAN
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
    RAISE EXCEPTION 'Only Super Admin can change admin status';
  END IF;

  IF caller_id = target_id THEN
    RAISE EXCEPTION 'You cannot change your own account status';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM admin WHERE id = target_id AND role = 'admin') THEN
    RAISE EXCEPTION 'Can only change status for regular admin accounts';
  END IF;

  UPDATE admin
  SET is_active = active
  WHERE id = target_id AND role = 'admin';

  RETURN json_build_object('id', target_id, 'is_active', active);
END;
$$;

GRANT EXECUTE ON FUNCTION set_admin_active(TEXT, TEXT, BOOLEAN)
  TO anon, authenticated, service_role;
