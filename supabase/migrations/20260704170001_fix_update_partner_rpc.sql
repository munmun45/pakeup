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
