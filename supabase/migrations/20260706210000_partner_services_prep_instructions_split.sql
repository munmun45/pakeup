-- Add columns for Men and Women specific prep instructions (both parlour and home)
ALTER TABLE partner_services ADD COLUMN IF NOT EXISTS parlour_prep_men TEXT DEFAULT NULL;
ALTER TABLE partner_services ADD COLUMN IF NOT EXISTS parlour_prep_women TEXT DEFAULT NULL;
ALTER TABLE partner_services ADD COLUMN IF NOT EXISTS home_prep_men TEXT DEFAULT NULL;
ALTER TABLE partner_services ADD COLUMN IF NOT EXISTS home_prep_women TEXT DEFAULT NULL;

-- Migrate existing rows to these columns
UPDATE partner_services SET
  parlour_prep_men = CASE WHEN is_parlour_available AND parlour_price_men IS NOT NULL THEN prep_instructions ELSE NULL END,
  parlour_prep_women = CASE WHEN is_parlour_available AND parlour_price_women IS NOT NULL THEN prep_instructions ELSE NULL END,
  home_prep_men = CASE WHEN is_home_available AND home_price_men IS NOT NULL THEN prep_instructions ELSE NULL END,
  home_prep_women = CASE WHEN is_home_available AND home_price_women IS NOT NULL THEN prep_instructions ELSE NULL END;

