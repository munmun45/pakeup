-- Add new columns for separate parlour and home visit durations and genders
ALTER TABLE partner_services ADD COLUMN IF NOT EXISTS parlour_duration_minutes INT DEFAULT NULL;
ALTER TABLE partner_services ADD COLUMN IF NOT EXISTS parlour_target_gender TEXT DEFAULT NULL;
ALTER TABLE partner_services ADD COLUMN IF NOT EXISTS home_duration_minutes INT DEFAULT NULL;
ALTER TABLE partner_services ADD COLUMN IF NOT EXISTS home_target_gender TEXT DEFAULT NULL;

-- Migrate existing values
UPDATE partner_services SET
  parlour_duration_minutes = CASE WHEN is_parlour_available THEN duration_minutes ELSE NULL END,
  parlour_target_gender = CASE WHEN is_parlour_available THEN target_gender ELSE NULL END,
  home_duration_minutes = CASE WHEN is_home_available THEN duration_minutes ELSE NULL END,
  home_target_gender = CASE WHEN is_home_available THEN target_gender ELSE NULL END;

-- Drop old function overloads
DROP FUNCTION IF EXISTS create_partner_service(TEXT, UUID, TEXT, TEXT, INT, TEXT, TEXT, DECIMAL, BOOLEAN, DECIMAL, BOOLEAN, DECIMAL, INT, DECIMAL);
DROP FUNCTION IF EXISTS update_partner_service(TEXT, UUID, UUID, TEXT, TEXT, INT, BOOLEAN, TEXT, TEXT, DECIMAL, BOOLEAN, DECIMAL, BOOLEAN, DECIMAL, INT, DECIMAL);

-- Redefine list_partner_services to return all parlour and home columns
CREATE OR REPLACE FUNCTION list_partner_services(caller_id TEXT)
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
        ps.id,
        ps.partner_id,
        p.business_name AS partner_name,
        ps.primary_image,
        ps.images,
        p.primary_image AS partner_primary_image,
        p.images AS partner_images,
        coalesce(a.owner_name, p.owner_name) AS owner_name,
        coalesce(a.phone, p.phone) AS phone,
        ps.name,
        ps.description,
        ps.price,
        ps.discount_price,
        ps.duration_minutes,
        ps.category,
        ps.target_gender,
        ps.service_location,
        ps.free_radius_km,
        ps.per_km_charge,
        ps.is_parlour_available,
        ps.parlour_price,
        ps.parlour_duration_minutes,
        ps.parlour_target_gender,
        ps.is_home_available,
        ps.home_price,
        ps.home_duration_minutes,
        ps.home_target_gender,
        ps.service_image,
        ps.is_featured,
        ps.prep_instructions,
        ps.is_active,
        ps.created_at
      FROM partner_services ps
      JOIN partners p ON p.id = ps.partner_id
      LEFT JOIN partner_accounts a ON a.id = p.account_id
    ) t
  );
END;
$$;

GRANT EXECUTE ON FUNCTION list_partner_services(TEXT) TO anon, authenticated, service_role;

