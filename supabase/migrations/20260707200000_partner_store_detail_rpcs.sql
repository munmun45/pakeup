-- Partner store app: get / update / toggle active for owned stores

CREATE OR REPLACE FUNCTION assert_partner_store_owned(
  p_account_id UUID,
  p_login_pass TEXT,
  p_store_id   UUID
)
RETURNS partners
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_account_id UUID := assert_partner_store_owned.p_account_id;
  v_store_id   UUID := assert_partner_store_owned.p_store_id;
  store_row    partners%ROWTYPE;
BEGIN
  PERFORM assert_partner_account_access(v_account_id, p_login_pass);

  SELECT * INTO store_row
  FROM partners p
  WHERE p.id = v_store_id
    AND p.account_id = v_account_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Store not found';
  END IF;

  RETURN store_row;
END;
$$;

-- Refresh list to include whatsapp + description
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
        p.whatsapp,
        p.alternate_phone,
        p.email,
        p.description,
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

CREATE OR REPLACE FUNCTION get_partner_store(
  p_account_id UUID,
  p_login_pass TEXT,
  p_store_id   UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  store_row partners%ROWTYPE;
BEGIN
  store_row := assert_partner_store_owned(p_account_id, p_login_pass, p_store_id);
  RETURN row_to_json(store_row);
END;
$$;

CREATE OR REPLACE FUNCTION update_partner_store(
  p_account_id    UUID,
  p_login_pass    TEXT,
  p_store_id      UUID,
  p_business_name TEXT,
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
  v_store_id      UUID := update_partner_store.p_store_id;
  v_business_name TEXT := trim(update_partner_store.p_business_name);
  v_phone         TEXT := nullif(trim(update_partner_store.p_phone), '');
  v_whatsapp      TEXT := nullif(trim(update_partner_store.p_whatsapp), '');
  v_email         TEXT := nullif(trim(update_partner_store.p_email), '');
  v_description   TEXT := nullif(trim(update_partner_store.p_description), '');
  v_address_line  TEXT := nullif(trim(update_partner_store.p_address_line), '');
  v_city          TEXT := nullif(trim(update_partner_store.p_city), '');
  v_state         TEXT := nullif(trim(update_partner_store.p_state), '');
  v_pincode       TEXT := nullif(trim(update_partner_store.p_pincode), '');
  v_category      TEXT := coalesce(nullif(trim(update_partner_store.p_category), ''), 'salon');
  updated_row     partners%ROWTYPE;
BEGIN
  PERFORM assert_partner_store_owned(p_account_id, p_login_pass, v_store_id);

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

  UPDATE partners SET
    business_name = v_business_name,
    phone = v_phone,
    whatsapp = v_whatsapp,
    email = v_email,
    description = v_description,
    address_line = v_address_line,
    city = v_city,
    state = v_state,
    pincode = v_pincode,
    latitude = p_latitude,
    longitude = p_longitude,
    category = v_category
  WHERE id = v_store_id
  RETURNING * INTO updated_row;

  RETURN row_to_json(updated_row);
END;
$$;

CREATE OR REPLACE FUNCTION set_partner_store_active(
  p_account_id UUID,
  p_login_pass TEXT,
  p_store_id   UUID,
  p_active     BOOLEAN
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_store_id UUID := set_partner_store_active.p_store_id;
  updated_row partners%ROWTYPE;
BEGIN
  PERFORM assert_partner_store_owned(p_account_id, p_login_pass, v_store_id);

  UPDATE partners SET is_active = p_active
  WHERE id = v_store_id
  RETURNING * INTO updated_row;

  RETURN row_to_json(updated_row);
END;
$$;

GRANT EXECUTE ON FUNCTION assert_partner_store_owned(UUID, TEXT, UUID)
  TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION get_partner_store(UUID, TEXT, UUID)
  TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION update_partner_store(
  UUID, TEXT, UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, TEXT
) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION set_partner_store_active(UUID, TEXT, UUID, BOOLEAN)
  TO anon, authenticated, service_role;

NOTIFY pgrst, 'reload schema';
