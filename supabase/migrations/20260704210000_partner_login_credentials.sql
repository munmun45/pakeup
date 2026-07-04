-- Partner store-app login credentials (set by admin)

ALTER TABLE partners ADD COLUMN IF NOT EXISTS login_id TEXT;
ALTER TABLE partners ADD COLUMN IF NOT EXISTS pass TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS idx_partners_login_id
  ON partners (login_id)
  WHERE login_id IS NOT NULL AND trim(login_id) <> '';

CREATE OR REPLACE FUNCTION list_partners(caller_id TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  RETURN (
    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.created_at DESC), '[]'::json)
    FROM (
      SELECT
        p.id,
        p.business_name,
        p.owner_name,
        p.phone,
        p.email,
        p.whatsapp,
        p.alternate_phone,
        p.city,
        p.state,
        p.pincode,
        p.category,
        coalesce(pc.name, p.category) AS category_name,
        p.address_line,
        p.description,
        p.gst_number,
        p.website,
        p.google_map_embed,
        p.latitude,
        p.longitude,
        p.notes,
        p.is_active,
        p.kyc_status,
        p.login_id,
        (p.pass IS NOT NULL AND trim(p.pass) <> '') AS has_password,
        p.created_at
      FROM partners p
      LEFT JOIN partner_categories pc ON pc.slug = p.category
    ) t
  );
END;
$$;

CREATE OR REPLACE FUNCTION set_partner_password(
  caller_id TEXT,
  partner_id UUID,
  login_id TEXT,
  new_pass TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_partner_id UUID := set_partner_password.partner_id;
  v_login_id TEXT := trim(set_partner_password.login_id);
  v_new_pass TEXT := trim(set_partner_password.new_pass);
  updated_row partners%ROWTYPE;
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  IF NOT EXISTS (SELECT 1 FROM partners WHERE id = v_partner_id) THEN
    RAISE EXCEPTION 'Partner not found';
  END IF;

  IF v_login_id = '' THEN
    RAISE EXCEPTION 'Login ID is required';
  END IF;

  IF v_new_pass = '' OR length(v_new_pass) < 4 THEN
    RAISE EXCEPTION 'Password must be at least 4 characters';
  END IF;

  IF EXISTS (
    SELECT 1 FROM partners p
    WHERE p.login_id = v_login_id AND p.id <> v_partner_id
  ) THEN
    RAISE EXCEPTION 'Login ID already in use';
  END IF;

  UPDATE partners
  SET login_id = v_login_id, pass = v_new_pass
  WHERE id = v_partner_id
  RETURNING * INTO updated_row;

  RETURN json_build_object(
    'id', updated_row.id,
    'login_id', updated_row.login_id,
    'has_password', true
  );
END;
$$;

GRANT EXECUTE ON FUNCTION set_partner_password(TEXT, UUID, TEXT, TEXT)
  TO anon, authenticated, service_role;
