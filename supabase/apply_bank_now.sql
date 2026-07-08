-- Run this in Supabase SQL Editor if bank save fails on mobile/admin.
-- Safe to run multiple times.

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

CREATE OR REPLACE FUNCTION touch_partner_bank_details_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS partner_bank_details_updated_at ON partner_bank_details;
CREATE TRIGGER partner_bank_details_updated_at
  BEFORE UPDATE ON partner_bank_details
  FOR EACH ROW
  EXECUTE FUNCTION touch_partner_bank_details_updated_at();

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
    account_id,
    bank_account_holder,
    bank_name,
    ifsc_code,
    account_number,
    account_type,
    upi_id,
    account_status
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
    account_status = 'pending'
  RETURNING * INTO result_row;

  FOR store_row IN
    SELECT * FROM partners p WHERE p.account_id = v_account_id
  LOOP
    INSERT INTO partner_kyc_details (
      partner_id,
      account_id,
      bank_account_holder,
      bank_name,
      ifsc_code,
      account_number,
      account_status
    )
    VALUES (
      store_row.id,
      v_account_id,
      result_row.bank_account_holder,
      result_row.bank_name,
      result_row.ifsc_code,
      result_row.account_number,
      'pending'
    )
    ON CONFLICT ON CONSTRAINT partner_kyc_details_partner_id_key DO UPDATE SET
      bank_account_holder = EXCLUDED.bank_account_holder,
      bank_name = EXCLUDED.bank_name,
      ifsc_code = EXCLUDED.ifsc_code,
      account_number = EXCLUDED.account_number,
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
DECLARE
  v_account_id UUID := get_partner_bank_details.p_account_id;
BEGIN
  PERFORM assert_partner_account_access(v_account_id, p_login_pass);

  RETURN (
    SELECT row_to_json(t)
    FROM (
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
      WHERE b.account_id = v_account_id
    ) t
  );
END;
$$;

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
    account_id,
    bank_account_holder,
    bank_name,
    ifsc_code,
    account_number,
    passbook_doc_url,
    account_type,
    upi_id,
    account_status
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
    account_type = COALESCE(EXCLUDED.account_type, partner_bank_details.account_type),
    upi_id = COALESCE(EXCLUDED.upi_id, partner_bank_details.upi_id),
    account_status = 'pending'
  RETURNING * INTO result_row;

  RETURN row_to_json(result_row);
END;
$$;

