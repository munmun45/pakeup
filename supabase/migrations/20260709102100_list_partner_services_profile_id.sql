-- Include parent account profile_id in admin partner services list.

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
        a.profile_id,
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
