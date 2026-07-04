-- Extra contact fields for partners

ALTER TABLE partners ADD COLUMN IF NOT EXISTS whatsapp TEXT;
ALTER TABLE partners ADD COLUMN IF NOT EXISTS alternate_phone TEXT;

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
        p.id,
        p.business_name,
        p.owner_name,
        p.phone,
        p.email,
        p.whatsapp,
        p.alternate_phone,
        p.city,
        p.state,
        p.pincode,
        p.category,
        coalesce(pc.name, p.category) AS category_name,
        p.address_line,
        p.description,
        p.gst_number,
        p.website,
        p.google_map_embed,
        p.latitude,
        p.longitude,
        p.notes,
        p.is_active,
        p.kyc_status,
        p.created_at
      FROM partners p
      LEFT JOIN partner_categories pc ON pc.slug = p.category
    ) t
  );
END;
$$;

DROP FUNCTION IF EXISTS create_partner(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, TEXT);

CREATE OR REPLACE FUNCTION create_partner(
  caller_id         TEXT,
  business_name     TEXT,
  owner_name        TEXT,
  phone             TEXT DEFAULT NULL,
  email             TEXT DEFAULT NULL,
  whatsapp          TEXT DEFAULT NULL,
  alternate_phone   TEXT DEFAULT NULL,
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
  v_business_name    TEXT := create_partner.business_name;
  v_owner_name       TEXT := create_partner.owner_name;
  v_phone            TEXT := create_partner.phone;
  v_email            TEXT := create_partner.email;
  v_whatsapp         TEXT := create_partner.whatsapp;
  v_alternate_phone  TEXT := create_partner.alternate_phone;
  v_city             TEXT := create_partner.city;
  v_state            TEXT := create_partner.state;
  v_pincode          TEXT := create_partner.pincode;
  v_category         TEXT := create_partner.category;
  v_address_line     TEXT := create_partner.address_line;
  v_description      TEXT := create_partner.description;
  v_gst_number       TEXT := create_partner.gst_number;
  v_website          TEXT := create_partner.website;
  v_google_map_embed TEXT := create_partner.google_map_embed;
  v_latitude         DOUBLE PRECISION := create_partner.latitude;
  v_longitude        DOUBLE PRECISION := create_partner.longitude;
  v_notes            TEXT := create_partner.notes;
  new_row partners%ROWTYPE;
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  IF trim(v_business_name) = '' OR trim(v_owner_name) = '' THEN
    RAISE EXCEPTION 'Business name and owner name are required';
  END IF;

  INSERT INTO partners (
    business_name, owner_name, phone, email, whatsapp, alternate_phone,
    city, state, pincode, category, address_line, description, gst_number,
    website, google_map_embed, latitude, longitude, notes
  ) VALUES (
    trim(v_business_name),
    trim(v_owner_name),
    nullif(trim(v_phone), ''),
    nullif(trim(v_email), ''),
    nullif(trim(v_whatsapp), ''),
    nullif(trim(v_alternate_phone), ''),
    nullif(trim(v_city), ''),
    nullif(trim(v_state), ''),
    nullif(trim(v_pincode), ''),
    coalesce(nullif(trim(v_category), ''), 'salon'),
    nullif(trim(v_address_line), ''),
    nullif(trim(v_description), ''),
    nullif(trim(v_gst_number), ''),
    nullif(trim(v_website), ''),
    nullif(trim(v_google_map_embed), ''),
    v_latitude,
    v_longitude,
    nullif(trim(v_notes), '')
  )
  RETURNING * INTO new_row;

  RETURN row_to_json(new_row);
END;
$$;

DROP FUNCTION IF EXISTS update_partner(TEXT, UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, TEXT);

CREATE OR REPLACE FUNCTION update_partner(
  caller_id         TEXT,
  partner_id        UUID,
  business_name     TEXT,
  owner_name        TEXT,
  phone             TEXT DEFAULT NULL,
  email             TEXT DEFAULT NULL,
  whatsapp          TEXT DEFAULT NULL,
  alternate_phone   TEXT DEFAULT NULL,
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
  v_partner_id       UUID := update_partner.partner_id;
  v_business_name    TEXT := update_partner.business_name;
  v_owner_name       TEXT := update_partner.owner_name;
  v_phone            TEXT := update_partner.phone;
  v_email            TEXT := update_partner.email;
  v_whatsapp         TEXT := update_partner.whatsapp;
  v_alternate_phone  TEXT := update_partner.alternate_phone;
  v_city             TEXT := update_partner.city;
  v_state            TEXT := update_partner.state;
  v_pincode          TEXT := update_partner.pincode;
  v_category         TEXT := update_partner.category;
  v_address_line     TEXT := update_partner.address_line;
  v_description      TEXT := update_partner.description;
  v_gst_number       TEXT := update_partner.gst_number;
  v_website          TEXT := update_partner.website;
  v_google_map_embed TEXT := update_partner.google_map_embed;
  v_latitude         DOUBLE PRECISION := update_partner.latitude;
  v_longitude        DOUBLE PRECISION := update_partner.longitude;
  v_notes            TEXT := update_partner.notes;
  updated_row partners%ROWTYPE;
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  IF trim(v_business_name) = '' OR trim(v_owner_name) = '' THEN
    RAISE EXCEPTION 'Business name and owner name are required';
  END IF;

  UPDATE partners SET
    business_name = trim(v_business_name),
    owner_name = trim(v_owner_name),
    phone = nullif(trim(v_phone), ''),
    email = nullif(trim(v_email), ''),
    whatsapp = nullif(trim(v_whatsapp), ''),
    alternate_phone = nullif(trim(v_alternate_phone), ''),
    city = nullif(trim(v_city), ''),
    state = nullif(trim(v_state), ''),
    pincode = nullif(trim(v_pincode), ''),
    category = coalesce(nullif(trim(v_category), ''), 'salon'),
    address_line = nullif(trim(v_address_line), ''),
    description = nullif(trim(v_description), ''),
    gst_number = nullif(trim(v_gst_number), ''),
    website = nullif(trim(v_website), ''),
    google_map_embed = nullif(trim(v_google_map_embed), ''),
    latitude = v_latitude,
    longitude = v_longitude,
    notes = nullif(trim(v_notes), '')
  WHERE id = v_partner_id
  RETURNING * INTO updated_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Partner not found';
  END IF;

  RETURN row_to_json(updated_row);
END;
$$;

GRANT EXECUTE ON FUNCTION create_partner(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION update_partner(TEXT, UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, TEXT) TO anon, authenticated, service_role;
