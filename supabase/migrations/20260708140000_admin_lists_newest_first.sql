-- Show recently added items at the top of admin list RPCs.

CREATE OR REPLACE FUNCTION list_partner_kyc_overview(caller_id TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
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
        coalesce(nullif(trim(k.passbook_doc_url), ''), '') <> '' AS has_passbook_doc
      FROM partners p
      LEFT JOIN partner_accounts a ON a.id = p.account_id
      LEFT JOIN partner_kyc_details k ON k.partner_id = p.id
    ) t
  );
END;
$fn$;

CREATE OR REPLACE FUNCTION list_partner_bank_accounts(caller_id TEXT)
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
        p.primary_image,
        p.images,
        p.is_active,
        p.created_at,
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

CREATE OR REPLACE FUNCTION list_admin_users(caller_id TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM admin WHERE id = caller_id AND role = 'super_admin'
  ) THEN
    RAISE EXCEPTION 'Only Super Admin can view admin users';
  END IF;

  RETURN (
    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.created_at DESC), '[]'::json)
    FROM (
      SELECT
        a.id,
        a.role::text AS role,
        a.name,
        a.phone,
        a.notes,
        a.is_active,
        a.created_at,
        COALESCE(
          (
            SELECT json_agg(ap.page_key ORDER BY p.sort_order)
            FROM admin_page_access ap
            JOIN admin_pages p ON p.page_key = ap.page_key
            WHERE ap.admin_id = a.id
          ),
          '[]'::json
        ) AS pages
      FROM admin a
      ORDER BY a.created_at DESC
    ) t
  );
END;
$$;

CREATE OR REPLACE FUNCTION list_partner_categories(caller_id TEXT)
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
      SELECT id, slug, name, is_active, sort_order, created_at
      FROM partner_categories
    ) t
  );
END;
$$;

CREATE OR REPLACE FUNCTION list_service_categories(caller_id TEXT)
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
      SELECT id, slug, name, is_active, sort_order, created_at
      FROM service_categories
    ) t
  );
END;
$$;

NOTIFY pgrst, 'reload schema';
