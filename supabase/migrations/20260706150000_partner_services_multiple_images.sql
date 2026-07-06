-- Add images and primary_image columns to partner_services table
ALTER TABLE partner_services ADD COLUMN IF NOT EXISTS images TEXT[] NOT NULL DEFAULT '{}';
ALTER TABLE partner_services ADD COLUMN IF NOT EXISTS primary_image TEXT DEFAULT NULL;

-- Redefine list_partner_services to return the service's own primary_image and images
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

-- Create update_partner_service_images function
CREATE OR REPLACE FUNCTION update_partner_service_images(
  caller_id     TEXT,
  service_id    UUID,
  images        TEXT[],
  primary_image TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  UPDATE partner_services SET
    images = update_partner_service_images.images,
    primary_image = nullif(trim(update_partner_service_images.primary_image), '')
  WHERE id = service_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Service not found';
  END IF;

  RETURN json_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION update_partner_service_images(TEXT, UUID, TEXT[], TEXT) TO anon, authenticated, service_role;
