-- Partner store app: list services for account-owned stores

CREATE OR REPLACE FUNCTION list_partner_store_services(
  p_account_id UUID,
  p_login_pass TEXT,
  p_store_id   UUID DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_account_id UUID := list_partner_store_services.p_account_id;
  v_store_id   UUID := list_partner_store_services.p_store_id;
BEGIN
  PERFORM assert_partner_account_access(v_account_id, p_login_pass);

  IF v_store_id IS NOT NULL THEN
    PERFORM assert_partner_store_owned(v_account_id, p_login_pass, v_store_id);
  END IF;

  RETURN COALESCE((
    SELECT json_agg(row_to_json(t) ORDER BY t.created_at DESC)
    FROM (
      SELECT
        ps.id,
        ps.partner_id,
        p.business_name AS partner_name,
        ps.name,
        ps.description,
        ps.category,
        ps.target_gender,
        ps.is_parlour_available,
        ps.parlour_price_men,
        ps.parlour_duration_men,
        ps.parlour_price_women,
        ps.parlour_duration_women,
        ps.is_home_available,
        ps.home_price_men,
        ps.home_duration_men,
        ps.home_price_women,
        ps.home_duration_women,
        ps.service_image,
        ps.primary_image,
        ps.images,
        ps.is_active,
        ps.created_at
      FROM partner_services ps
      JOIN partners p ON p.id = ps.partner_id
      WHERE p.account_id = v_account_id
        AND (v_store_id IS NULL OR ps.partner_id = v_store_id)
    ) t
  ), '[]'::json);
END;
$$;

GRANT EXECUTE ON FUNCTION list_partner_store_services(UUID, TEXT, UUID)
  TO anon, authenticated, service_role;

NOTIFY pgrst, 'reload schema';
