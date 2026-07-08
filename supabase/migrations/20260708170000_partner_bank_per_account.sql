-- Bank account details belong to partner_accounts (one per login), not per store.

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

-- Migrate existing per-store bank data to one row per account (newest KYC row wins).
INSERT INTO partner_bank_details (
  account_id,
  bank_account_holder,
  bank_name,
  ifsc_code,
  account_number,
  passbook_doc_url,
  account_status,
  created_at,
  updated_at
)
SELECT DISTINCT ON (p.account_id)
  p.account_id,
  k.bank_account_holder,
  k.bank_name,
  k.ifsc_code,
  k.account_number,
  k.passbook_doc_url,
  COALESCE(k.account_status, 'pending'),
  COALESCE(k.created_at, now()),
  COALESCE(k.updated_at, now())
FROM partners p
INNER JOIN partner_kyc_details k ON k.partner_id = p.id
WHERE p.account_id IS NOT NULL
ORDER BY p.account_id, k.updated_at DESC NULLS LAST
ON CONFLICT (account_id) DO NOTHING;

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
        b.passbook_doc_url,
        b.updated_at AS account_updated_at
      FROM partner_accounts a
      LEFT JOIN partner_bank_details b ON b.account_id = a.id
    ) t
  );
END;
$$;

DROP FUNCTION IF EXISTS set_partner_account_status(TEXT, UUID, TEXT);

CREATE OR REPLACE FUNCTION set_partner_account_status(
  caller_id TEXT,
  account_id UUID,
  new_status TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_account_id UUID := set_partner_account_status.account_id;
  v_new_status TEXT := set_partner_account_status.new_status;
  result_row partner_bank_details%ROWTYPE;
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  IF v_new_status NOT IN ('pending', 'approved', 'rejected') THEN
    RAISE EXCEPTION 'Invalid account status';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM partner_accounts a WHERE a.id = v_account_id) THEN
    RAISE EXCEPTION 'Partner account not found';
  END IF;

  INSERT INTO partner_bank_details (account_id, account_status)
  VALUES (v_account_id, v_new_status)
  ON CONFLICT (account_id) DO UPDATE SET
    account_status = EXCLUDED.account_status
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

CREATE OR REPLACE FUNCTION upsert_partner_bank_account(
  caller_id TEXT,
  account_id UUID,
  bank_account_holder TEXT,
  bank_name TEXT,
  ifsc_code TEXT,
  account_number TEXT,
  passbook_doc_url TEXT DEFAULT NULL
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
    account_status
  )
  VALUES (
    v_account_id,
    nullif(trim(bank_account_holder), ''),
    nullif(trim(bank_name), ''),
    nullif(trim(upper(ifsc_code)), ''),
    nullif(trim(account_number), ''),
    nullif(trim(passbook_doc_url), ''),
    'pending'
  )
  ON CONFLICT (account_id) DO UPDATE SET
    bank_account_holder = COALESCE(EXCLUDED.bank_account_holder, partner_bank_details.bank_account_holder),
    bank_name = COALESCE(EXCLUDED.bank_name, partner_bank_details.bank_name),
    ifsc_code = COALESCE(EXCLUDED.ifsc_code, partner_bank_details.ifsc_code),
    account_number = COALESCE(EXCLUDED.account_number, partner_bank_details.account_number),
    passbook_doc_url = COALESCE(EXCLUDED.passbook_doc_url, partner_bank_details.passbook_doc_url),
    account_status = 'pending'
  RETURNING * INTO result_row;

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
  result_row partner_bank_details%ROWTYPE;
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

  RETURN row_to_json(result_row);
END;
$$;

GRANT EXECUTE ON FUNCTION list_partner_bank_accounts(TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION set_partner_account_status(TEXT, UUID, TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION get_partner_bank_account(TEXT, UUID) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION upsert_partner_bank_account(TEXT, UUID, TEXT, TEXT, TEXT, TEXT, TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION get_partner_bank_details(UUID, TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION save_partner_bank_details(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) TO anon, authenticated, service_role;

NOTIFY pgrst, 'reload schema';
