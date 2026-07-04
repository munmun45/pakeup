-- Fix ambiguous account_id in set_partner_account_active (and related updates)

CREATE OR REPLACE FUNCTION set_partner_account_active(
  caller_id  TEXT,
  account_id UUID,
  active     BOOLEAN
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_account_id UUID := set_partner_account_active.account_id;
  v_active     BOOLEAN := set_partner_account_active.active;
  updated_row  partner_accounts%ROWTYPE;
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  UPDATE partner_accounts a
  SET is_active = v_active
  WHERE a.id = v_account_id
  RETURNING * INTO updated_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Partner account not found';
  END IF;

  UPDATE partners p
  SET is_active = v_active
  WHERE p.account_id = v_account_id;

  RETURN json_build_object(
    'id', updated_row.id,
    'is_active', updated_row.is_active
  );
END;
$$;

CREATE OR REPLACE FUNCTION update_partner_account(
  caller_id                   TEXT,
  account_id                  UUID,
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
  v_account_id      UUID := update_partner_account.account_id;
  v_owner_name      TEXT := trim(update_partner_account.owner_name);
  v_phone           TEXT := nullif(trim(update_partner_account.phone), '');
  v_email           TEXT := nullif(trim(update_partner_account.email), '');
  v_whatsapp        TEXT := nullif(trim(update_partner_account.whatsapp), '');
  v_alternate_phone TEXT := nullif(trim(update_partner_account.alternate_phone), '');
  v_login_pass      TEXT := nullif(trim(update_partner_account.login_pass), '');
  old_row           partner_accounts%ROWTYPE;
  updated_row       partner_accounts%ROWTYPE;
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  SELECT * INTO old_row FROM partner_accounts a WHERE a.id = v_account_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Partner account not found';
  END IF;

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

  IF v_phone <> coalesce(old_row.phone, '') AND phone_verification_token IS NOT NULL THEN
    PERFORM consume_partner_otp_token(
      phone_verification_token, v_phone, 'mobile', caller_id
    );
  END IF;

  IF v_whatsapp <> coalesce(old_row.whatsapp, '') AND whatsapp_verification_token IS NOT NULL THEN
    PERFORM consume_partner_otp_token(
      whatsapp_verification_token, v_whatsapp, 'whatsapp', caller_id
    );
  END IF;

  IF EXISTS (
    SELECT 1 FROM partner_accounts a
    WHERE (a.phone = v_phone OR a.login_id = v_phone)
      AND a.id <> v_account_id
  ) THEN
    RAISE EXCEPTION 'Phone number already registered';
  END IF;

  IF v_login_pass IS NOT NULL AND length(v_login_pass) < 4 THEN
    RAISE EXCEPTION 'Password must be at least 4 characters';
  END IF;

  UPDATE partner_accounts a SET
    owner_name = v_owner_name,
    phone = v_phone,
    email = v_email,
    whatsapp = v_whatsapp,
    alternate_phone = v_alternate_phone,
    login_id = v_phone,
    pass = CASE WHEN v_login_pass IS NOT NULL THEN v_login_pass ELSE a.pass END
  WHERE a.id = v_account_id
  RETURNING * INTO updated_row;

  UPDATE partners p SET
    owner_name = v_owner_name,
    phone = v_phone,
    email = v_email,
    whatsapp = v_whatsapp,
    alternate_phone = v_alternate_phone
  WHERE p.account_id = v_account_id;

  RETURN json_build_object(
    'id', updated_row.id,
    'owner_name', updated_row.owner_name,
    'phone', updated_row.phone,
    'email', updated_row.email,
    'whatsapp', updated_row.whatsapp,
    'alternate_phone', updated_row.alternate_phone,
    'login_id', updated_row.login_id,
    'has_password', updated_row.pass IS NOT NULL AND trim(updated_row.pass) <> '',
    'is_active', updated_row.is_active,
    'store_count', (
      SELECT count(*)::int FROM partners p WHERE p.account_id = updated_row.id
    ),
    'created_at', updated_row.created_at
  );
END;
$$;

GRANT EXECUTE ON FUNCTION set_partner_account_active(TEXT, UUID, BOOLEAN)
  TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION update_partner_account(TEXT, UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, UUID, UUID)
  TO anon, authenticated, service_role;
