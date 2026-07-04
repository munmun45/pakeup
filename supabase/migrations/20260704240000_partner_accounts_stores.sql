-- Separate partner login account from store (salon) records.
-- One account can own multiple stores.

CREATE TABLE IF NOT EXISTS partner_accounts (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_name      TEXT NOT NULL,
  phone           TEXT,
  email           TEXT,
  whatsapp        TEXT,
  alternate_phone TEXT,
  login_id        TEXT,
  pass            TEXT,
  is_active       BOOLEAN NOT NULL DEFAULT true,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

DROP TRIGGER IF EXISTS partner_accounts_updated_at ON partner_accounts;
CREATE TRIGGER partner_accounts_updated_at
  BEFORE UPDATE ON partner_accounts
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE partners ADD COLUMN IF NOT EXISTS account_id UUID REFERENCES partner_accounts(id);

DO $$
DECLARE
  r RECORD;
  acc_id UUID;
BEGIN
  FOR r IN SELECT * FROM partners WHERE account_id IS NULL LOOP
    INSERT INTO partner_accounts (
      owner_name,
      phone,
      email,
      whatsapp,
      alternate_phone,
      login_id,
      pass,
      is_active,
      created_at,
      updated_at
    ) VALUES (
      r.owner_name,
      r.phone,
      r.email,
      r.whatsapp,
      r.alternate_phone,
      r.login_id,
      r.pass,
      r.is_active,
      r.created_at,
      r.updated_at
    )
    RETURNING id INTO acc_id;

    UPDATE partners SET account_id = acc_id WHERE id = r.id;
  END LOOP;
END $$;

CREATE INDEX IF NOT EXISTS idx_partners_account_id ON partners(account_id);

CREATE UNIQUE INDEX IF NOT EXISTS idx_partner_accounts_phone_unique
  ON partner_accounts (phone)
  WHERE phone IS NOT NULL AND trim(phone) <> '';

CREATE UNIQUE INDEX IF NOT EXISTS idx_partner_accounts_login_id_unique
  ON partner_accounts (login_id)
  WHERE login_id IS NOT NULL AND trim(login_id) <> '';

ALTER TABLE partner_kyc_details
  ADD COLUMN IF NOT EXISTS account_id UUID REFERENCES partner_accounts(id);

UPDATE partner_kyc_details k
SET account_id = p.account_id
FROM partners p
WHERE p.id = k.partner_id
  AND k.account_id IS NULL;

CREATE OR REPLACE FUNCTION list_partner_accounts(caller_id TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  RETURN (
    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.owner_name, t.phone), '[]'::json)
    FROM (
      SELECT
        a.id,
        a.owner_name,
        a.phone,
        a.email,
        a.whatsapp,
        a.alternate_phone,
        a.login_id,
        (a.pass IS NOT NULL AND trim(a.pass) <> '') AS has_password,
        a.is_active,
        (
          SELECT count(*)::int
          FROM partners p
          WHERE p.account_id = a.id
        ) AS store_count,
        a.created_at
      FROM partner_accounts a
    ) t
  );
END;
$$;

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
        p.account_id,
        p.business_name,
        coalesce(a.owner_name, p.owner_name) AS owner_name,
        coalesce(a.phone, p.phone) AS phone,
        coalesce(a.email, p.email) AS email,
        coalesce(a.whatsapp, p.whatsapp) AS whatsapp,
        coalesce(a.alternate_phone, p.alternate_phone) AS alternate_phone,
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
        a.login_id,
        (a.pass IS NOT NULL AND trim(a.pass) <> '') AS has_password,
        (
          SELECT count(*)::int
          FROM partners ps
          WHERE ps.account_id = p.account_id
        ) AS store_count,
        p.created_at
      FROM partners p
      LEFT JOIN partner_accounts a ON a.id = p.account_id
      LEFT JOIN partner_categories pc ON pc.slug = p.category
    ) t
  );
END;
$$;

DROP FUNCTION IF EXISTS create_partner(
  TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, TEXT
);

