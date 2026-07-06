-- Drop old function overloads to prevent postgrest cache mismatch
DROP FUNCTION IF EXISTS create_partner_service(TEXT, UUID, TEXT, TEXT, DECIMAL, INT, TEXT, TEXT, DECIMAL, TEXT);
DROP FUNCTION IF EXISTS update_partner_service(TEXT, UUID, UUID, TEXT, TEXT, DECIMAL, INT, BOOLEAN, TEXT, TEXT, DECIMAL, TEXT);

-- Add new travel charge columns to partner_services table
ALTER TABLE partner_services ADD COLUMN IF NOT EXISTS free_radius_km INT NOT NULL DEFAULT 0;
ALTER TABLE partner_services ADD COLUMN IF NOT EXISTS per_km_charge DECIMAL(10, 2) NOT NULL DEFAULT 0.00;

-- Redefine list_partner_services to return the new columns
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

-- Redefine create_partner_service to accept travel charge fields
CREATE OR REPLACE FUNCTION create_partner_service(
  caller_id         TEXT,
  partner_id        UUID,
  service_name      TEXT,
  description       TEXT DEFAULT NULL,
  price             DECIMAL DEFAULT 0,
  duration_minutes  INT DEFAULT 30,
  category          TEXT DEFAULT 'Others',
  target_gender     TEXT DEFAULT 'Unisex',
  discount_price    DECIMAL DEFAULT NULL,
  service_location  TEXT DEFAULT 'At Salon Only',
  free_radius_km    INT DEFAULT 0,
  per_km_charge     DECIMAL DEFAULT 0
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_partner_id       UUID := create_partner_service.partner_id;
  v_service_name     TEXT := create_partner_service.service_name;
  v_description      TEXT := create_partner_service.description;
  v_price            DECIMAL := create_partner_service.price;
  v_duration_minutes INT := create_partner_service.duration_minutes;
  v_category         TEXT := create_partner_service.category;
  v_target_gender    TEXT := create_partner_service.target_gender;
  v_discount_price   DECIMAL := create_partner_service.discount_price;
  v_service_location TEXT := create_partner_service.service_location;
  v_free_radius_km   INT := create_partner_service.free_radius_km;
  v_per_km_charge    DECIMAL := create_partner_service.per_km_charge;
  new_row partner_services%ROWTYPE;
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  IF trim(v_service_name) = '' THEN
    RAISE EXCEPTION 'Service name is required';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM partners WHERE id = v_partner_id) THEN
    RAISE EXCEPTION 'Partner not found';
  END IF;

  INSERT INTO partner_services (
    partner_id, name, description, price, duration_minutes,
    category, target_gender, discount_price, service_location,
    free_radius_km, per_km_charge
  ) VALUES (
    v_partner_id,
    trim(v_service_name),
    nullif(trim(v_description), ''),
    coalesce(v_price, 0),
    coalesce(v_duration_minutes, 30),
    coalesce(nullif(trim(v_category), ''), 'Others'),
    coalesce(nullif(trim(v_target_gender), ''), 'Unisex'),
    v_discount_price,
    coalesce(nullif(trim(v_service_location), ''), 'At Salon Only'),
    coalesce(v_free_radius_km, 0),
    coalesce(v_per_km_charge, 0)
  )
  RETURNING * INTO new_row;

  RETURN row_to_json(new_row);
END;
$$;

GRANT EXECUTE ON FUNCTION create_partner_service(TEXT, UUID, TEXT, TEXT, DECIMAL, INT, TEXT, TEXT, DECIMAL, TEXT, INT, DECIMAL) TO anon, authenticated, service_role;

-- Redefine update_partner_service to accept travel charge fields
CREATE OR REPLACE FUNCTION update_partner_service(
  caller_id         TEXT,
  service_id        UUID,
  partner_id        UUID,
  service_name      TEXT,
  description       TEXT DEFAULT NULL,
  price             DECIMAL DEFAULT 0,
  duration_minutes  INT DEFAULT 30,
  active            BOOLEAN DEFAULT true,
  category          TEXT DEFAULT 'Others',
  target_gender     TEXT DEFAULT 'Unisex',
  discount_price    DECIMAL DEFAULT NULL,
  service_location  TEXT DEFAULT 'At Salon Only',
  free_radius_km    INT DEFAULT 0,
  per_km_charge     DECIMAL DEFAULT 0
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_service_id       UUID := update_partner_service.service_id;
  v_partner_id       UUID := update_partner_service.partner_id;
  v_service_name     TEXT := update_partner_service.service_name;
  v_description      TEXT := update_partner_service.description;
  v_price            DECIMAL := update_partner_service.price;
  v_duration_minutes INT := update_partner_service.duration_minutes;
  v_active           BOOLEAN := update_partner_service.active;
  v_category         TEXT := update_partner_service.category;
  v_target_gender    TEXT := update_partner_service.target_gender;
  v_discount_price   DECIMAL := update_partner_service.discount_price;
  v_service_location TEXT := update_partner_service.service_location;
  v_free_radius_km   INT := update_partner_service.free_radius_km;
  v_per_km_charge    DECIMAL := update_partner_service.per_km_charge;
  updated_row partner_services%ROWTYPE;
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  IF trim(v_service_name) = '' THEN
    RAISE EXCEPTION 'Service name is required';
  END IF;

  UPDATE partner_services SET
    partner_id = v_partner_id,
    name = trim(v_service_name),
    description = nullif(trim(v_description), ''),
    price = coalesce(v_price, 0),
    duration_minutes = coalesce(v_duration_minutes, 30),
    is_active = v_active,
    category = coalesce(nullif(trim(v_category), ''), 'Others'),
    target_gender = coalesce(nullif(trim(v_target_gender), ''), 'Unisex'),
    discount_price = v_discount_price,
    service_location = coalesce(nullif(trim(v_service_location), ''), 'At Salon Only'),
    free_radius_km = coalesce(v_free_radius_km, 0),
    per_km_charge = coalesce(v_per_km_charge, 0)
  WHERE id = v_service_id
  RETURNING * INTO updated_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Service not found';
  END IF;

  RETURN row_to_json(updated_row);
END;
$$;

GRANT EXECUTE ON FUNCTION update_partner_service(TEXT, UUID, UUID, TEXT, TEXT, DECIMAL, INT, BOOLEAN, TEXT, TEXT, DECIMAL, TEXT, INT, DECIMAL) TO anon, authenticated, service_role;
