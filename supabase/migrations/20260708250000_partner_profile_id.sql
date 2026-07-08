-- Human-readable partner profile IDs: A000001, A000002, ...

CREATE SEQUENCE IF NOT EXISTS partner_profile_id_seq
  START WITH 1
  INCREMENT BY 1
  NO MINVALUE
  NO MAXVALUE
  CACHE 1;

CREATE OR REPLACE FUNCTION generate_partner_profile_id()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
  n BIGINT;
BEGIN
  n := nextval('partner_profile_id_seq');
  IF n > 999999 THEN
    RAISE EXCEPTION 'Partner profile ID limit reached';
  END IF;
  RETURN 'A' || lpad(n::text, 6, '0');
END;
$$;

ALTER TABLE partner_accounts
  ADD COLUMN IF NOT EXISTS profile_id TEXT;

DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT id
    FROM partner_accounts
    WHERE profile_id IS NULL
    ORDER BY created_at ASC, id ASC
  LOOP
    UPDATE partner_accounts
    SET profile_id = generate_partner_profile_id()
    WHERE id = r.id;
  END LOOP;
END $$;

ALTER TABLE partner_accounts
  ALTER COLUMN profile_id SET DEFAULT generate_partner_profile_id();

ALTER TABLE partner_accounts
  ALTER COLUMN profile_id SET NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_partner_accounts_profile_id_unique
  ON partner_accounts (profile_id);

-- ── verify_partner ────────────────────────────────────────────────────────────

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
  v_kyc_status TEXT;
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

  SELECT CASE
    WHEN bool_or(p.kyc_status = 'approved') THEN 'approved'
    WHEN bool_or(p.kyc_status = 'rejected') THEN 'rejected'
    ELSE 'pending'
  END
  INTO v_kyc_status
  FROM partners p
  WHERE p.account_id = account_row.id;

  v_kyc_status := coalesce(v_kyc_status, 'pending');

  SELECT * INTO store_row
  FROM partners p
  WHERE p.account_id = account_row.id
  ORDER BY p.created_at DESC
  LIMIT 1;

  RETURN json_build_object(
    'id', account_row.id,
    'account_id', account_row.id,
    'profile_id', account_row.profile_id,
    'business_name', coalesce(store_row.business_name, account_row.owner_name),
    'owner_name', account_row.owner_name,
    'phone', account_row.phone,
    'email', account_row.email,
    'city', store_row.city,
    'category', coalesce(store_row.category, 'salon'),
    'is_active', account_row.is_active,
    'kyc_status', v_kyc_status,
    'login_id', account_row.login_id,
    'store_count', (
      SELECT count(*)::int FROM partners p WHERE p.account_id = account_row.id
    ),
    'created_at', account_row.created_at
  );
END;
$$;

-- ── register_partner ──────────────────────────────────────────────────────────

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
    'profile_id', account_row.profile_id,
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

-- ── create_partner_account ────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION create_partner_account(
  caller_id                   TEXT,
  owner_name                  TEXT,
  phone                       TEXT DEFAULT NULL,
  email                       TEXT DEFAULT NULL,
  whatsapp                    TEXT DEFAULT NULL,
  alternate_phone             TEXT DEFAULT NULL,
  login_pass                  TEXT DEFAULT NULL,
  phone_verification_token    UUID DEFAULT NULL,
  whatsapp_verification_token UUID DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_owner_name      TEXT := trim(create_partner_account.owner_name);
  v_phone           TEXT := nullif(trim(create_partner_account.phone), '');
  v_email           TEXT := nullif(trim(create_partner_account.email), '');
  v_whatsapp        TEXT := nullif(trim(create_partner_account.whatsapp), '');
  v_alternate_phone TEXT := nullif(trim(create_partner_account.alternate_phone), '');
  v_login_pass      TEXT := nullif(trim(create_partner_account.login_pass), '');
  account_row       partner_accounts%ROWTYPE;
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  IF v_owner_name = '' THEN
    RAISE EXCEPTION 'Owner name is required';
  END IF;

  IF v_phone IS NULL OR length(v_phone) <> 10 THEN
    RAISE EXCEPTION 'Phone must be 10 digits';
  END IF;

  IF v_whatsapp IS NULL OR length(v_whatsapp) <> 10 THEN
    RAISE EXCEPTION 'WhatsApp must be a 10-digit number';
  END IF;

  IF v_email IS NULL OR v_email = '' THEN
    RAISE EXCEPTION 'Email is required';
  END IF;

  IF phone_verification_token IS NOT NULL THEN
    PERFORM consume_partner_otp_token(
      phone_verification_token, v_phone, 'mobile', caller_id
    );
  END IF;

  IF whatsapp_verification_token IS NOT NULL THEN
    PERFORM consume_partner_otp_token(
      whatsapp_verification_token, v_whatsapp, 'whatsapp', caller_id
    );
  END IF;

  IF EXISTS (
    SELECT 1 FROM partner_accounts a
    WHERE a.phone = v_phone OR a.login_id = v_phone
  ) THEN
    RAISE EXCEPTION 'Phone number already registered';
  END IF;

  IF v_login_pass IS NOT NULL AND length(v_login_pass) < 4 THEN
    RAISE EXCEPTION 'Password must be at least 4 characters';
  END IF;

  INSERT INTO partner_accounts (
    owner_name, phone, email, whatsapp, alternate_phone, login_id, pass
  ) VALUES (
    v_owner_name, v_phone, v_email, v_whatsapp, v_alternate_phone, v_phone, v_login_pass
  )
  RETURNING * INTO account_row;

  RETURN json_build_object(
    'id', account_row.id,
    'profile_id', account_row.profile_id,
    'owner_name', account_row.owner_name,
    'phone', account_row.phone,
    'email', account_row.email,
    'whatsapp', account_row.whatsapp,
    'alternate_phone', account_row.alternate_phone,
    'login_id', account_row.login_id,
    'has_password', account_row.pass IS NOT NULL AND trim(account_row.pass) <> '',
    'is_active', account_row.is_active,
    'store_count', 0,
    'created_at', account_row.created_at
  );
END;
$$;

-- ── list_partner_accounts ───────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION list_partner_accounts(caller_id TEXT)
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
        a.id,
        a.profile_id,
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

-- ── list_partner_bank_accounts ────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION list_partner_bank_accounts(caller_id TEXT)
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
        a.id AS account_id,
        a.profile_id,
        a.owner_name,
        a.phone,
        a.email,
        a.is_active,
        a.created_at,
        (
          SELECT count(*)::int
          FROM partners p
          WHERE p.account_id = a.id
        ) AS store_count,
        (
          SELECT p.primary_image
          FROM partners p
          WHERE p.account_id = a.id
          ORDER BY p.created_at DESC
          LIMIT 1
        ) AS primary_image,
        COALESCE(b.account_status, 'pending') AS account_status,
        b.bank_account_holder,
        b.bank_name,
        b.ifsc_code,
        b.account_number,
        b.account_type,
        b.upi_id,
        b.passbook_doc_url,
        b.updated_at AS account_updated_at
      FROM partner_accounts a
      LEFT JOIN partner_bank_details b ON b.account_id = a.id
    ) t
  );
END;
$$;

GRANT EXECUTE ON FUNCTION verify_partner(TEXT, TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION register_partner(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION create_partner_account(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, UUID, UUID)
  TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION list_partner_accounts(TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION list_partner_bank_accounts(TEXT) TO anon, authenticated, service_role;

NOTIFY pgrst, 'reload schema';
