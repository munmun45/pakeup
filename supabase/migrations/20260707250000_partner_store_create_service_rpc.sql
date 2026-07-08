-- Partner store app: create a basic service for an owned store
-- Pricing / location / gender are managed later from the admin panel.

CREATE OR REPLACE FUNCTION create_partner_store_service(
  p_account_id      UUID,
  p_login_pass      TEXT,
  p_store_id        UUID,
  p_service_name    TEXT,
  p_description     TEXT    DEFAULT NULL,
  p_category        TEXT    DEFAULT 'Others',
  p_service_image   TEXT    DEFAULT NULL,
  p_primary_image   TEXT    DEFAULT NULL,
  p_images          TEXT[]  DEFAULT '{}'
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_primary_image TEXT;
  v_images        TEXT[];
  new_row         partner_services%ROWTYPE;
BEGIN
  PERFORM assert_partner_store_owned(p_account_id, p_login_pass, p_store_id);

  IF trim(p_service_name) = '' THEN
    RAISE EXCEPTION 'Service name is required';
  END IF;

  v_primary_image := nullif(trim(coalesce(p_primary_image, p_service_image, '')), '');
  v_images := coalesce(p_images, '{}');

  IF v_primary_image IS NULL AND array_length(v_images, 1) IS NOT NULL THEN
    v_primary_image := v_images[1];
  END IF;

  IF v_primary_image IS NOT NULL AND (array_length(v_images, 1) IS NULL OR array_length(v_images, 1) = 0) THEN
    v_images := ARRAY[v_primary_image];
  END IF;

  INSERT INTO partner_services (
    partner_id,
    name,
    description,
    category,
    price,
    duration_minutes,
    target_gender,
    service_location,
    is_parlour_available,
    is_home_available,
    service_image,
    primary_image,
    images
  ) VALUES (
    p_store_id,
    trim(p_service_name),
    nullif(trim(coalesce(p_description, '')), ''),
    coalesce(nullif(trim(p_category), ''), 'Others'),
    0,
    30,
    'Unisex',
    'At Salon Only',
    TRUE,
    FALSE,
    v_primary_image,
    v_primary_image,
    v_images
  )
  RETURNING * INTO new_row;

  RETURN row_to_json(new_row);
END;
$$;

GRANT EXECUTE ON FUNCTION create_partner_store_service(
  UUID, TEXT, UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT[]
) TO anon, authenticated, service_role;

NOTIFY pgrst, 'reload schema';
