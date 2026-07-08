-- ============================================================
-- CREATE partner_bank_details table + functions
-- Run in Supabase → SQL Editor → Run (all at once)
-- ============================================================

-- TABLE (1 bank account per partner login id)
CREATE TABLE IF NOT EXISTS partner_bank_details (
  account_id          UUID PRIMARY KEY
                      REFERENCES partner_accounts(id) ON DELETE CASCADE,
  bank_account_holder TEXT,
  bank_name           TEXT,
  ifsc_code           TEXT,
  account_number      TEXT,
  account_type        TEXT NOT NULL DEFAULT 'savings',
  upi_id              TEXT,
  passbook_doc_url    TEXT,
  account_status      TEXT NOT NULL DEFAULT 'pending'
                      CHECK (account_status IN ('pending', 'approved', 'rejected')),
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION touch_partner_bank_details_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at := now(); RETURN NEW; END;
$$;

DROP TRIGGER IF EXISTS partner_bank_details_updated_at ON partner_bank_details;
CREATE TRIGGER partner_bank_details_updated_at
  BEFORE UPDATE ON partner_bank_details
  FOR EACH ROW EXECUTE FUNCTION touch_partner_bank_details_updated_at();

-- ADMIN: save full bank + account_type + upi_id
DROP FUNCTION IF EXISTS upsert_partner_bank_account(TEXT, UUID, TEXT, TEXT, TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS upsert_partner_bank_account(TEXT, UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT);

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
    bank_name           = COALESCE(EXCLUDED.bank_name,           partner_bank_details.bank_name),
    ifsc_code           = COALESCE(EXCLUDED.ifsc_code,           partner_bank_details.ifsc_code),
    account_number      = COALESCE(EXCLUDED.account_number,      partner_bank_details.account_number),
    passbook_doc_url    = COALESCE(EXCLUDED.passbook_doc_url,    partner_bank_details.passbook_doc_url),
    account_type        = COALESCE(nullif(trim(EXCLUDED.account_type), ''), partner_bank_details.account_type),
    upi_id              = EXCLUDED.upi_id,
    account_status      = 'pending',
    updated_at          = now()
  RETURNING * INTO result_row;
  RETURN row_to_json(result_row);
END;
$$;

-- ADMIN: save only account_type + upi_id
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

CREATE OR REPLACE FUNCTION patch_partner_bank_account_extras(
  caller_id TEXT, account_id UUID,
  account_type TEXT DEFAULT 'savings', upi_id TEXT DEFAULT NULL
)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  RETURN save_partner_bank_meta_admin(caller_id, account_id, account_type, upi_id);
END;
$$;

-- ADMIN: get one bank account
CREATE OR REPLACE FUNCTION get_partner_bank_account(caller_id TEXT, account_id UUID)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  PERFORM assert_admin_partner_access(caller_id);
  RETURN (SELECT row_to_json(t) FROM (
    SELECT b.account_id, b.bank_account_holder, b.bank_name, b.ifsc_code, b.account_number,
           b.account_type, b.upi_id, b.passbook_doc_url, b.account_status, b.updated_at
    FROM partner_bank_details b
    WHERE b.account_id = get_partner_bank_account.account_id
  ) t);
END;
$$;

-- ADMIN: list all bank accounts (one per partner login)
CREATE OR REPLACE FUNCTION list_partner_bank_accounts(caller_id TEXT)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  PERFORM assert_admin_partner_access(caller_id);
  RETURN (SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.created_at DESC), '[]'::json)
    FROM (
      SELECT
        a.id AS account_id, a.owner_name, a.phone, a.email, a.is_active, a.created_at,
        (SELECT count(*)::int FROM partners p WHERE p.account_id = a.id) AS store_count,
        (SELECT p.primary_image FROM partners p WHERE p.account_id = a.id
         ORDER BY p.created_at DESC LIMIT 1) AS primary_image,
        COALESCE(b.account_status, 'pending') AS account_status,
        b.bank_account_holder, b.bank_name, b.ifsc_code, b.account_number,
        b.account_type, b.upi_id, b.passbook_doc_url,
        b.updated_at AS account_updated_at
      FROM partner_accounts a
      LEFT JOIN partner_bank_details b ON b.account_id = a.id
    ) t);
END;
$$;

-- MOBILE APP: save bank
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
    bank_name = EXCLUDED.bank_name, ifsc_code = EXCLUDED.ifsc_code,
    account_number = EXCLUDED.account_number,
    account_type = EXCLUDED.account_type, upi_id = EXCLUDED.upi_id,
    account_status = 'pending', updated_at = now()
  RETURNING * INTO result_row;
  RETURN row_to_json(result_row);
END;
$$;

-- MOBILE APP: get bank
CREATE OR REPLACE FUNCTION get_partner_bank_details(p_account_id UUID, p_login_pass TEXT)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  PERFORM assert_partner_account_access(p_account_id, p_login_pass);
  RETURN (SELECT row_to_json(t) FROM (
    SELECT bank_account_holder AS account_name, b.bank_name, b.ifsc_code AS ifsc,
           b.account_number, b.account_type, b.upi_id, b.passbook_doc_url,
           b.account_status, b.updated_at
    FROM partner_bank_details b WHERE b.account_id = p_account_id
  ) t);
END;
$$;

-- MOBILE APP: save account_type + upi only
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
  ON CONFLICT ON CONSTRAINT partner_bank_details_pkey DO UPDATE SET account_type = EXCLUDED.account_type, upi_id = EXCLUDED.upi_id, updated_at = now();
  RETURN (
    SELECT row_to_json(b)
    FROM partner_bank_details b
    WHERE b.account_id = save_partner_bank_meta.partner_id
  );
END;
$$;

CREATE OR REPLACE FUNCTION patch_partner_bank_extras(
  partner_id UUID, p_login_pass TEXT,
  account_type TEXT DEFAULT 'savings', upi_id TEXT DEFAULT NULL
)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  RETURN save_partner_bank_meta(partner_id, p_login_pass, account_type, upi_id);
END;
$$;

-- APPROVE / REJECT bank account
DROP FUNCTION IF EXISTS set_partner_account_status(TEXT, UUID, TEXT);
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
  ON CONFLICT ON CONSTRAINT partner_bank_details_pkey DO UPDATE SET account_status = EXCLUDED.account_status, updated_at = now()
  RETURNING * INTO result_row;
  RETURN row_to_json(result_row);
END;
$$;

-- PERMISSIONS
GRANT EXECUTE ON FUNCTION upsert_partner_bank_account(TEXT,UUID,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION save_partner_bank_meta_admin(TEXT,UUID,TEXT,TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION patch_partner_bank_account_extras(TEXT,UUID,TEXT,TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION get_partner_bank_account(TEXT,UUID) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION list_partner_bank_accounts(TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION save_partner_bank_details(UUID,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION get_partner_bank_details(UUID,TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION save_partner_bank_meta(UUID,TEXT,TEXT,TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION patch_partner_bank_extras(UUID,TEXT,TEXT,TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION set_partner_account_status(TEXT,UUID,TEXT) TO anon, authenticated, service_role;

NOTIFY pgrst, 'reload schema';
