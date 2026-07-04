-- Email + alternate OTP channels; OTP tokens optional until SMS/email API connected

ALTER TABLE partner_otp_verifications
  DROP CONSTRAINT IF EXISTS partner_otp_verifications_channel_check;

ALTER TABLE partner_otp_verifications
  ADD CONSTRAINT partner_otp_verifications_channel_check
  CHECK (channel IN ('mobile', 'whatsapp', 'email', 'alternate'));

CREATE OR REPLACE FUNCTION send_partner_otp(
  caller_id TEXT,
  phone     TEXT,
  channel   TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_contact TEXT := nullif(trim(send_partner_otp.phone), '');
  v_channel TEXT := lower(trim(send_partner_otp.channel));
  v_code    TEXT;
  v_last    TIMESTAMPTZ;
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  IF v_contact IS NULL THEN
    RAISE EXCEPTION 'Contact value is required';
  END IF;

  IF v_channel IN ('mobile', 'whatsapp', 'alternate') THEN
    IF length(v_contact) <> 10 THEN
      RAISE EXCEPTION 'Phone must be 10 digits';
    END IF;
  ELSIF v_channel = 'email' THEN
    IF v_contact !~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' THEN
      RAISE EXCEPTION 'Enter a valid email address';
    END IF;
  ELSE
    RAISE EXCEPTION 'Invalid OTP channel';
  END IF;

  SELECT o.created_at INTO v_last
  FROM partner_otp_verifications o
  WHERE o.admin_id = caller_id
    AND o.phone = v_contact
    AND o.channel = v_channel
  ORDER BY o.created_at DESC
  LIMIT 1;

  IF v_last IS NOT NULL AND v_last > now() - interval '60 seconds' THEN
    RETURN json_build_object(
      'sent', false,
      'retry_after', greatest(
        1,
        60 - extract(epoch FROM (now() - v_last))::int
      ),
      'message', 'Please wait before requesting another OTP'
    );
  END IF;

  v_code := lpad((floor(random() * 1000000))::int::text, 6, '0');

  INSERT INTO partner_otp_verifications (
    admin_id, phone, channel, otp_code, expires_at
  ) VALUES (
    caller_id, v_contact, v_channel, v_code, now() + interval '5 minutes'
  );

  RETURN json_build_object(
    'sent', true,
    'retry_after', 60,
    'debug_otp', v_code
  );
END;
$$;

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

  UPDATE partner_accounts SET
    owner_name = v_owner_name,
    phone = v_phone,
    email = v_email,
    whatsapp = v_whatsapp,
    alternate_phone = v_alternate_phone,
    login_id = v_phone,
    pass = CASE WHEN v_login_pass IS NOT NULL THEN v_login_pass ELSE pass END
  WHERE id = v_account_id
  RETURNING * INTO updated_row;

  UPDATE partners SET
    owner_name = v_owner_name,
    phone = v_phone,
    email = v_email,
    whatsapp = v_whatsapp,
    alternate_phone = v_alternate_phone
  WHERE account_id = v_account_id;

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