-- Redefine create_partner_service
CREATE OR REPLACE FUNCTION create_partner_service(
  caller_id                TEXT,
  partner_id               UUID,
  service_name             TEXT,
  description              TEXT DEFAULT NULL,
  category                 TEXT DEFAULT 'Others',
  discount_price           DECIMAL DEFAULT NULL,
  is_parlour_available     BOOLEAN DEFAULT TRUE,
  parlour_price            DECIMAL DEFAULT NULL,
  parlour_duration_minutes INT DEFAULT NULL,
  parlour_target_gender    TEXT DEFAULT NULL,
  is_home_available        BOOLEAN DEFAULT FALSE,
  home_price               DECIMAL DEFAULT NULL,
  home_duration_minutes    INT DEFAULT NULL,
  home_target_gender       TEXT DEFAULT NULL,
  free_radius_km           INT DEFAULT 0,
  per_km_charge            DECIMAL DEFAULT 0
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_partner_id               UUID := create_partner_service.partner_id;
  v_service_name             TEXT := create_partner_service.service_name;
  v_description              TEXT := create_partner_service.description;
  v_category                 TEXT := create_partner_service.category;
  v_discount_price           DECIMAL := create_partner_service.discount_price;
  v_is_parlour_available     BOOLEAN := create_partner_service.is_parlour_available;
  v_parlour_price            DECIMAL := create_partner_service.parlour_price;
  v_parlour_duration_minutes INT := create_partner_service.parlour_duration_minutes;
  v_parlour_target_gender    TEXT := create_partner_service.parlour_target_gender;
  v_is_home_available        BOOLEAN := create_partner_service.is_home_available;
  v_home_price               DECIMAL := create_partner_service.home_price;
  v_home_duration_minutes    INT := create_partner_service.home_duration_minutes;
  v_home_target_gender       TEXT := create_partner_service.home_target_gender;
  v_free_radius_km           INT := create_partner_service.free_radius_km;
  v_per_km_charge            DECIMAL := create_partner_service.per_km_charge;
  
  v_price                    DECIMAL;
  v_duration_minutes         INT;
  v_target_gender            TEXT;
  v_service_location         TEXT;
  new_row partner_services%ROWTYPE;
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  IF trim(v_service_name) = '' THEN
    RAISE EXCEPTION 'Service name is required';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM partners WHERE id = v_partner_id) THEN
    RAISE EXCEPTION 'Partner not found';
  END IF;

  -- Determine backward-compatible fallback location, price, duration, gender
  IF v_is_parlour_available AND v_is_home_available THEN
    v_service_location := 'Both';
    v_price := coalesce(v_parlour_price, v_home_price, 0);
    v_duration_minutes := coalesce(v_parlour_duration_minutes, v_home_duration_minutes, 30);
    v_target_gender := coalesce(nullif(trim(v_parlour_target_gender), ''), nullif(trim(v_home_target_gender), ''), 'Unisex');
  ELSIF v_is_home_available THEN
    v_service_location := 'At Home';
    v_price := coalesce(v_home_price, 0);
    v_duration_minutes := coalesce(v_home_duration_minutes, 30);
    v_target_gender := coalesce(nullif(trim(v_home_target_gender), ''), 'Unisex');
  ELSE
    v_service_location := 'At Salon Only';
    v_price := coalesce(v_parlour_price, 0);
    v_duration_minutes := coalesce(v_parlour_duration_minutes, 30);
    v_target_gender := coalesce(nullif(trim(v_parlour_target_gender), ''), 'Unisex');
  END IF;

  INSERT INTO partner_services (
    partner_id, name, description, price, duration_minutes,
    category, target_gender, discount_price, service_location,
    free_radius_km, per_km_charge,
    is_parlour_available, parlour_price, parlour_duration_minutes, parlour_target_gender,
    is_home_available, home_price, home_duration_minutes, home_target_gender
  ) VALUES (
    v_partner_id,
    trim(v_service_name),
    nullif(trim(v_description), ''),
    v_price,
    v_duration_minutes,
    coalesce(nullif(trim(v_category), ''), 'Others'),
    v_target_gender,
    v_discount_price,
    v_service_location,
    coalesce(v_free_radius_km, 0),
    coalesce(v_per_km_charge, 0),
    v_is_parlour_available,
    v_parlour_price,
    v_parlour_duration_minutes,
    coalesce(nullif(trim(v_parlour_target_gender), ''), 'Unisex'),
    v_is_home_available,
    v_home_price,
    v_home_duration_minutes,
    coalesce(nullif(trim(v_home_target_gender), ''), 'Unisex')
  )
  RETURNING * INTO new_row;

  RETURN row_to_json(new_row);
END;
$$;

GRANT EXECUTE ON FUNCTION create_partner_service(TEXT, UUID, TEXT, TEXT, TEXT, DECIMAL, BOOLEAN, DECIMAL, INT, TEXT, BOOLEAN, DECIMAL, INT, TEXT, INT, DECIMAL) TO anon, authenticated, service_role;

