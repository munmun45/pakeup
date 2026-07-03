-- Partner management pages (Add Partners, KYC, Partner Services)

INSERT INTO admin_pages (page_key, label, sort_order) VALUES
  ('add_partners', 'Add Partners', 16),
  ('partner_kyc', 'KYC', 17),
  ('partner_services', 'Partner Services', 18)
ON CONFLICT (page_key) DO NOTHING;

INSERT INTO admin_page_access (admin_id, page_key)
SELECT 'admin', page_key FROM admin_pages
WHERE page_key IN ('add_partners', 'partner_kyc', 'partner_services')
ON CONFLICT DO NOTHING;
