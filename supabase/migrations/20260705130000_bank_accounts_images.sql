-- Redefine list_partner_bank_accounts to include primary_image and images from partners
CREATE OR REPLACE FUNCTION list_partner_bank_accounts(caller_id TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  RETURN (
    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.business_name), '[]'::json)
    FROM (
      SELECT
        p.id AS partner_id,
        p.business_name,
        coalesce(a.owner_name, p.owner_name) AS owner_name,
        coalesce(a.phone, p.phone) AS phone,
        p.primary_image,
        p.images,
        p.is_active,
        coalesce(k.account_status, 'pending') AS account_status,
        k.bank_account_holder,
        k.bank_name,
        k.ifsc_code,
        k.account_number,
        k.passbook_doc_url,
        k.submitted_at AS kyc_submitted_at,
        k.updated_at AS account_updated_at
      FROM partners p
      LEFT JOIN partner_accounts a ON a.id = p.account_id
      LEFT JOIN partner_kyc_details k ON k.partner_id = p.id
    ) t
  );
END;
$$;

GRANT EXECUTE ON FUNCTION list_partner_bank_accounts(TEXT) TO anon, authenticated, service_role;
