-- Allow changing admin id and password on edit

ALTER TABLE admin_page_access
  DROP CONSTRAINT IF EXISTS admin_page_access_admin_id_fkey;

ALTER TABLE admin_page_access
  ADD CONSTRAINT admin_page_access_admin_id_fkey
  FOREIGN KEY (admin_id) REFERENCES admin(id)
  ON DELETE CASCADE ON UPDATE CASCADE;

DROP FUNCTION IF EXISTS update_admin_user(TEXT, TEXT, TEXT[], TEXT, TEXT, TEXT);

CREATE OR REPLACE FUNCTION update_admin_user(
  caller_id TEXT,
  target_id TEXT,
  page_keys TEXT[],
  admin_name TEXT DEFAULT NULL,
  admin_phone TEXT DEFAULT NULL,
  admin_notes TEXT DEFAULT NULL,
  new_id TEXT DEFAULT NULL,
  new_pass TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_final_id TEXT;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM admin WHERE id = caller_id AND role = 'super_admin'
  ) THEN
    RAISE EXCEPTION 'Only Super Admin can update admins';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM admin WHERE id = target_id AND role = 'admin') THEN
    RAISE EXCEPTION 'Can only update regular admin accounts';
  END IF;

  v_final_id := COALESCE(NULLIF(trim(new_id), ''), target_id);

  IF v_final_id <> target_id THEN
    IF EXISTS (SELECT 1 FROM admin WHERE id = v_final_id) THEN
      RAISE EXCEPTION 'Admin ID already exists';
    END IF;
  END IF;

  IF new_pass IS NOT NULL AND trim(new_pass) <> '' AND length(trim(new_pass)) < 4 THEN
    RAISE EXCEPTION 'Password must be at least 4 characters';
  END IF;

  UPDATE admin
  SET
    id = v_final_id,
    name = NULLIF(trim(admin_name), ''),
    phone = NULLIF(trim(admin_phone), ''),
    notes = NULLIF(trim(admin_notes), ''),
    pass = CASE
      WHEN new_pass IS NOT NULL AND trim(new_pass) <> '' THEN trim(new_pass)
      ELSE pass
    END
  WHERE id = target_id;

  DELETE FROM admin_page_access WHERE admin_id = v_final_id;

  INSERT INTO admin_page_access (admin_id, page_key)
  SELECT v_final_id, pk
  FROM unnest(page_keys) AS pk
  WHERE pk IN (SELECT page_key FROM admin_pages WHERE page_key != 'manage_admins');

  RETURN json_build_object('id', v_final_id, 'updated', true);
END;
$$;

GRANT EXECUTE ON FUNCTION update_admin_user(TEXT, TEXT, TEXT[], TEXT, TEXT, TEXT, TEXT, TEXT)
  TO anon, authenticated, service_role;
