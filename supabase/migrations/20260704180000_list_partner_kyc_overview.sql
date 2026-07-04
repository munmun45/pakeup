-- Partner KYC list with PAN and Aadhaar for admin review table

CREATE OR REPLACE FUNCTION list_partner_kyc_overview(caller_id TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  RETURN (
    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.business_name), '[]'::json)
    FROM (
      SELECT
        p.id AS partner_id,
        p.business_name,
        p.owner_name,
        p.is_active,
        coalesce(p.kyc_status, 'pending') AS kyc_status,
        k.pan_number,
        k.aadhaar_number
      FROM partners p
      LEFT JOIN partner_kyc_details k ON k.partner_id = p.id
    ) t
  );
END;
$fn$;

GRANT EXECUTE ON FUNCTION list_partner_kyc_overview(TEXT) TO anon, authenticated, service_role;
