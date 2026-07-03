-- Manage Accounts sidebar page + list RPC

INSERT INTO admin_pages (page_key, label, sort_order) VALUES
  ('partner_manage_accounts', 'Manage Accounts', 18)
ON CONFLICT (page_key) DO NOTHING;

UPDATE admin_pages SET sort_order = 19 WHERE page_key = 'partner_services';

INSERT INTO admin_page_access (admin_id, page_key)
SELECT 'admin', 'partner_manage_accounts'
ON CONFLICT DO NOTHING;

CREATE OR REPLACE FUNCTION assert_admin_partner_access(caller_id TEXT)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM admin a
    WHERE a.id = caller_id
      AND a.is_active
      AND (
        a.role = 'super_admin'
        OR EXISTS (
          SELECT 1 FROM admin_page_access apa
          WHERE apa.admin_id = a.id
            AND apa.page_key IN (
              'add_partners',
              'partner_kyc',
              'partner_services',
              'partner_categories',
              'partner_manage_accounts'
            )
        )
      )
  ) THEN
    RAISE EXCEPTION 'Access denied';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION list_partner_accounts(caller_id TEXT)
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
        p.owner_name,
        p.is_active,
        k.bank_account_holder,
        k.bank_name,
        k.ifsc_code,
        k.account_number,
        k.passbook_doc_url,
        k.submitted_at AS kyc_submitted_at,
        k.updated_at AS account_updated_at
      FROM partners p
      LEFT JOIN partner_kyc_details k ON k.partner_id = p.id
    ) t
  );
END;
$$;

GRANT EXECUTE ON FUNCTION list_partner_accounts(TEXT) TO anon, authenticated, service_role;
