-- Admin account creation date + profile fetch

ALTER TABLE admin
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();

UPDATE admin SET created_at = now() WHERE created_at IS NULL;

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
    'is_active', admin_row.is_active,
    'created_at', admin_row.created_at,
    'pages', pages
  );
END;
$$;

CREATE OR REPLACE FUNCTION get_admin_profile(caller_id TEXT)
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
  WHERE id = caller_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Admin account not found';
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
    'is_active', admin_row.is_active,
    'created_at', admin_row.created_at,
    'pages', pages
  );
END;
$$;

GRANT EXECUTE ON FUNCTION get_admin_profile(TEXT)
  TO anon, authenticated, service_role;