DROP FUNCTION IF EXISTS upsert_partner_bank_account(TEXT, UUID, TEXT, TEXT, TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS upsert_partner_bank_account(TEXT, UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT);

GRANT EXECUTE ON FUNCTION save_partner_bank_details(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION get_partner_bank_details(UUID, TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION upsert_partner_bank_account(TEXT, UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) TO anon, authenticated, service_role;

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
DECLARE
  v_account_id UUID := patch_partner_bank_account_extras.account_id;
  result_row partner_bank_details%ROWTYPE;
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  IF NOT EXISTS (SELECT 1 FROM partner_accounts a WHERE a.id = v_account_id) THEN
    RAISE EXCEPTION 'Partner account not found';
  END IF;

  INSERT INTO partner_bank_details (account_id, account_type, upi_id, account_status)
  VALUES (
    v_account_id,
    COALESCE(nullif(trim(account_type), ''), 'savings'),
    nullif(trim(upi_id), ''),
    'pending'
  )
  ON CONFLICT (account_id) DO UPDATE SET
    account_type = COALESCE(nullif(trim(EXCLUDED.account_type), ''), partner_bank_details.account_type),
    upi_id = EXCLUDED.upi_id
  RETURNING * INTO result_row;

  RETURN row_to_json(result_row);
END;
$$;

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

GRANT EXECUTE ON FUNCTION patch_partner_bank_account_extras(TEXT, UUID, TEXT, TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION list_partner_bank_accounts(TEXT) TO anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION patch_partner_bank_extras(
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
  v_account_id UUID := patch_partner_bank_extras.partner_id;
  result_row partner_bank_details%ROWTYPE;
BEGIN
  PERFORM assert_partner_account_access(v_account_id, p_login_pass);

  INSERT INTO partner_bank_details (account_id, account_type, upi_id, account_status)
  VALUES (
    v_account_id,
    COALESCE(nullif(trim(account_type), ''), 'savings'),
    nullif(trim(upi_id), ''),
    'pending'
  )
  ON CONFLICT (account_id) DO UPDATE SET
    account_type = COALESCE(nullif(trim(EXCLUDED.account_type), ''), partner_bank_details.account_type),
    upi_id = EXCLUDED.upi_id
  RETURNING * INTO result_row;

  RETURN row_to_json(result_row);
END;
$$;

GRANT EXECUTE ON FUNCTION patch_partner_bank_extras(UUID, TEXT, TEXT, TEXT) TO anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION save_partner_store_bank_legacy(
  partner_id UUID,
  p_login_pass TEXT,
  account_name TEXT,
  account_number TEXT,
  ifsc TEXT,
  bank_name TEXT,
  account_type TEXT DEFAULT 'savings',
  upi_id TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_account_id UUID := save_partner_store_bank_legacy.partner_id;
  store_row      partners%ROWTYPE;
  kyc_row        partner_kyc_details%ROWTYPE;
BEGIN
  PERFORM assert_partner_account_access(v_account_id, p_login_pass);

  IF EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'partner_bank_details'
  ) THEN
    RETURN save_partner_bank_details(
      v_account_id,
      account_name,
      account_number,
      ifsc,
      bank_name,
      account_type,
      upi_id,
      p_login_pass
    );
  END IF;

  FOR store_row IN
    SELECT * FROM partners p WHERE p.account_id = v_account_id
  LOOP
    INSERT INTO partner_kyc_details (
      partner_id,
      account_id,
      bank_account_holder,
      bank_name,
      ifsc_code,
      account_number,
      account_status
    )
    VALUES (
      store_row.id,
      v_account_id,
      nullif(trim(account_name), ''),
      nullif(trim(bank_name), ''),
      nullif(trim(upper(ifsc)), ''),
      nullif(trim(account_number), ''),
      'pending'
    )
    ON CONFLICT ON CONSTRAINT partner_kyc_details_partner_id_key DO UPDATE SET
      bank_account_holder = EXCLUDED.bank_account_holder,
      bank_name = EXCLUDED.bank_name,
      ifsc_code = EXCLUDED.ifsc_code,
      account_number = EXCLUDED.account_number,
      account_status = 'pending'
    RETURNING * INTO kyc_row;
  END LOOP;

  RETURN json_build_object(
    'account_name', nullif(trim(account_name), ''),
    'bank_name', nullif(trim(bank_name), ''),
    'ifsc', nullif(trim(upper(ifsc)), ''),
    'account_number', nullif(trim(account_number), ''),
    'account_type', COALESCE(nullif(trim(account_type), ''), 'savings'),
    'upi_id', nullif(trim(upi_id), ''),
    'account_status', 'pending'
  );
END;
$$;

CREATE OR REPLACE FUNCTION get_partner_store_bank_legacy(
  p_account_id UUID,
  p_login_pass TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_account_id UUID := get_partner_store_bank_legacy.p_account_id;
BEGIN
  PERFORM assert_partner_account_access(v_account_id, p_login_pass);

  IF EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'partner_bank_details'
  ) THEN
    RETURN get_partner_bank_details(v_account_id, p_login_pass);
  END IF;

  RETURN (
    SELECT row_to_json(t)
    FROM (
      SELECT
        k.bank_account_holder AS account_name,
        k.bank_name,
        k.ifsc_code AS ifsc,
        k.account_number,
        'savings'::text AS account_type,
        NULL::text AS upi_id,
        k.passbook_doc_url,
        COALESCE(k.account_status, 'pending') AS account_status,
        k.updated_at
      FROM partner_kyc_details k
      INNER JOIN partners p ON p.id = k.partner_id
      WHERE p.account_id = v_account_id
      ORDER BY k.updated_at DESC NULLS LAST
      LIMIT 1
    ) t
  );
END;
$$;

GRANT EXECUTE ON FUNCTION save_partner_store_bank_legacy(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION get_partner_store_bank_legacy(UUID, TEXT) TO anon, authenticated, service_role;

NOTIFY pgrst, 'reload schema';
