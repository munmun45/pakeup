-- Include parent account profile_id in admin KYC overview list.

CREATE OR REPLACE FUNCTION list_partner_kyc_overview(caller_id TEXT)
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
        p.id AS partner_id,
        p.business_name,
        coalesce(a.owner_name, p.owner_name) AS owner_name,
        coalesce(a.phone, p.phone) AS phone,
        a.profile_id,
        p.primary_image,
        p.images,
        p.is_active,
        coalesce(p.kyc_status, 'pending') AS kyc_status,
        p.created_at,
        k.pan_number,
        k.aadhaar_number,
        coalesce(nullif(trim(k.aadhaar_doc_url), ''), '') <> '' AS has_aadhaar_doc,
        coalesce(nullif(trim(k.pan_doc_url), ''), '') <> '' AS has_pan_doc,
        coalesce(nullif(trim(k.agreement_doc_url), ''), '') <> '' AS has_agreement_doc,
        coalesce(nullif(trim(k.gst_doc_url), ''), '') <> '' AS has_gst_doc,
        coalesce(nullif(trim(k.other_doc_url), ''), '') <> '' AS has_other_doc,
        coalesce(nullif(trim(b.passbook_doc_url), ''), '') <> '' AS has_passbook_doc
      FROM partners p
      LEFT JOIN partner_accounts a ON a.id = p.account_id
      LEFT JOIN partner_kyc_details k ON k.partner_id = p.id
      LEFT JOIN partner_bank_details b ON b.account_id = p.account_id
    ) t
  );
END;
$$;
