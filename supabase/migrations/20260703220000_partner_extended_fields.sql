-- Extended partner fields: description, location, map embed, business details

ALTER TABLE partners ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE partners ADD COLUMN IF NOT EXISTS state TEXT;
ALTER TABLE partners ADD COLUMN IF NOT EXISTS pincode TEXT;
ALTER TABLE partners ADD COLUMN IF NOT EXISTS gst_number TEXT;
ALTER TABLE partners ADD COLUMN IF NOT EXISTS website TEXT;
ALTER TABLE partners ADD COLUMN IF NOT EXISTS google_map_embed TEXT;
ALTER TABLE partners ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION;
ALTER TABLE partners ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;

CREATE OR REPLACE FUNCTION list_partners(caller_id TEXT)
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
        id,
        business_name,
        owner_name,
        phone,
        email,
        city,
        state,
        pincode,
        category,
        address_line,
        description,
        gst_number,
        website,
        google_map_embed,
        latitude,
        longitude,
        notes,
        is_active,
        kyc_status,
        created_at
      FROM partners
    ) t
  );
END;
$$;

DROP FUNCTION IF EXISTS create_partner(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT);

CREATE OR REPLACE FUNCTION create_partner(
  caller_id         TEXT,
  business_name     TEXT,
  owner_name        TEXT,
  phone             TEXT DEFAULT NULL,
  email             TEXT DEFAULT NULL,
  city              TEXT DEFAULT NULL,
  state             TEXT DEFAULT NULL,
  pincode           TEXT DEFAULT NULL,
  category          TEXT DEFAULT 'salon',
  address_line      TEXT DEFAULT NULL,
  description       TEXT DEFAULT NULL,
  gst_number        TEXT DEFAULT NULL,
  website           TEXT DEFAULT NULL,
  google_map_embed  TEXT DEFAULT NULL,
  latitude          DOUBLE PRECISION DEFAULT NULL,
  longitude         DOUBLE PRECISION DEFAULT NULL,
  notes             TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  new_row partners%ROWTYPE;
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  IF trim(business_name) = '' OR trim(owner_name) = '' THEN
    RAISE EXCEPTION 'Business name and owner name are required';
  END IF;

  INSERT INTO partners (
    business_name, owner_name, phone, email, city, state, pincode,
    category, address_line, description, gst_number, website,
    google_map_embed, latitude, longitude, notes
  ) VALUES (
    trim(business_name),
    trim(owner_name),
    nullif(trim(phone), ''),
    nullif(trim(email), ''),
    nullif(trim(city), ''),
    nullif(trim(state), ''),
    nullif(trim(pincode), ''),
    coalesce(nullif(trim(category), ''), 'salon'),
    nullif(trim(address_line), ''),
    nullif(trim(description), ''),
    nullif(trim(gst_number), ''),
    nullif(trim(website), ''),
    nullif(trim(google_map_embed), ''),
    create_partner.latitude,
    create_partner.longitude,
    nullif(trim(notes), '')
  )
  RETURNING * INTO new_row;

  RETURN row_to_json(new_row);
END;
$$;

DROP FUNCTION IF EXISTS update_partner(TEXT, UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT);

CREATE OR REPLACE FUNCTION update_partner(
  caller_id         TEXT,
  partner_id        UUID,
  business_name     TEXT,
  owner_name        TEXT,
  phone             TEXT DEFAULT NULL,
  email             TEXT DEFAULT NULL,
  city              TEXT DEFAULT NULL,
  state             TEXT DEFAULT NULL,
  pincode           TEXT DEFAULT NULL,
  category          TEXT DEFAULT 'salon',
  address_line      TEXT DEFAULT NULL,
  description       TEXT DEFAULT NULL,
  gst_number        TEXT DEFAULT NULL,
  website           TEXT DEFAULT NULL,
  google_map_embed  TEXT DEFAULT NULL,
  latitude          DOUBLE PRECISION DEFAULT NULL,
  longitude         DOUBLE PRECISION DEFAULT NULL,
  notes             TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  updated_row partners%ROWTYPE;
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  IF trim(business_name) = '' OR trim(owner_name) = '' THEN
    RAISE EXCEPTION 'Business name and owner name are required';
  END IF;

  UPDATE partners SET
    business_name = trim(business_name),
    owner_name = trim(owner_name),
    phone = nullif(trim(phone), ''),
    email = nullif(trim(email), ''),
    city = nullif(trim(city), ''),
    state = nullif(trim(state), ''),
    pincode = nullif(trim(pincode), ''),
    category = coalesce(nullif(trim(category), ''), 'salon'),
    address_line = nullif(trim(address_line), ''),
    description = nullif(trim(description), ''),
    gst_number = nullif(trim(gst_number), ''),
    website = nullif(trim(website), ''),
    google_map_embed = nullif(trim(google_map_embed), ''),
    latitude = update_partner.latitude,
    longitude = update_partner.longitude,
    notes = nullif(trim(notes), '')
  WHERE id = partner_id
  RETURNING * INTO updated_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Partner not found';
  END IF;

  RETURN row_to_json(updated_row);
END;
$$;

GRANT EXECUTE ON FUNCTION create_partner(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION update_partner(TEXT, UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, TEXT) TO anon, authenticated, service_role;
