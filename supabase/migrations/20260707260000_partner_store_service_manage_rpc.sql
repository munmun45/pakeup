-- Partner store app: toggle active + update basic service details

CREATE OR REPLACE FUNCTION toggle_partner_store_service_active(
  p_account_id  UUID,
  p_login_pass  TEXT,
  p_store_id    UUID,
  p_service_id  UUID,
  p_active      BOOLEAN
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  updated_row partner_services%ROWTYPE;
BEGIN
  PERFORM assert_partner_store_owned(p_account_id, p_login_pass, p_store_id);

  UPDATE partner_services ps
  SET is_active = p_active
  WHERE ps.id = p_service_id
    AND ps.partner_id = p_store_id
  RETURNING * INTO updated_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Service not found';
  END IF;

  RETURN row_to_json(updated_row);
END;
$$;

CREATE OR REPLACE FUNCTION update_partner_store_service(
  p_account_id      UUID,
  p_login_pass      TEXT,
  p_store_id        UUID,
  p_service_id      UUID,
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
  updated_row     partner_services%ROWTYPE;
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

  UPDATE partner_services ps
  SET
    name = trim(p_service_name),
    description = nullif(trim(coalesce(p_description, '')), ''),
    category = coalesce(nullif(trim(p_category), ''), 'Others'),
    service_image = v_primary_image,
    primary_image = v_primary_image,
    images = v_images
  WHERE ps.id = p_service_id
    AND ps.partner_id = p_store_id
  RETURNING * INTO updated_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Service not found';
  END IF;

  RETURN row_to_json(updated_row);
END;
$$;

GRANT EXECUTE ON FUNCTION toggle_partner_store_service_active(
  UUID, TEXT, UUID, UUID, BOOLEAN
) TO anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION update_partner_store_service(
  UUID, TEXT, UUID, UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT[]
) TO anon, authenticated, service_role;

NOTIFY pgrst, 'reload schema';