CREATE OR REPLACE FUNCTION create_partner(
  caller_id         TEXT,
  business_name     TEXT,
  owner_name        TEXT,
  phone             TEXT DEFAULT NULL,
  email             TEXT DEFAULT NULL,
  whatsapp          TEXT DEFAULT NULL,
  alternate_phone   TEXT DEFAULT NULL,
  city              TEXT DEFAULT NULL,
  state             TEXT DEFAULT NULL,
  pincode           TEXT DEFAULT NULL,
  category          TEXT DEFAULT 'salon',
  address_line      TEXT DEFAULT NULL,
  description       TEXT DEFAULT NULL,
  gst_number        TEXT DEFAULT NULL,
  website           TEXT DEFAULT NULL,
  google_map_embed  TEXT DEFAULT NULL,
  latitude          DOUBLE PRECISION DEFAULT NULL,
  longitude         DOUBLE PRECISION DEFAULT NULL,
  notes             TEXT DEFAULT NULL,
  account_id        UUID DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_business_name    TEXT := trim(create_partner.business_name);
  v_owner_name       TEXT := trim(create_partner.owner_name);
  v_phone            TEXT := nullif(trim(create_partner.phone), '');
  v_email            TEXT := nullif(trim(create_partner.email), '');
  v_whatsapp         TEXT := nullif(trim(create_partner.whatsapp), '');
  v_alternate_phone  TEXT := nullif(trim(create_partner.alternate_phone), '');
  v_city             TEXT := nullif(trim(create_partner.city), '');
  v_state            TEXT := nullif(trim(create_partner.state), '');
  v_pincode          TEXT := nullif(trim(create_partner.pincode), '');
  v_category         TEXT := coalesce(nullif(trim(create_partner.category), ''), 'salon');
  v_address_line     TEXT := nullif(trim(create_partner.address_line), '');
  v_description      TEXT := nullif(trim(create_partner.description), '');
  v_gst_number       TEXT := nullif(trim(create_partner.gst_number), '');
  v_website          TEXT := nullif(trim(create_partner.website), '');
  v_google_map_embed TEXT := nullif(trim(create_partner.google_map_embed), '');
  v_latitude         DOUBLE PRECISION := create_partner.latitude;
  v_longitude        DOUBLE PRECISION := create_partner.longitude;
  v_notes            TEXT := nullif(trim(create_partner.notes), '');
  v_account_id       UUID := create_partner.account_id;
  account_row        partner_accounts%ROWTYPE;
  new_row            partners%ROWTYPE;
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  IF v_business_name = '' THEN
    RAISE EXCEPTION 'Business name is required';
  END IF;

  IF v_account_id IS NULL THEN
    IF v_owner_name = '' THEN
      RAISE EXCEPTION 'Owner name is required';
    END IF;

    INSERT INTO partner_accounts (
      owner_name, phone, email, whatsapp, alternate_phone, login_id
    ) VALUES (
      v_owner_name,
      v_phone,
      v_email,
      v_whatsapp,
      v_alternate_phone,
      v_phone
    )
    RETURNING * INTO account_row;

    v_account_id := account_row.id;
  ELSE
    IF NOT EXISTS (SELECT 1 FROM partner_accounts a WHERE a.id = v_account_id) THEN
      RAISE EXCEPTION 'Account not found';
    END IF;

    SELECT * INTO account_row FROM partner_accounts a WHERE a.id = v_account_id;
    v_owner_name := account_row.owner_name;
    v_phone := account_row.phone;
    v_email := account_row.email;
    v_whatsapp := account_row.whatsapp;
    v_alternate_phone := account_row.alternate_phone;
  END IF;

  INSERT INTO partners (
    account_id,
    business_name,
    owner_name,
    phone,
    email,
    whatsapp,
    alternate_phone,
    city,
    state,
    pincode,
    category,
    address_line,
    description,
    gst_number,
    website,
    google_map_embed,
    latitude,
    longitude,
    notes
  ) VALUES (
    v_account_id,
    v_business_name,
    v_owner_name,
    v_phone,
    v_email,
    v_whatsapp,
    v_alternate_phone,
    v_city,
    v_state,
    v_pincode,
    v_category,
    v_address_line,
    v_description,
    v_gst_number,
    v_website,
    v_google_map_embed,
    v_latitude,
    v_longitude,
    v_notes
  )
  RETURNING * INTO new_row;

  RETURN row_to_json(new_row);
END;
$$;

CREATE OR REPLACE FUNCTION update_partner(
  caller_id         TEXT,
  partner_id        UUID,
  business_name     TEXT,
  owner_name        TEXT,
  phone             TEXT DEFAULT NULL,
  email             TEXT DEFAULT NULL,
  whatsapp          TEXT DEFAULT NULL,
  alternate_phone   TEXT DEFAULT NULL,
  city              TEXT DEFAULT NULL,
  state             TEXT DEFAULT NULL,
  pincode           TEXT DEFAULT NULL,
  category          TEXT DEFAULT 'salon',
  address_line      TEXT DEFAULT NULL,
  description       TEXT DEFAULT NULL,
  gst_number        TEXT DEFAULT NULL,
  website           TEXT DEFAULT NULL,
  google_map_embed  TEXT DEFAULT NULL,
  latitude          DOUBLE PRECISION DEFAULT NULL,
  longitude         DOUBLE PRECISION DEFAULT NULL,
  notes             TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_partner_id       UUID := update_partner.partner_id;
  v_business_name    TEXT := trim(update_partner.business_name);
  v_owner_name       TEXT := trim(update_partner.owner_name);
  v_phone            TEXT := nullif(trim(update_partner.phone), '');
  v_email            TEXT := nullif(trim(update_partner.email), '');
  v_whatsapp         TEXT := nullif(trim(update_partner.whatsapp), '');
  v_alternate_phone  TEXT := nullif(trim(update_partner.alternate_phone), '');
  v_city             TEXT := nullif(trim(update_partner.city), '');
  v_state            TEXT := nullif(trim(update_partner.state), '');
  v_pincode          TEXT := nullif(trim(update_partner.pincode), '');
  v_category         TEXT := coalesce(nullif(trim(update_partner.category), ''), 'salon');
  v_address_line     TEXT := nullif(trim(update_partner.address_line), '');
  v_description      TEXT := nullif(trim(update_partner.description), '');
  v_gst_number       TEXT := nullif(trim(update_partner.gst_number), '');
  v_website          TEXT := nullif(trim(update_partner.website), '');
  v_google_map_embed TEXT := nullif(trim(update_partner.google_map_embed), '');
  v_latitude         DOUBLE PRECISION := update_partner.latitude;
  v_longitude        DOUBLE PRECISION := update_partner.longitude;
  v_notes            TEXT := nullif(trim(update_partner.notes), '');
  v_account_id       UUID;
  updated_row        partners%ROWTYPE;
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  IF v_business_name = '' OR v_owner_name = '' THEN
    RAISE EXCEPTION 'Business name and owner name are required';
  END IF;

  SELECT p.account_id INTO v_account_id
  FROM partners p
  WHERE p.id = v_partner_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Partner not found';
  END IF;

  IF v_account_id IS NOT NULL THEN
    UPDATE partner_accounts SET
      owner_name = v_owner_name,
      phone = v_phone,
      email = v_email,
      whatsapp = v_whatsapp,
      alternate_phone = v_alternate_phone,
      login_id = coalesce(login_id, v_phone)
    WHERE id = v_account_id;
  END IF;

  UPDATE partners SET
    business_name = v_business_name,
    owner_name = v_owner_name,
    phone = v_phone,
    email = v_email,
    whatsapp = v_whatsapp,
    alternate_phone = v_alternate_phone,
    city = v_city,
    state = v_state,
    pincode = v_pincode,
    category = v_category,
    address_line = v_address_line,
    description = v_description,
    gst_number = v_gst_number,
    website = v_website,
    google_map_embed = v_google_map_embed,
    latitude = v_latitude,
    longitude = v_longitude,
    notes = v_notes
  WHERE id = v_partner_id
  RETURNING * INTO updated_row;

  RETURN row_to_json(updated_row);
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
  v_account_id UUID;
  updated_row partner_accounts%ROWTYPE;
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  SELECT p.account_id INTO v_account_id
  FROM partners p
  WHERE p.id = v_partner_id;

  IF v_account_id IS NULL THEN
    RAISE EXCEPTION 'Partner account not found';
  END IF;

  IF v_login_id = '' THEN
    RAISE EXCEPTION 'Login ID is required';
  END IF;

  IF v_new_pass = '' OR length(v_new_pass) < 4 THEN
    RAISE EXCEPTION 'Password must be at least 4 characters';
  END IF;

  IF EXISTS (
    SELECT 1 FROM partner_accounts a
    WHERE a.login_id = v_login_id AND a.id <> v_account_id
  ) THEN
    RAISE EXCEPTION 'Login ID already in use';
  END IF;

  UPDATE partner_accounts
  SET login_id = v_login_id, pass = v_new_pass
  WHERE id = v_account_id
  RETURNING * INTO updated_row;

  RETURN json_build_object(
    'account_id', updated_row.id,
    'login_id', updated_row.login_id,
    'has_password', true
  );
END;
$$;

CREATE OR REPLACE FUNCTION verify_partner(login_id TEXT, login_pass TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_login_id TEXT := trim(verify_partner.login_id);
  v_login_pass TEXT := trim(verify_partner.login_pass);
  account_row partner_accounts%ROWTYPE;
  store_row partners%ROWTYPE;
BEGIN
  IF v_login_id = '' OR v_login_pass = '' THEN
    RETURN NULL;
  END IF;

  SELECT * INTO account_row
  FROM partner_accounts a
  WHERE (a.login_id = v_login_id OR a.phone = v_login_id)
    AND a.pass = v_login_pass;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  IF NOT account_row.is_active THEN
    RETURN json_build_object('error', 'deactivated');
  END IF;

  IF account_row.pass IS NULL OR trim(account_row.pass) = '' THEN
    RETURN json_build_object('error', 'no_password');
  END IF;

  SELECT * INTO store_row
  FROM partners p
  WHERE p.account_id = account_row.id
  ORDER BY p.created_at
  LIMIT 1;

  RETURN json_build_object(
    'id', account_row.id,
    'account_id', account_row.id,
    'business_name', coalesce(store_row.business_name, account_row.owner_name),
    'owner_name', account_row.owner_name,
    'phone', account_row.phone,
    'email', account_row.email,
    'city', store_row.city,
    'category', coalesce(store_row.category, 'salon'),
    'is_active', account_row.is_active,
    'kyc_status', coalesce(store_row.kyc_status, 'pending'),
    'login_id', account_row.login_id,
    'store_count', (
      SELECT count(*)::int FROM partners p WHERE p.account_id = account_row.id
    ),
    'created_at', account_row.created_at
  );
END;
$$;

CREATE OR REPLACE FUNCTION register_partner(
  business_name TEXT,
  owner_name TEXT,
  login_id TEXT,
  login_pass TEXT,
  phone TEXT DEFAULT NULL,
  email TEXT DEFAULT NULL,
  city TEXT DEFAULT NULL,
  category TEXT DEFAULT 'salon'
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_business_name TEXT := trim(register_partner.business_name);
  v_owner_name TEXT := trim(register_partner.owner_name);
  v_login_pass TEXT := trim(register_partner.login_pass);
  v_phone TEXT := nullif(trim(register_partner.phone), '');
  v_email TEXT := nullif(trim(register_partner.email), '');
  v_city TEXT := nullif(trim(register_partner.city), '');
  v_category TEXT := coalesce(nullif(trim(register_partner.category), ''), 'salon');
  v_login_id TEXT;
  account_row partner_accounts%ROWTYPE;
  store_row partners%ROWTYPE;
BEGIN
  IF v_business_name = '' OR v_owner_name = '' THEN
    RAISE EXCEPTION 'Business name and owner name are required';
  END IF;

  IF v_phone IS NULL THEN
    RAISE EXCEPTION 'Phone number is required';
  END IF;

  IF length(v_phone) <> 10 THEN
    RAISE EXCEPTION 'Phone must be 10 digits';
  END IF;

  v_login_id := v_phone;

  IF v_login_pass = '' OR length(v_login_pass) < 4 THEN
    RAISE EXCEPTION 'Password must be at least 4 characters';
  END IF;

  IF EXISTS (
    SELECT 1 FROM partner_accounts a
    WHERE a.login_id = v_login_id OR a.phone = v_phone
  ) THEN
    RAISE EXCEPTION 'Phone number already registered';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM partner_categories pc
    WHERE pc.slug = v_category AND pc.is_active
  ) THEN
    v_category := 'salon';
  END IF;

  INSERT INTO partner_accounts (
    owner_name, phone, email, login_id, pass, is_active
  ) VALUES (
    v_owner_name, v_phone, v_email, v_login_id, v_login_pass, true
  )
  RETURNING * INTO account_row;

  INSERT INTO partners (
    account_id,
    business_name,
    owner_name,
    phone,
    email,
    city,
    category,
    is_active,
    kyc_status
  ) VALUES (
    account_row.id,
    v_business_name,
    v_owner_name,
    v_phone,
    v_email,
    v_city,
    v_category,
    true,
    'pending'
  )
  RETURNING * INTO store_row;

  RETURN json_build_object(
    'id', account_row.id,
    'account_id', account_row.id,
    'business_name', store_row.business_name,
    'owner_name', account_row.owner_name,
    'phone', account_row.phone,
    'email', account_row.email,
    'city', store_row.city,
    'category', store_row.category,
    'is_active', account_row.is_active,
    'kyc_status', store_row.kyc_status,
    'login_id', account_row.login_id,
    'store_count', 1,
    'created_at', account_row.created_at
  );
END;
$$;

GRANT EXECUTE ON FUNCTION list_partner_accounts(TEXT)
  TO anon, authenticated, service_role;
