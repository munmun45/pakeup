-- ============================================================
-- PakeUp: Run this ENTIRE script in Supabase → SQL Editor → Run
-- Safe to run more than once.
-- ============================================================

-- 1) TABLE: one bank account per partner login (account_id)
CREATE TABLE IF NOT EXISTS partner_bank_details (
  account_id UUID PRIMARY KEY REFERENCES partner_accounts(id) ON DELETE CASCADE,
  bank_account_holder TEXT,
  bank_name TEXT,
  ifsc_code TEXT,
  account_number TEXT,
  account_type TEXT NOT NULL DEFAULT 'savings',
  upi_id TEXT,
  passbook_doc_url TEXT,
  account_status TEXT NOT NULL DEFAULT 'pending'
    CHECK (account_status IN ('pending', 'approved', 'rejected')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE partner_bank_details
  ADD COLUMN IF NOT EXISTS account_type TEXT NOT NULL DEFAULT 'savings',
  ADD COLUMN IF NOT EXISTS upi_id TEXT;

ALTER TABLE partner_kyc_details
  ADD COLUMN IF NOT EXISTS account_type TEXT DEFAULT 'savings',
  ADD COLUMN IF NOT EXISTS upi_id TEXT;

ALTER TABLE partner_kyc_details
  ADD COLUMN IF NOT EXISTS account_id UUID REFERENCES partner_accounts(id);

-- 2) MOBILE APP: save + get bank (includes account_type + upi_id)
CREATE OR REPLACE FUNCTION save_partner_bank_details(
  partner_id UUID,
  account_name TEXT,
  account_number TEXT,
  ifsc TEXT,
  bank_name TEXT,
  account_type TEXT DEFAULT 'savings',
  upi_id TEXT DEFAULT NULL,
  p_login_pass TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_account_id UUID := save_partner_bank_details.partner_id;
  store_row      partners%ROWTYPE;
  result_row     partner_bank_details%ROWTYPE;
BEGIN
  PERFORM assert_partner_account_access(v_account_id, p_login_pass);

  INSERT INTO partner_bank_details (
    account_id, bank_account_holder, bank_name, ifsc_code, account_number,
    account_type, upi_id, account_status
  )
  VALUES (
    v_account_id,
    nullif(trim(account_name), ''),
    nullif(trim(bank_name), ''),
    nullif(trim(upper(ifsc)), ''),
    nullif(trim(account_number), ''),
    COALESCE(nullif(trim(account_type), ''), 'savings'),
    nullif(trim(upi_id), ''),
    'pending'
  )
  ON CONFLICT (account_id) DO UPDATE SET
    bank_account_holder = EXCLUDED.bank_account_holder,
    bank_name = EXCLUDED.bank_name,
    ifsc_code = EXCLUDED.ifsc_code,
    account_number = EXCLUDED.account_number,
    account_type = EXCLUDED.account_type,
    upi_id = EXCLUDED.upi_id,
    account_status = 'pending',
    updated_at = now()
  RETURNING * INTO result_row;

  FOR store_row IN SELECT * FROM partners p WHERE p.account_id = v_account_id LOOP
    INSERT INTO partner_kyc_details (
      partner_id, account_id, bank_account_holder, bank_name, ifsc_code,
      account_number, account_type, upi_id, account_status
    )
    VALUES (
      store_row.id, v_account_id,
      result_row.bank_account_holder, result_row.bank_name, result_row.ifsc_code,
      result_row.account_number, result_row.account_type, result_row.upi_id, 'pending'
    )
    ON CONFLICT ON CONSTRAINT partner_kyc_details_partner_id_key DO UPDATE SET
      bank_account_holder = EXCLUDED.bank_account_holder,
      bank_name = EXCLUDED.bank_name,
      ifsc_code = EXCLUDED.ifsc_code,
      account_number = EXCLUDED.account_number,
      account_type = EXCLUDED.account_type,
      upi_id = EXCLUDED.upi_id,
      account_status = 'pending';
  END LOOP;

  RETURN row_to_json(result_row);
END;
$$;

CREATE OR REPLACE FUNCTION get_partner_bank_details(
  p_account_id UUID,
  p_login_pass TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM assert_partner_account_access(p_account_id, p_login_pass);
  RETURN (
    SELECT row_to_json(t) FROM (
      SELECT
        b.bank_account_holder AS account_name,
        b.bank_name,
        b.ifsc_code AS ifsc,
        b.account_number,
        b.account_type,
        b.upi_id,
        b.passbook_doc_url,
        b.account_status,
        b.updated_at
      FROM partner_bank_details b
      WHERE b.account_id = p_account_id
    ) t
  );
END;
$$;

-- 3) ADMIN: save account type + UPI only
CREATE OR REPLACE FUNCTION save_partner_bank_meta_admin(
  caller_id TEXT,
  account_id UUID,
  account_type TEXT DEFAULT 'savings',
  upi_id TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_account_id UUID := save_partner_bank_meta_admin.account_id;
  v_type TEXT := COALESCE(nullif(trim(account_type), ''), 'savings');
  v_upi  TEXT := nullif(trim(upi_id), '');
  store_row partners%ROWTYPE;
  result_row partner_bank_details%ROWTYPE;
BEGIN
  PERFORM assert_admin_partner_access(caller_id);
  IF NOT EXISTS (SELECT 1 FROM partner_accounts a WHERE a.id = v_account_id) THEN
    RAISE EXCEPTION 'Partner account not found';
  END IF;

  INSERT INTO partner_bank_details (account_id, account_type, upi_id, account_status)
  VALUES (v_account_id, v_type, v_upi, 'pending')
  ON CONFLICT (account_id) DO UPDATE SET
    account_type = v_type,
    upi_id = v_upi,
    updated_at = now()
  RETURNING * INTO result_row;

  FOR store_row IN SELECT * FROM partners p WHERE p.account_id = v_account_id LOOP
    INSERT INTO partner_kyc_details (partner_id, account_id, account_type, upi_id)
    VALUES (store_row.id, v_account_id, v_type, v_upi)
    ON CONFLICT ON CONSTRAINT partner_kyc_details_partner_id_key DO UPDATE SET
      account_type = v_type,
      upi_id = v_upi;
  END LOOP;

  RETURN row_to_json(result_row);
END;
$$;

-- 4) MOBILE: save account type + UPI only
CREATE OR REPLACE FUNCTION save_partner_bank_meta(
  partner_id UUID,
  p_login_pass TEXT,
  account_type TEXT DEFAULT 'savings',
  upi_id TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_account_id UUID := save_partner_bank_meta.partner_id;
  v_type TEXT := COALESCE(nullif(trim(account_type), ''), 'savings');
  v_upi  TEXT := nullif(trim(upi_id), '');
  store_row partners%ROWTYPE;
  result_row partner_bank_details%ROWTYPE;
BEGIN
  PERFORM assert_partner_account_access(v_account_id, p_login_pass);

  INSERT INTO partner_bank_details (account_id, account_type, upi_id, account_status)
  VALUES (v_account_id, v_type, v_upi, 'pending')
  ON CONFLICT (account_id) DO UPDATE SET
    account_type = v_type,
    upi_id = v_upi,
    updated_at = now()
  RETURNING * INTO result_row;

  FOR store_row IN SELECT * FROM partners p WHERE p.account_id = v_account_id LOOP
    INSERT INTO partner_kyc_details (partner_id, account_id, account_type, upi_id)
    VALUES (store_row.id, v_account_id, v_type, v_upi)
    ON CONFLICT ON CONSTRAINT partner_kyc_details_partner_id_key DO UPDATE SET
      account_type = v_type,
      upi_id = v_upi;
  END LOOP;

  RETURN row_to_json(result_row);
END;
$$;

-- 5) ADMIN: full bank save (with account_type + upi_id)
DROP FUNCTION IF EXISTS upsert_partner_bank_account(TEXT, UUID, TEXT, TEXT, TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS upsert_partner_bank_account(TEXT, UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT);

CREATE OR REPLACE FUNCTION upsert_partner_bank_account(
  caller_id TEXT,
  account_id UUID,
  bank_account_holder TEXT,
  bank_name TEXT,
  ifsc_code TEXT,
  account_number TEXT,
  passbook_doc_url TEXT DEFAULT NULL,
  account_type TEXT DEFAULT 'savings',
  upi_id TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_account_id UUID := upsert_partner_bank_account.account_id;
  result_row partner_bank_details%ROWTYPE;
BEGIN
  PERFORM assert_admin_partner_access(caller_id);
  IF NOT EXISTS (SELECT 1 FROM partner_accounts a WHERE a.id = v_account_id) THEN
    RAISE EXCEPTION 'Partner account not found';
  END IF;

  INSERT INTO partner_bank_details (
    account_id, bank_account_holder, bank_name, ifsc_code, account_number,
    passbook_doc_url, account_type, upi_id, account_status
  )
  VALUES (
    v_account_id,
    nullif(trim(bank_account_holder), ''),
    nullif(trim(bank_name), ''),
    nullif(trim(upper(ifsc_code)), ''),
    nullif(trim(account_number), ''),
    nullif(trim(passbook_doc_url), ''),
    COALESCE(nullif(trim(account_type), ''), 'savings'),
    nullif(trim(upi_id), ''),
    'pending'
  )
  ON CONFLICT (account_id) DO UPDATE SET
    bank_account_holder = COALESCE(EXCLUDED.bank_account_holder, partner_bank_details.bank_account_holder),
    bank_name = COALESCE(EXCLUDED.bank_name, partner_bank_details.bank_name),
    ifsc_code = COALESCE(EXCLUDED.ifsc_code, partner_bank_details.ifsc_code),
    account_number = COALESCE(EXCLUDED.account_number, partner_bank_details.account_number),
    passbook_doc_url = COALESCE(EXCLUDED.passbook_doc_url, partner_bank_details.passbook_doc_url),
    account_type = COALESCE(nullif(trim(EXCLUDED.account_type), ''), partner_bank_details.account_type),
    upi_id = EXCLUDED.upi_id,
    account_status = 'pending',
    updated_at = now()
  RETURNING * INTO result_row;

  RETURN row_to_json(result_row);
END;
$$;

CREATE OR REPLACE FUNCTION patch_partner_bank_account_extras(
  caller_id TEXT,
  account_id UUID,
  account_type TEXT DEFAULT 'savings',
  upi_id TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN save_partner_bank_meta_admin(caller_id, account_id, account_type, upi_id);
END;
$$;

CREATE OR REPLACE FUNCTION get_partner_bank_account(
  caller_id TEXT,
  account_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM assert_admin_partner_access(caller_id);
  RETURN (
    SELECT row_to_json(t) FROM (
      SELECT
        b.account_id,
        b.bank_account_holder,
        b.bank_name,
        b.ifsc_code,
        b.account_number,
        b.account_type,
        b.upi_id,
        b.passbook_doc_url,
        b.account_status,
        b.updated_at
      FROM partner_bank_details b
      WHERE b.account_id = get_partner_bank_account.account_id
    ) t
  );
END;
$$;

-- 6) ADMIN list (one row per partner login)
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
        a.owner_name,
        a.phone,
        a.email,
        a.is_active,
        a.created_at,
        (SELECT count(*)::int FROM partners p WHERE p.account_id = a.id) AS store_count,
        (SELECT p.primary_image FROM partners p WHERE p.account_id = a.id
         ORDER BY p.created_at DESC LIMIT 1) AS primary_image,
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

-- 7) GRANTS
GRANT EXECUTE ON FUNCTION save_partner_bank_details(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION get_partner_bank_details(UUID, TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION save_partner_bank_meta_admin(TEXT, UUID, TEXT, TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION save_partner_bank_meta(UUID, TEXT, TEXT, TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION upsert_partner_bank_account(TEXT, UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION patch_partner_bank_account_extras(TEXT, UUID, TEXT, TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION get_partner_bank_account(TEXT, UUID) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION list_partner_bank_accounts(TEXT) TO anon, authenticated, service_role;

NOTIFY pgrst, 'reload schema';

-- 8) CHECK: see saved data (run separately after saving from app)
-- SELECT * FROM partner_bank_details ORDER BY updated_at DESC;