-- Drop old function overloads to avoid conflicts
DROP FUNCTION IF EXISTS create_partner_service(TEXT, UUID, TEXT, TEXT, TEXT, DECIMAL, BOOLEAN, DECIMAL, INT, DECIMAL, INT, BOOLEAN, DECIMAL, INT, DECIMAL, INT, INT, DECIMAL);
DROP FUNCTION IF EXISTS update_partner_service(TEXT, UUID, UUID, TEXT, TEXT, BOOLEAN, TEXT, DECIMAL, BOOLEAN, DECIMAL, INT, DECIMAL, INT, BOOLEAN, DECIMAL, INT, DECIMAL, INT, INT, DECIMAL);

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
        ps.is_parlour_available,
        ps.parlour_price,
        ps.parlour_duration_minutes,
        ps.parlour_target_gender,
        ps.parlour_price_men,
        ps.parlour_duration_men,
        ps.parlour_price_women,
        ps.parlour_duration_women,
        ps.parlour_prep_men,
        ps.parlour_prep_women,
        ps.is_home_available,
        ps.home_price,
        ps.home_duration_minutes,
        ps.home_target_gender,
        ps.home_price_men,
        ps.home_duration_men,
        ps.home_price_women,
        ps.home_duration_women,
        ps.home_prep_men,
        ps.home_prep_women,
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
  caller_id              TEXT,
  partner_id             UUID,
  service_name           TEXT,
  description            TEXT DEFAULT NULL,
  category               TEXT DEFAULT 'Others',
  discount_price         DECIMAL DEFAULT NULL,
  is_parlour_available   BOOLEAN DEFAULT TRUE,
  parlour_price_men      DECIMAL DEFAULT NULL,
  parlour_duration_men   INT DEFAULT NULL,
  parlour_price_women    DECIMAL DEFAULT NULL,
  parlour_duration_women INT DEFAULT NULL,
  parlour_prep_men       TEXT DEFAULT NULL,
  parlour_prep_women     TEXT DEFAULT NULL,
  is_home_available      BOOLEAN DEFAULT FALSE,
  home_price_men         DECIMAL DEFAULT NULL,
  home_duration_men      INT DEFAULT NULL,
  home_price_women       DECIMAL DEFAULT NULL,
  home_duration_women    INT DEFAULT NULL,
  home_prep_men          TEXT DEFAULT NULL,
  home_prep_women        TEXT DEFAULT NULL,
  free_radius_km         INT DEFAULT 0,
  per_km_charge          DECIMAL DEFAULT 0
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_partner_id             UUID := create_partner_service.partner_id;
  v_service_name           TEXT := create_partner_service.service_name;
  v_description            TEXT := create_partner_service.description;
  v_category               TEXT := create_partner_service.category;
  v_discount_price         DECIMAL := create_partner_service.discount_price;
  v_is_parlour_available   BOOLEAN := create_partner_service.is_parlour_available;
  
  v_parlour_price_men      DECIMAL := create_partner_service.parlour_price_men;
  v_parlour_duration_men   INT := create_partner_service.parlour_duration_men;
  v_parlour_price_women    DECIMAL := create_partner_service.parlour_price_women;
  v_parlour_duration_women INT := create_partner_service.parlour_duration_women;
  v_parlour_prep_men       TEXT := create_partner_service.parlour_prep_men;
  v_parlour_prep_women     TEXT := create_partner_service.parlour_prep_women;
  
  v_is_home_available      BOOLEAN := create_partner_service.is_home_available;
  v_home_price_men         DECIMAL := create_partner_service.home_price_men;
  v_home_duration_men      INT := create_partner_service.home_duration_men;
  v_home_price_women       DECIMAL := create_partner_service.home_price_women;
  v_home_duration_women    INT := create_partner_service.home_duration_women;
  v_home_prep_men          TEXT := create_partner_service.home_prep_men;
  v_home_prep_women        TEXT := create_partner_service.home_prep_women;
  
  v_free_radius_km         INT := create_partner_service.free_radius_km;
  v_per_km_charge          DECIMAL := create_partner_service.per_km_charge;
  
  v_price                  DECIMAL;
  v_duration_minutes       INT;
  v_target_gender          TEXT;
  v_service_location       TEXT;
  v_parlour_target_gender  TEXT;
  v_home_target_gender     TEXT;
  v_prep_fallback          TEXT;
  new_row partner_services%ROWTYPE;
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  IF trim(v_service_name) = '' THEN
    RAISE EXCEPTION 'Service name is required';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM partners WHERE id = v_partner_id) THEN
    RAISE EXCEPTION 'Partner not found';
  END IF;

  -- Determine location
  IF v_is_parlour_available AND v_is_home_available THEN
    v_service_location := 'Both';
  ELSIF v_is_home_available THEN
    v_service_location := 'At Home';
  ELSE
    v_service_location := 'At Salon Only';
  END IF;

  -- Determine parlour target gender
  IF v_parlour_price_men IS NOT NULL AND v_parlour_price_women IS NOT NULL THEN
    v_parlour_target_gender := 'Unisex';
  ELSIF v_parlour_price_men IS NOT NULL THEN
    v_parlour_target_gender := 'Men';
  ELSIF v_parlour_price_women IS NOT NULL THEN
    v_parlour_target_gender := 'Women';
  ELSE
    v_parlour_target_gender := 'Unisex';
  END IF;

  -- Determine home target gender
  IF v_home_price_men IS NOT NULL AND v_home_price_women IS NOT NULL THEN
    v_home_target_gender := 'Unisex';
  ELSIF v_home_price_men IS NOT NULL THEN
    v_home_target_gender := 'Men';
  ELSIF v_home_price_women IS NOT NULL THEN
    v_home_target_gender := 'Women';
  ELSE
    v_home_target_gender := 'Unisex';
  END IF;

  -- Determine global target gender
  IF (v_parlour_price_men IS NOT NULL OR v_home_price_men IS NOT NULL) AND 
     (v_parlour_price_women IS NOT NULL OR v_home_price_women IS NOT NULL) THEN
    v_target_gender := 'Unisex';
  ELSIF (v_parlour_price_men IS NOT NULL OR v_home_price_men IS NOT NULL) THEN
    v_target_gender := 'Men';
  ELSE
    v_target_gender := 'Women';
  END IF;

  -- Determine fallback general price and duration
  v_price := coalesce(v_parlour_price_men, v_parlour_price_women, v_home_price_men, v_home_price_women, 0);
  v_duration_minutes := coalesce(v_parlour_duration_men, v_parlour_duration_women, v_home_duration_men, v_home_duration_women, 30);
  v_prep_fallback := coalesce(v_parlour_prep_men, v_parlour_prep_women, v_home_prep_men, v_home_prep_women);

  INSERT INTO partner_services (
    partner_id, name, description, price, duration_minutes,
    category, target_gender, discount_price, service_location,
    free_radius_km, per_km_charge,
    is_parlour_available, parlour_price, parlour_duration_minutes, parlour_target_gender,
    parlour_price_men, parlour_duration_men, parlour_price_women, parlour_duration_women,
    parlour_prep_men, parlour_prep_women,
    is_home_available, home_price, home_duration_minutes, home_target_gender,
    home_price_men, home_duration_men, home_price_women, home_duration_women,
    home_prep_men, home_prep_women, prep_instructions
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
    coalesce(v_parlour_price_men, v_parlour_price_women),
    coalesce(v_parlour_duration_men, v_parlour_duration_women),
    v_parlour_target_gender,
    v_parlour_price_men,
    v_parlour_duration_men,
    v_parlour_price_women,
    v_parlour_duration_women,
    v_parlour_prep_men,
    v_parlour_prep_women,
    v_is_home_available,
    coalesce(v_home_price_men, v_home_price_women),
    coalesce(v_home_duration_men, v_home_duration_women),
    v_home_target_gender,
    v_home_price_men,
    v_home_duration_men,
    v_home_price_women,
    v_home_duration_women,
    v_home_prep_men,
    v_home_prep_women,
    v_prep_fallback
  )
  RETURNING * INTO new_row;

  RETURN row_to_json(new_row);
