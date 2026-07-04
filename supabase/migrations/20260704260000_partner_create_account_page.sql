-- Create Partner sidebar page

INSERT INTO admin_pages (page_key, label, sort_order) VALUES
  ('partner_create_account', 'Create Partner', 16)
ON CONFLICT (page_key) DO UPDATE SET label = EXCLUDED.label;

UPDATE admin_pages SET sort_order = 17 WHERE page_key = 'add_partners';
UPDATE admin_pages SET sort_order = 18 WHERE page_key = 'partner_categories';
UPDATE admin_pages SET sort_order = 19 WHERE page_key = 'partner_kyc';
UPDATE admin_pages SET sort_order = 20 WHERE page_key = 'partner_manage_accounts';
UPDATE admin_pages SET sort_order = 21 WHERE page_key = 'partner_services';

INSERT INTO admin_page_access (admin_id, page_key)
SELECT 'admin', 'partner_create_account'
WHERE NOT EXISTS (
  SELECT 1 FROM admin_page_access
  WHERE admin_id = 'admin' AND page_key = 'partner_create_account'
);

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
              'partner_create_account',
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
