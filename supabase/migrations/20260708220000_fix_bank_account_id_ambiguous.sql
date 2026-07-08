-- Fix remaining ambiguity: ON CONFLICT (account_id) vs function parameter account_id.
-- Use the primary-key constraint name instead of the column name.

CREATE OR REPLACE FUNCTION upsert_partner_bank_account(
  caller_id           TEXT,
  account_id          UUID,
  bank_account_holder TEXT,
  bank_name           TEXT,
  ifsc_code           TEXT,
  account_number      TEXT,
  passbook_doc_url    TEXT    DEFAULT NULL,
  account_type        TEXT    DEFAULT 'savings',
  upi_id              TEXT    DEFAULT NULL
)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE result_row partner_bank_details%ROWTYPE;
BEGIN
  PERFORM assert_admin_partner_access(caller_id);
  INSERT INTO partner_bank_details (
    account_id, bank_account_holder, bank_name, ifsc_code, account_number,
    passbook_doc_url, account_type, upi_id, account_status
  ) VALUES (
    upsert_partner_bank_account.account_id,
    nullif(trim(upsert_partner_bank_account.bank_account_holder), ''),
    nullif(trim(upsert_partner_bank_account.bank_name), ''),
    nullif(trim(upper(upsert_partner_bank_account.ifsc_code)), ''),
    nullif(trim(upsert_partner_bank_account.account_number), ''),
    nullif(trim(upsert_partner_bank_account.passbook_doc_url), ''),
    COALESCE(nullif(trim(upsert_partner_bank_account.account_type), ''), 'savings'),
    nullif(trim(upsert_partner_bank_account.upi_id), ''),
    'pending'
  )
  ON CONFLICT ON CONSTRAINT partner_bank_details_pkey DO UPDATE SET
    bank_account_holder = COALESCE(EXCLUDED.bank_account_holder, partner_bank_details.bank_account_holder),
    bank_name           = COALESCE(EXCLUDED.bank_name, partner_bank_details.bank_name),
    ifsc_code           = COALESCE(EXCLUDED.ifsc_code, partner_bank_details.ifsc_code),
    account_number      = COALESCE(EXCLUDED.account_number, partner_bank_details.account_number),
    passbook_doc_url    = COALESCE(EXCLUDED.passbook_doc_url, partner_bank_details.passbook_doc_url),
    account_type        = COALESCE(nullif(trim(EXCLUDED.account_type), ''), partner_bank_details.account_type),
    upi_id              = EXCLUDED.upi_id,
    account_status      = 'pending',
    updated_at          = now()
  RETURNING * INTO result_row;
  RETURN row_to_json(result_row);
END;
$$;

CREATE OR REPLACE FUNCTION save_partner_bank_meta_admin(
  caller_id    TEXT,
  account_id   UUID,
  account_type TEXT DEFAULT 'savings',
  upi_id       TEXT DEFAULT NULL
)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE result_row partner_bank_details%ROWTYPE;
BEGIN
  PERFORM assert_admin_partner_access(caller_id);
  INSERT INTO partner_bank_details (account_id, account_type, upi_id, account_status)
  VALUES (
    save_partner_bank_meta_admin.account_id,
    COALESCE(nullif(trim(save_partner_bank_meta_admin.account_type), ''), 'savings'),
    nullif(trim(save_partner_bank_meta_admin.upi_id), ''),
    'pending'
  )
  ON CONFLICT ON CONSTRAINT partner_bank_details_pkey DO UPDATE SET
    account_type = COALESCE(nullif(trim(EXCLUDED.account_type), ''), partner_bank_details.account_type),
    upi_id       = EXCLUDED.upi_id,
    updated_at   = now()
  RETURNING * INTO result_row;
  RETURN row_to_json(result_row);
END;
$$;

CREATE OR REPLACE FUNCTION set_partner_account_status(
  caller_id TEXT, account_id UUID, new_status TEXT
)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE result_row partner_bank_details%ROWTYPE;
BEGIN
  PERFORM assert_admin_partner_access(caller_id);
  IF new_status NOT IN ('pending','approved','rejected') THEN
    RAISE EXCEPTION 'Invalid status';
  END IF;
  INSERT INTO partner_bank_details (account_id, account_status)
  VALUES (set_partner_account_status.account_id, set_partner_account_status.new_status)
  ON CONFLICT ON CONSTRAINT partner_bank_details_pkey DO UPDATE SET
    account_status = EXCLUDED.account_status,
    updated_at = now()
  RETURNING * INTO result_row;
  RETURN row_to_json(result_row);
END;
$$;

CREATE OR REPLACE FUNCTION save_partner_bank_details(
  partner_id      UUID,
  account_name    TEXT,
  account_number  TEXT,
  ifsc            TEXT,
  bank_name       TEXT,
  account_type    TEXT DEFAULT 'savings',
  upi_id          TEXT DEFAULT NULL,
  p_login_pass    TEXT DEFAULT NULL
)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE result_row partner_bank_details%ROWTYPE;
BEGIN
  PERFORM assert_partner_account_access(partner_id, p_login_pass);
  INSERT INTO partner_bank_details (
    account_id, bank_account_holder, bank_name, ifsc_code, account_number,
    account_type, upi_id, account_status
  ) VALUES (
    save_partner_bank_details.partner_id,
    nullif(trim(save_partner_bank_details.account_name), ''),
    nullif(trim(save_partner_bank_details.bank_name), ''),
    nullif(trim(upper(save_partner_bank_details.ifsc)), ''),
    nullif(trim(save_partner_bank_details.account_number), ''),
    COALESCE(nullif(trim(save_partner_bank_details.account_type), ''), 'savings'),
    nullif(trim(save_partner_bank_details.upi_id), ''),
    'pending'
  )
  ON CONFLICT ON CONSTRAINT partner_bank_details_pkey DO UPDATE SET
    bank_account_holder = EXCLUDED.bank_account_holder,
    bank_name = EXCLUDED.bank_name,
    ifsc_code = EXCLUDED.ifsc_code,
    account_number = EXCLUDED.account_number,
    account_type = EXCLUDED.account_type,
    upi_id = EXCLUDED.upi_id,
    account_status = 'pending',
    updated_at = now()
  RETURNING * INTO result_row;
  RETURN row_to_json(result_row);
END;
$$;

CREATE OR REPLACE FUNCTION save_partner_bank_meta(
  partner_id UUID, p_login_pass TEXT,
  account_type TEXT DEFAULT 'savings', upi_id TEXT DEFAULT NULL
)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  PERFORM assert_partner_account_access(partner_id, p_login_pass);
  INSERT INTO partner_bank_details (account_id, account_type, upi_id, account_status)
  VALUES (
    save_partner_bank_meta.partner_id,
    COALESCE(nullif(trim(save_partner_bank_meta.account_type), ''), 'savings'),
    nullif(trim(save_partner_bank_meta.upi_id), ''),
    'pending'
  )
  ON CONFLICT ON CONSTRAINT partner_bank_details_pkey DO UPDATE SET
    account_type = EXCLUDED.account_type,
    upi_id = EXCLUDED.upi_id,
    updated_at = now();
  RETURN (
    SELECT row_to_json(b)
    FROM partner_bank_details b
    WHERE b.account_id = save_partner_bank_meta.partner_id
  );
END;
$$;

NOTIFY pgrst, 'reload schema';
