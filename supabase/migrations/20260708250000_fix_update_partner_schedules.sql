-- Fix: single update_partner overload accepting both account_id and schedules

DROP FUNCTION IF EXISTS update_partner(
  TEXT, UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, TEXT, UUID
);

DROP FUNCTION IF EXISTS update_partner(
  TEXT, UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, TEXT, JSONB
);

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
  notes             TEXT DEFAULT NULL,
  account_id        UUID DEFAULT NULL,
  schedules         JSONB DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_partner_id       UUID := update_partner.partner_id;
  v_business_name    TEXT := trim(update_partner.business_name);
  v_owner_name       TEXT := trim(update_partner.owner_name);
  v_phone            TEXT := nullif(trim(update_partner.phone), '');
  v_email            TEXT := nullif(trim(update_partner.email), '');
  v_whatsapp         TEXT := nullif(trim(update_partner.whatsapp), '');
  v_alternate_phone  TEXT := nullif(trim(update_partner.alternate_phone), '');
  v_city             TEXT := nullif(trim(update_partner.city), '');
  v_state            TEXT := nullif(trim(update_partner.state), '');
  v_pincode          TEXT := nullif(trim(update_partner.pincode), '');
  v_category         TEXT := coalesce(nullif(trim(update_partner.category), ''), 'salon');
  v_address_line     TEXT := nullif(trim(update_partner.address_line), '');
  v_description      TEXT := nullif(trim(update_partner.description), '');
  v_gst_number       TEXT := nullif(trim(update_partner.gst_number), '');
  v_website          TEXT := nullif(trim(update_partner.website), '');
  v_google_map_embed TEXT := nullif(trim(update_partner.google_map_embed), '');
  v_latitude         DOUBLE PRECISION := update_partner.latitude;
  v_longitude        DOUBLE PRECISION := update_partner.longitude;
  v_notes            TEXT := nullif(trim(update_partner.notes), '');
  v_account_id       UUID;
  updated_row        partners%ROWTYPE;
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  IF v_business_name = '' OR v_owner_name = '' THEN
    RAISE EXCEPTION 'Business name and owner name are required';
  END IF;

  SELECT p.account_id INTO v_account_id
  FROM partners p
  WHERE p.id = v_partner_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Partner not found';
  END IF;

  UPDATE partners SET
    business_name = v_business_name,
    owner_name = v_owner_name,
    phone = v_phone,
    email = v_email,
    whatsapp = v_whatsapp,
    alternate_phone = v_alternate_phone,
    city = v_city,
    state = v_state,
    pincode = v_pincode,
    category = v_category,
    address_line = v_address_line,
    description = v_description,
    gst_number = v_gst_number,
    website = v_website,
    google_map_embed = v_google_map_embed,
    latitude = v_latitude,
    longitude = v_longitude,
    notes = v_notes
  WHERE id = v_partner_id
  RETURNING * INTO updated_row;

  IF schedules IS NOT NULL THEN
    PERFORM save_partner_schedules(updated_row.id, schedules);
  END IF;

  IF v_account_id IS NOT NULL THEN
    UPDATE partner_accounts pa SET
      owner_name = v_owner_name,
      phone = coalesce(v_phone, pa.phone),
      email = v_email,
      whatsapp = v_whatsapp,
      alternate_phone = v_alternate_phone
    WHERE pa.id = v_account_id;
  END IF;

  RETURN row_to_json(updated_row);
END;
$$;

GRANT EXECUTE ON FUNCTION update_partner(
  TEXT, UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, TEXT, UUID, JSONB
) TO anon, authenticated, service_role;

NOTIFY pgrst, 'reload schema';
