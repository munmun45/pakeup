-- Return aggregated KYC status from all partner stores on login.

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

GRANT EXECUTE ON FUNCTION verify_partner(TEXT, TEXT) TO anon, authenticated, service_role;

NOTIFY pgrst, 'reload schema';
