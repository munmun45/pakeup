-- Sort partner accounts by created_at DESC (recent data on top)
CREATE OR REPLACE FUNCTION list_partner_accounts(caller_id TEXT)
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
        a.id,
        a.owner_name,
        a.phone,
        a.email,
        a.whatsapp,
        a.alternate_phone,
        a.login_id,
        (a.pass IS NOT NULL AND trim(a.pass) <> '') AS has_password,
        a.is_active,
        (
          SELECT count(*)::int
          FROM partners p
          WHERE p.account_id = a.id
        ) AS store_count,
        a.created_at
      FROM partner_accounts a
    ) t
  );
END;
$$;

GRANT EXECUTE ON FUNCTION list_partner_accounts(TEXT) TO anon, authenticated, service_role;
