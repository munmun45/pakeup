-- Partner login uses phone number as login_id

CREATE OR REPLACE FUNCTION verify_partner(login_id TEXT, login_pass TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_login_id TEXT := trim(verify_partner.login_id);
  v_login_pass TEXT := trim(verify_partner.login_pass);
  partner_row partners%ROWTYPE;
BEGIN
  IF v_login_id = '' OR v_login_pass = '' THEN
    RETURN NULL;
  END IF;

  SELECT * INTO partner_row
  FROM partners p
  WHERE (p.login_id = v_login_id OR p.phone = v_login_id)
    AND p.pass = v_login_pass;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  IF NOT partner_row.is_active THEN
    RETURN json_build_object('error', 'deactivated');
  END IF;

  IF partner_row.pass IS NULL OR trim(partner_row.pass) = '' THEN
    RETURN json_build_object('error', 'no_password');
  END IF;

  RETURN json_build_object(
    'id', partner_row.id,
    'business_name', partner_row.business_name,
    'owner_name', partner_row.owner_name,
    'phone', partner_row.phone,
    'email', partner_row.email,
    'city', partner_row.city,
    'category', partner_row.category,
    'is_active', partner_row.is_active,
    'kyc_status', partner_row.kyc_status,
    'login_id', partner_row.login_id,
    'created_at', partner_row.created_at
  );
END;
$$;

CREATE OR REPLACE FUNCTION register_partner(
  business_name TEXT,
  owner_name TEXT,
  login_id TEXT,
  login_pass TEXT,
  phone TEXT DEFAULT NULL,
  email TEXT DEFAULT NULL,
  city TEXT DEFAULT NULL,
  category TEXT DEFAULT 'salon'
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_business_name TEXT := trim(register_partner.business_name);
  v_owner_name TEXT := trim(register_partner.owner_name);
  v_login_pass TEXT := trim(register_partner.login_pass);
  v_phone TEXT := NULLIF(trim(register_partner.phone), '');
  v_email TEXT := NULLIF(trim(register_partner.email), '');
  v_city TEXT := NULLIF(trim(register_partner.city), '');
  v_category TEXT := COALESCE(NULLIF(trim(register_partner.category), ''), 'salon');
  v_login_id TEXT;
  new_row partners%ROWTYPE;
BEGIN
  IF v_business_name = '' OR v_owner_name = '' THEN
    RAISE EXCEPTION 'Business name and owner name are required';
  END IF;

  IF v_phone IS NULL THEN
    RAISE EXCEPTION 'Phone number is required';
  END IF;

  IF length(v_phone) <> 10 THEN
    RAISE EXCEPTION 'Phone must be 10 digits';
  END IF;

  v_login_id := v_phone;

  IF v_login_pass = '' OR length(v_login_pass) < 4 THEN
    RAISE EXCEPTION 'Password must be at least 4 characters';
  END IF;

  IF EXISTS (
    SELECT 1 FROM partners p
    WHERE p.login_id = v_login_id OR p.phone = v_phone
  ) THEN
    RAISE EXCEPTION 'Phone number already registered';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM partner_categories pc
    WHERE pc.slug = v_category AND pc.is_active
  ) THEN
    v_category := 'salon';
  END IF;

  INSERT INTO partners (
    business_name,
    owner_name,
    phone,
    email,
    city,
    category,
    login_id,
    pass,
    is_active,
    kyc_status
  ) VALUES (
    v_business_name,
    v_owner_name,
    v_phone,
    v_email,
    v_city,
    v_category,
    v_login_id,
    v_login_pass,
    true,
    'pending'
  )
  RETURNING * INTO new_row;

  RETURN json_build_object(
    'id', new_row.id,
    'business_name', new_row.business_name,
    'owner_name', new_row.owner_name,
    'phone', new_row.phone,
    'email', new_row.email,
    'city', new_row.city,
    'category', new_row.category,
    'is_active', new_row.is_active,
    'kyc_status', new_row.kyc_status,
    'login_id', new_row.login_id,
    'created_at', new_row.created_at
  );
END;
$$;