-- Redefine update_partner_service
CREATE OR REPLACE FUNCTION update_partner_service(
  caller_id                TEXT,
  service_id               UUID,
  partner_id               UUID,
  service_name             TEXT,
  description              TEXT DEFAULT NULL,
  active                   BOOLEAN DEFAULT true,
  category                 TEXT DEFAULT 'Others',
  discount_price           DECIMAL DEFAULT NULL,
  is_parlour_available     BOOLEAN DEFAULT TRUE,
  parlour_price            DECIMAL DEFAULT NULL,
  parlour_duration_minutes INT DEFAULT NULL,
  parlour_target_gender    TEXT DEFAULT NULL,
  is_home_available        BOOLEAN DEFAULT FALSE,
  home_price               DECIMAL DEFAULT NULL,
  home_duration_minutes    INT DEFAULT NULL,
  home_target_gender       TEXT DEFAULT NULL,
  free_radius_km           INT DEFAULT 0,
  per_km_charge            DECIMAL DEFAULT 0
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_service_id               UUID := update_partner_service.service_id;
  v_partner_id               UUID := update_partner_service.partner_id;
  v_service_name             TEXT := update_partner_service.service_name;
  v_description              TEXT := update_partner_service.description;
  v_active                   BOOLEAN := update_partner_service.active;
  v_category                 TEXT := update_partner_service.category;
  v_discount_price           DECIMAL := update_partner_service.discount_price;
  v_is_parlour_available     BOOLEAN := update_partner_service.is_parlour_available;
  v_parlour_price            DECIMAL := update_partner_service.parlour_price;
  v_parlour_duration_minutes INT := update_partner_service.parlour_duration_minutes;
  v_parlour_target_gender    TEXT := update_partner_service.parlour_target_gender;
  v_is_home_available        BOOLEAN := update_partner_service.is_home_available;
  v_home_price               DECIMAL := update_partner_service.home_price;
  v_home_duration_minutes    INT := update_partner_service.home_duration_minutes;
  v_home_target_gender       TEXT := update_partner_service.home_target_gender;
  v_free_radius_km           INT := update_partner_service.free_radius_km;
  v_per_km_charge            DECIMAL := update_partner_service.per_km_charge;
  
  v_price                    DECIMAL;
  v_duration_minutes         INT;
  v_target_gender            TEXT;
  v_service_location         TEXT;
  updated_row partner_services%ROWTYPE;
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  IF trim(v_service_name) = '' THEN
    RAISE EXCEPTION 'Service name is required';
  END IF;

  -- Determine backward-compatible fallback location, price, duration, gender
  IF v_is_parlour_available AND v_is_home_available THEN
    v_service_location := 'Both';
    v_price := coalesce(v_parlour_price, v_home_price, 0);
    v_duration_minutes := coalesce(v_parlour_duration_minutes, v_home_duration_minutes, 30);
    v_target_gender := coalesce(nullif(trim(v_parlour_target_gender), ''), nullif(trim(v_home_target_gender), ''), 'Unisex');
  ELSIF v_is_home_available THEN
    v_service_location := 'At Home';
    v_price := coalesce(v_home_price, 0);
    v_duration_minutes := coalesce(v_home_duration_minutes, 30);
    v_target_gender := coalesce(nullif(trim(v_home_target_gender), ''), 'Unisex');
  ELSE
    v_service_location := 'At Salon Only';
    v_price := coalesce(v_parlour_price, 0);
    v_duration_minutes := coalesce(v_parlour_duration_minutes, 30);
    v_target_gender := coalesce(nullif(trim(v_parlour_target_gender), ''), 'Unisex');
  END IF;

  UPDATE partner_services SET
    partner_id = v_partner_id,
    name = trim(v_service_name),
    description = nullif(trim(v_description), ''),
    price = v_price,
    duration_minutes = v_duration_minutes,
    is_active = v_active,
    category = coalesce(nullif(trim(v_category), ''), 'Others'),
    target_gender = v_target_gender,
    discount_price = v_discount_price,
    service_location = v_service_location,
    free_radius_km = coalesce(v_free_radius_km, 0),
    per_km_charge = coalesce(v_per_km_charge, 0),
    is_parlour_available = v_is_parlour_available,
    parlour_price = v_parlour_price,
    parlour_duration_minutes = v_parlour_duration_minutes,
    parlour_target_gender = coalesce(nullif(trim(v_parlour_target_gender), ''), 'Unisex'),
    is_home_available = v_is_home_available,
    home_price = v_home_price,
    home_duration_minutes = v_home_duration_minutes,
    home_target_gender = coalesce(nullif(trim(v_home_target_gender), ''), 'Unisex')
  WHERE id = v_service_id
  RETURNING * INTO updated_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Service not found';
  END IF;

  RETURN row_to_json(updated_row);
END;
$$;

GRANT EXECUTE ON FUNCTION update_partner_service(TEXT, UUID, UUID, TEXT, TEXT, BOOLEAN, TEXT, DECIMAL, BOOLEAN, DECIMAL, INT, TEXT, BOOLEAN, DECIMAL, INT, TEXT, INT, DECIMAL) TO anon, authenticated, service_role;
