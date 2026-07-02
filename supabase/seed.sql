-- ============================================================
-- PakeUp – Seed Data
-- Run after migration
-- ============================================================

-- Platform settings
INSERT INTO platform_settings (key, value) VALUES
  ('default_commission_rate', '10'::jsonb),
  ('free_ai_monthly', '5'::jsonb),
  ('home_visit_commission_rate', '10'::jsonb),
  ('bridal_commission_rate', '10'::jsonb)
ON CONFLICT (key) DO NOTHING;

-- Categories
INSERT INTO categories (name, slug, sort_order) VALUES
  ('Hair', 'hair', 1),
  ('Makeup', 'makeup', 2),
  ('Nails', 'nails', 3),
  ('Skincare', 'skincare', 4),
  ('Spa', 'spa', 5),
  ('Bridal', 'bridal', 6),
  ('Men''s Grooming', 'mens-grooming', 7)
ON CONFLICT (slug) DO NOTHING;

-- Sample coupons
INSERT INTO coupons (code, type, value, min_order, usage_limit, valid_until) VALUES
  ('WELCOME50', 'flat', 50, 200, 1000, now() + interval '1 year'),
  ('BEAUTY10', 'percentage', 10, 500, 500, now() + interval '6 months')
ON CONFLICT (code) DO NOTHING;

-- Sample affiliate products
INSERT INTO affiliate_products (name, brand, category, price_display, affiliate_url, sort_order) VALUES
  ('Matte Lipstick', 'Lakme', 'makeup', '₹499', 'https://example.com/lipstick', 1),
  ('Hair Serum', 'L''Oreal', 'hair', '₹699', 'https://example.com/serum', 2),
  ('Face Wash', 'Cetaphil', 'skincare', '₹399', 'https://example.com/facewash', 3);

-- ============================================================
-- CREATE ADMIN USER (run AFTER creating user in Supabase Auth)
-- Step 1: Dashboard → Authentication → Add user
--   Email: admin@pakeup.com
--   Password: admin123
-- Step 2: Run this (replace UUID with actual auth.users id):
-- ============================================================
--
-- UPDATE profiles
-- SET role = 'admin', full_name = 'Super Admin', email = 'admin@pakeup.com'
-- WHERE id = 'YOUR-ADMIN-USER-UUID-HERE';
--
