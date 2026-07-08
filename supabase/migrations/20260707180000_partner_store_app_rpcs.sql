-- Partner store app: list/create stores via RPC (anon has no direct partners table access)

CREATE OR REPLACE FUNCTION assert_partner_account_access(
  p_account_id UUID,
  p_login_pass   TEXT
)
RETURNS partner_accounts
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_account_id UUID := assert_partner_account_access.p_account_id;
  v_login_pass TEXT := trim(assert_partner_account_access.p_login_pass);
  account_row  partner_accounts%ROWTYPE;
BEGIN
  IF v_account_id IS NULL OR v_login_pass = '' THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO account_row
  FROM partner_accounts a
  WHERE a.id = v_account_id
    AND a.pass = v_login_pass;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  IF NOT account_row.is_active THEN
    RAISE EXCEPTION 'Account deactivated';
  END IF;

  RETURN account_row;
END;
$$;

CREATE OR REPLACE FUNCTION list_partner_stores(
  p_account_id UUID,
  p_login_pass TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_account_id UUID := list_partner_stores.p_account_id;
BEGIN
  PERFORM assert_partner_account_access(v_account_id, p_login_pass);

  RETURN COALESCE((
    SELECT json_agg(row_to_json(t) ORDER BY t.created_at DESC)
    FROM (
      SELECT
        p.id,
        p.account_id,
        p.business_name,
        p.owner_name,
        p.phone,
        p.alternate_phone,
        p.email,
        p.address_line,
        p.city,
        p.state,
        p.pincode,
        p.latitude,
        p.longitude,
        p.category,
        p.is_active,
        p.kyc_status,
        p.primary_image,
        p.created_at
      FROM partners p
      WHERE p.account_id = v_account_id
    ) t
  ), '[]'::json);
END;
$$;

CREATE OR REPLACE FUNCTION create_partner_store(
  p_account_id    UUID,
  p_login_pass    TEXT,
  p_business_name TEXT,
  p_owner_name    TEXT DEFAULT NULL,
  p_phone         TEXT DEFAULT NULL,
  p_whatsapp      TEXT DEFAULT NULL,
  p_email         TEXT DEFAULT NULL,
  p_description   TEXT DEFAULT NULL,
  p_address_line  TEXT DEFAULT NULL,
  p_city          TEXT DEFAULT NULL,
  p_state         TEXT DEFAULT NULL,
  p_pincode       TEXT DEFAULT NULL,
  p_latitude      DOUBLE PRECISION DEFAULT NULL,
  p_longitude     DOUBLE PRECISION DEFAULT NULL,
  p_category      TEXT DEFAULT 'salon'
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_account_id    UUID := create_partner_store.p_account_id;
  v_business_name TEXT := trim(create_partner_store.p_business_name);
  v_owner_name    TEXT := nullif(trim(create_partner_store.p_owner_name), '');
  v_phone         TEXT := nullif(trim(create_partner_store.p_phone), '');
  v_whatsapp      TEXT := nullif(trim(create_partner_store.p_whatsapp), '');
  v_email         TEXT := nullif(trim(create_partner_store.p_email), '');
  v_description   TEXT := nullif(trim(create_partner_store.p_description), '');
  v_address_line  TEXT := nullif(trim(create_partner_store.p_address_line), '');
  v_city          TEXT := nullif(trim(create_partner_store.p_city), '');
  v_state         TEXT := nullif(trim(create_partner_store.p_state), '');
  v_pincode       TEXT := nullif(trim(create_partner_store.p_pincode), '');
  v_category      TEXT := coalesce(nullif(trim(create_partner_store.p_category), ''), 'salon');
  account_row     partner_accounts%ROWTYPE;
  new_row         partners%ROWTYPE;
BEGIN
  account_row := assert_partner_account_access(v_account_id, p_login_pass);

  IF v_business_name = '' THEN
    RAISE EXCEPTION 'Business name is required';
  END IF;

  IF v_phone IS NULL OR length(v_phone) <> 10 THEN
    RAISE EXCEPTION 'Phone must be 10 digits';
  END IF;

  IF v_whatsapp IS NULL OR length(v_whatsapp) <> 10 THEN
    RAISE EXCEPTION 'WhatsApp must be 10 digits';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM partner_categories pc
    WHERE pc.slug = v_category AND pc.is_active
  ) THEN
    v_category := 'salon';
  END IF;

  v_owner_name := coalesce(v_owner_name, account_row.owner_name);

  INSERT INTO partners (
    account_id,
    business_name,
    owner_name,
    phone,
    whatsapp,
    email,
    description,
    address_line,
    city,
    state,
    pincode,
    latitude,
    longitude,
    category,
    kyc_status,
    is_active
  ) VALUES (
    v_account_id,
    v_business_name,
    v_owner_name,
    v_phone,
    v_whatsapp,
    v_email,
    v_description,
    v_address_line,
    v_city,
    v_state,
    v_pincode,
    p_latitude,
    p_longitude,
    v_category,
    'pending',
    true
  )
  RETURNING * INTO new_row;

  RETURN row_to_json(new_row);
END;
$$;

GRANT EXECUTE ON FUNCTION assert_partner_account_access(UUID, TEXT)
  TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION list_partner_stores(UUID, TEXT)
  TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION create_partner_store(
  UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, TEXT
) TO anon, authenticated, service_role;
