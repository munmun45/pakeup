-- Include parent account profile_id in admin store list (Add Stores table).

CREATE OR REPLACE FUNCTION list_partners(caller_id TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  RETURN COALESCE((
    SELECT json_agg(row_to_json(t) ORDER BY t.created_at DESC)
    FROM (
      SELECT
        p.id,
        p.account_id,
        a.profile_id,
        p.business_name,
        p.owner_name,
        p.phone,
        p.email,
        p.whatsapp,
        p.alternate_phone,
        p.city,
        p.state,
        p.pincode,
        p.category,
        pc.name AS category_name,
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
        p.login_id,
        (p.pass IS NOT NULL AND p.pass <> '') AS has_password,
        p.primary_image,
        p.images,
        p.created_at,
        a.phone AS account_phone,
        a.whatsapp AS account_whatsapp,
        (
          SELECT count(*)::int
          FROM partners p2
          WHERE p2.account_id = p.account_id
        ) AS store_count,
        partner_schedules_json(p.id) AS schedules
      FROM partners p
      LEFT JOIN partner_categories pc ON pc.slug = p.category
      LEFT JOIN partner_accounts a ON a.id = p.account_id
    ) t
  ), '[]'::json);
END;
$$;

GRANT EXECUTE ON FUNCTION list_partners(TEXT) TO anon, authenticated, service_role;

NOTIFY pgrst, 'reload schema';