END;
$$;

GRANT EXECUTE ON FUNCTION create_partner_service(TEXT, UUID, TEXT, TEXT, TEXT, DECIMAL, BOOLEAN, DECIMAL, INT, DECIMAL, INT, TEXT, TEXT, BOOLEAN, DECIMAL, INT, DECIMAL, INT, TEXT, TEXT, INT, DECIMAL) TO anon, authenticated, service_role;

-- Redefine update_partner_service
CREATE OR REPLACE FUNCTION update_partner_service(
  caller_id              TEXT,
  service_id             UUID,
  partner_id             UUID,
  service_name           TEXT,
  description            TEXT DEFAULT NULL,
  active                 BOOLEAN DEFAULT true,
  category               TEXT DEFAULT 'Others',
  discount_price         DECIMAL DEFAULT NULL,
  is_parlour_available   BOOLEAN DEFAULT TRUE,
  parlour_price_men      DECIMAL DEFAULT NULL,
  parlour_duration_men   INT DEFAULT NULL,
  parlour_price_women    DECIMAL DEFAULT NULL,
  parlour_duration_women INT DEFAULT NULL,
  parlour_prep_men       TEXT DEFAULT NULL,
  parlour_prep_women     TEXT DEFAULT NULL,
  is_home_available      BOOLEAN DEFAULT FALSE,
  home_price_men         DECIMAL DEFAULT NULL,
  home_duration_men      INT DEFAULT NULL,
  home_price_women       DECIMAL DEFAULT NULL,
  home_duration_women    INT DEFAULT NULL,
  home_prep_men          TEXT DEFAULT NULL,
  home_prep_women        TEXT DEFAULT NULL,
  free_radius_km         INT DEFAULT 0,
  per_km_charge          DECIMAL DEFAULT 0
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_service_id             UUID := update_partner_service.service_id;
  v_partner_id             UUID := update_partner_service.partner_id;
  v_service_name           TEXT := update_partner_service.service_name;
  v_description            TEXT := update_partner_service.description;
  v_active                 BOOLEAN := update_partner_service.active;
  v_category               TEXT := update_partner_service.category;
  v_discount_price         DECIMAL := update_partner_service.discount_price;
  v_is_parlour_available   BOOLEAN := update_partner_service.is_parlour_available;
  
  v_parlour_price_men      DECIMAL := update_partner_service.parlour_price_men;
  v_parlour_duration_men   INT := update_partner_service.parlour_duration_men;
  v_parlour_price_women    DECIMAL := update_partner_service.parlour_price_women;
  v_parlour_duration_women INT := update_partner_service.parlour_duration_women;
  v_parlour_prep_men       TEXT := update_partner_service.parlour_prep_men;
  v_parlour_prep_women     TEXT := update_partner_service.parlour_prep_women;
  
  v_is_home_available      BOOLEAN := update_partner_service.is_home_available;
  v_home_price_men         DECIMAL := update_partner_service.home_price_men;
  v_home_duration_men      INT := update_partner_service.home_duration_men;
  v_home_price_women       DECIMAL := update_partner_service.home_price_women;
  v_home_duration_women    INT := update_partner_service.home_duration_women;
  v_home_prep_men          TEXT := update_partner_service.home_prep_men;
  v_home_prep_women        TEXT := update_partner_service.home_prep_women;
  
  v_free_radius_km         INT := update_partner_service.free_radius_km;
  v_per_km_charge          DECIMAL := update_partner_service.per_km_charge;
  
  v_price                  DECIMAL;
  v_duration_minutes       INT;
  v_target_gender          TEXT;
  v_service_location       TEXT;
  v_parlour_target_gender  TEXT;
  v_home_target_gender     TEXT;
  v_prep_fallback          TEXT;
  updated_row partner_services%ROWTYPE;
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  IF trim(v_service_name) = '' THEN
    RAISE EXCEPTION 'Service name is required';
  END IF;

  -- Determine location
  IF v_is_parlour_available AND v_is_home_available THEN
    v_service_location := 'Both';
  ELSIF v_is_home_available THEN
    v_service_location := 'At Home';
  ELSE
    v_service_location := 'At Salon Only';
  END IF;

  -- Determine parlour target gender
  IF v_parlour_price_men IS NOT NULL AND v_parlour_price_women IS NOT NULL THEN
    v_parlour_target_gender := 'Unisex';
  ELSIF v_parlour_price_men IS NOT NULL THEN
    v_parlour_target_gender := 'Men';
  ELSIF v_parlour_price_women IS NOT NULL THEN
    v_parlour_target_gender := 'Women';
  ELSE
    v_parlour_target_gender := 'Unisex';
  END IF;

  -- Determine home target gender
  IF v_home_price_men IS NOT NULL AND v_home_price_women IS NOT NULL THEN
    v_home_target_gender := 'Unisex';
  ELSIF v_home_price_men IS NOT NULL THEN
    v_home_target_gender := 'Men';
  ELSIF v_home_price_women IS NOT NULL THEN
    v_home_target_gender := 'Women';
  ELSE
    v_home_target_gender := 'Unisex';
  END IF;

  -- Determine global target gender
  IF (v_parlour_price_men IS NOT NULL OR v_home_price_men IS NOT NULL) AND 
     (v_parlour_price_women IS NOT NULL OR v_home_price_women IS NOT NULL) THEN
    v_target_gender := 'Unisex';
  ELSIF (v_parlour_price_men IS NOT NULL OR v_home_price_men IS NOT NULL) THEN
    v_target_gender := 'Men';
  ELSE
    v_target_gender := 'Women';
  END IF;

  -- Determine fallback general price and duration
  v_price := coalesce(v_parlour_price_men, v_parlour_price_women, v_home_price_men, v_home_price_women, 0);
  v_duration_minutes := coalesce(v_parlour_duration_men, v_parlour_duration_women, v_home_duration_men, v_home_duration_women, 30);
  v_prep_fallback := coalesce(v_parlour_prep_men, v_parlour_prep_women, v_home_prep_men, v_home_prep_women);

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
    parlour_price = coalesce(v_parlour_price_men, v_parlour_price_women),
    parlour_duration_minutes = coalesce(v_parlour_duration_men, v_parlour_duration_women),
    parlour_target_gender = v_parlour_target_gender,
    parlour_price_men = v_parlour_price_men,
    parlour_duration_men = v_parlour_duration_men,
    parlour_price_women = v_parlour_price_women,
    parlour_duration_women = v_parlour_duration_women,
    parlour_prep_men = v_parlour_prep_men,
    parlour_prep_women = v_parlour_prep_women,
    
    is_home_available = v_is_home_available,
    home_price = coalesce(v_home_price_men, v_home_price_women),
    home_duration_minutes = coalesce(v_home_duration_men, v_home_duration_women),
    home_target_gender = v_home_target_gender,
    home_price_men = v_home_price_men,
    home_duration_men = v_home_duration_men,
    home_price_women = v_home_price_women,
    home_duration_women = v_home_duration_women,
    home_prep_men = v_home_prep_men,
    home_prep_women = v_home_prep_women,
    prep_instructions = v_prep_fallback
  WHERE id = v_service_id
  RETURNING * INTO updated_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Service not found';
  END IF;

  RETURN row_to_json(updated_row);
END;
$$;

GRANT EXECUTE ON FUNCTION update_partner_service(TEXT, UUID, UUID, TEXT, TEXT, BOOLEAN, TEXT, DECIMAL, BOOLEAN, DECIMAL, INT, DECIMAL, INT, TEXT, TEXT, BOOLEAN, DECIMAL, INT, DECIMAL, INT, TEXT, TEXT, INT, DECIMAL) TO anon, authenticated, service_role;
