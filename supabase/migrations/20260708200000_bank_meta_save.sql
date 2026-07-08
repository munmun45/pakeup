-- Persist Account Type + UPI on partner_bank_details and partner_kyc_details.

ALTER TABLE partner_kyc_details
  ADD COLUMN IF NOT EXISTS account_type TEXT DEFAULT 'savings',
  ADD COLUMN IF NOT EXISTS upi_id TEXT;

ALTER TABLE partner_bank_details
  ADD COLUMN IF NOT EXISTS account_type TEXT NOT NULL DEFAULT 'savings',
  ADD COLUMN IF NOT EXISTS upi_id TEXT;

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
  v_type       TEXT := COALESCE(nullif(trim(account_type), ''), 'savings');
  v_upi        TEXT := nullif(trim(upi_id), '');
  store_row    partners%ROWTYPE;
  result_row   partner_bank_details%ROWTYPE;
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  IF NOT EXISTS (SELECT 1 FROM partner_accounts a WHERE a.id = v_account_id) THEN
    RAISE EXCEPTION 'Partner account not found';
  END IF;

  INSERT INTO partner_bank_details (account_id, account_type, upi_id, account_status)
  VALUES (v_account_id, v_type, v_upi, 'pending')
  ON CONFLICT (account_id) DO UPDATE SET
    account_type = v_type,
    upi_id = v_upi
  RETURNING * INTO result_row;

  FOR store_row IN
    SELECT * FROM partners p WHERE p.account_id = v_account_id
  LOOP
    INSERT INTO partner_kyc_details (partner_id, account_id, account_type, upi_id)
    VALUES (store_row.id, v_account_id, v_type, v_upi)
    ON CONFLICT ON CONSTRAINT partner_kyc_details_partner_id_key DO UPDATE SET
      account_type = v_type,
      upi_id = v_upi;
  END LOOP;

  RETURN row_to_json(result_row);
END;
$$;

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
  v_type       TEXT := COALESCE(nullif(trim(account_type), ''), 'savings');
  v_upi        TEXT := nullif(trim(upi_id), '');
  store_row    partners%ROWTYPE;
  result_row   partner_bank_details%ROWTYPE;
BEGIN
  PERFORM assert_partner_account_access(v_account_id, p_login_pass);

  INSERT INTO partner_bank_details (account_id, account_type, upi_id, account_status)
  VALUES (v_account_id, v_type, v_upi, 'pending')
  ON CONFLICT (account_id) DO UPDATE SET
    account_type = v_type,
    upi_id = v_upi
  RETURNING * INTO result_row;

  FOR store_row IN
    SELECT * FROM partners p WHERE p.account_id = v_account_id
  LOOP
    INSERT INTO partner_kyc_details (partner_id, account_id, account_type, upi_id)
    VALUES (store_row.id, v_account_id, v_type, v_upi)
    ON CONFLICT ON CONSTRAINT partner_kyc_details_partner_id_key DO UPDATE SET
      account_type = v_type,
      upi_id = v_upi;
  END LOOP;

  RETURN row_to_json(result_row);
END;
$$;

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
    account_type = COALESCE(nullif(trim(EXCLUDED.account_type), ''), partner_bank_details.account_type),
    upi_id = EXCLUDED.upi_id,
    account_status = 'pending'
  RETURNING * INTO result_row;

  RETURN row_to_json(result_row);
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
DECLARE
  v_account_id UUID := get_partner_bank_account.account_id;
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  RETURN (
    SELECT row_to_json(t)
    FROM (
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
      WHERE b.account_id = v_account_id
    ) t
  );
END;
$$;

GRANT EXECUTE ON FUNCTION save_partner_bank_meta_admin(TEXT, UUID, TEXT, TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION save_partner_bank_meta(UUID, TEXT, TEXT, TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION upsert_partner_bank_account(TEXT, UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION get_partner_bank_account(TEXT, UUID) TO anon, authenticated, service_role;

NOTIFY pgrst, 'reload schema';
