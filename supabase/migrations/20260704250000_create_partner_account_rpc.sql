-- Create parent partner account without a store

CREATE OR REPLACE FUNCTION create_partner_account(
  caller_id         TEXT,
  owner_name        TEXT,
  phone             TEXT DEFAULT NULL,
  email             TEXT DEFAULT NULL,
  whatsapp          TEXT DEFAULT NULL,
  alternate_phone   TEXT DEFAULT NULL,
  login_pass        TEXT DEFAULT NULL
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

  IF v_phone IS NULL THEN
    RAISE EXCEPTION 'Phone number is required';
  END IF;

  IF length(v_phone) <> 10 THEN
    RAISE EXCEPTION 'Phone must be 10 digits';
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
    owner_name,
    phone,
    email,
    whatsapp,
    alternate_phone,
    login_id,
    pass
  ) VALUES (
    v_owner_name,
    v_phone,
    v_email,
    v_whatsapp,
    v_alternate_phone,
    v_phone,
    v_login_pass
  )
  RETURNING * INTO account_row;

  RETURN json_build_object(
    'id', account_row.id,
    'owner_name', account_row.owner_name,
    'phone', account_row.phone,
    'email', account_row.email,
    'whatsapp', account_row.whatsapp,
    'alternate_phone', account_row.alternate_phone,
    'login_id', account_row.login_id,
    'has_password', account_row.pass IS NOT NULL AND trim(account_row.pass) <> '',
    'store_count', 0,
    'created_at', account_row.created_at
  );
END;
$$;

GRANT EXECUTE ON FUNCTION create_partner_account(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT)
  TO anon, authenticated, service_role;
