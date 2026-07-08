-- Partner store app: update store images

CREATE OR REPLACE FUNCTION update_partner_store_images(
  p_account_id    UUID,
  p_login_pass    TEXT,
  p_store_id      UUID,
  p_images        TEXT[],
  p_primary_image TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_store_id UUID := update_partner_store_images.p_store_id;
BEGIN
  PERFORM assert_partner_store_owned(p_account_id, p_login_pass, v_store_id);

  UPDATE partners SET
    images = p_images,
    primary_image = nullif(trim(p_primary_image), '')
  WHERE id = v_store_id;

  RETURN json_build_object('success', true);
END;
$$;

-- Ensure list/get include images array
CREATE OR REPLACE FUNCTION list_partner_stores(
  p_account_id UUID,
  p_login_pass TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_account_id UUID := list_partner_stores.p_account_id;
BEGIN
  PERFORM assert_partner_account_access(v_account_id, p_login_pass);

  RETURN COALESCE((
    SELECT json_agg(row_to_json(t) ORDER BY t.created_at DESC)
    FROM (
      SELECT
        p.id,
        p.account_id,
        p.business_name,
        p.owner_name,
        p.phone,
        p.whatsapp,
        p.alternate_phone,
        p.email,
        p.description,
        p.address_line,
        p.city,
        p.state,
        p.pincode,
        p.latitude,
        p.longitude,
        p.category,
        p.is_active,
        p.kyc_status,
        p.images,
        p.primary_image,
        p.created_at
      FROM partners p
      WHERE p.account_id = v_account_id
    ) t
  ), '[]'::json);
END;
$$;

GRANT EXECUTE ON FUNCTION update_partner_store_images(
  UUID, TEXT, UUID, TEXT[], TEXT
) TO anon, authenticated, service_role;

NOTIFY pgrst, 'reload schema';
