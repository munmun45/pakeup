-- Add images and primary_image columns to partners table
ALTER TABLE partners ADD COLUMN IF NOT EXISTS images TEXT[] NOT NULL DEFAULT '{}';
ALTER TABLE partners ADD COLUMN IF NOT EXISTS primary_image TEXT;

-- Create partner-images storage bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'partner-images',
  'partner-images',
  true,
  10485760, -- 10MB
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

-- Redefine list_partners to include images and primary_image
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
        p.account_id,
        p.business_name,
        coalesce(a.owner_name, p.owner_name) AS owner_name,
        coalesce(a.phone, p.phone) AS phone,
        coalesce(a.email, p.email) AS email,
        coalesce(a.whatsapp, p.whatsapp) AS whatsapp,
        coalesce(a.alternate_phone, p.alternate_phone) AS alternate_phone,
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
        a.login_id,
        (a.pass IS NOT NULL AND trim(a.pass) <> '') AS has_password,
        (
          SELECT count(*)::int
          FROM partners ps
          WHERE ps.account_id = p.account_id
        ) AS store_count,
        p.created_at,
        p.images,
        p.primary_image
      FROM partners p
      LEFT JOIN partner_accounts a ON a.id = p.account_id
      LEFT JOIN partner_categories pc ON pc.slug = p.category
    ) t
  );
END;
$$;

GRANT EXECUTE ON FUNCTION list_partners(TEXT) TO anon, authenticated, service_role;

-- Create update_partner_images function
CREATE OR REPLACE FUNCTION update_partner_images(
  caller_id     TEXT,
  partner_id    UUID,
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

  UPDATE partners SET
    images = update_partner_images.images,
    primary_image = nullif(trim(update_partner_images.primary_image), '')
  WHERE id = partner_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Partner not found';
  END IF;

  RETURN json_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION update_partner_images(TEXT, UUID, TEXT[], TEXT) TO anon, authenticated, service_role;

-- Storage policies for partner-images bucket
DROP POLICY IF EXISTS "partner_images_public_read" ON storage.objects;
CREATE POLICY "partner_images_public_read"
ON storage.objects FOR SELECT
USING (bucket_id = 'partner-images');

DROP POLICY IF EXISTS "partner_images_anon_insert" ON storage.objects;
CREATE POLICY "partner_images_anon_insert"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'partner-images');

DROP POLICY IF EXISTS "partner_images_anon_update" ON storage.objects;
CREATE POLICY "partner_images_anon_update"
ON storage.objects FOR UPDATE
USING (bucket_id = 'partner-images')
WITH CHECK (bucket_id = 'partner-images');

DROP POLICY IF EXISTS "partner_images_anon_delete" ON storage.objects;
CREATE POLICY "partner_images_anon_delete"
ON storage.objects FOR DELETE
USING (bucket_id = 'partner-images');
