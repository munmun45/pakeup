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

-- Sample partners (also in migration 20260704010000_seed_partners.sql)
INSERT INTO partners (
  id, business_name, owner_name, phone, email, whatsapp, alternate_phone,
  city, state, pincode, category, address_line, description,
  gst_number, website, latitude, longitude, notes, is_active, kyc_status
) VALUES
  (
    'a1000001-0000-4000-8000-000000000001',
    'Glow Studio Salon', 'Priya Sharma',
    '+91 98765 43210', 'priya@glowstudio.in', '+91 98765 43210', '+91 91234 56780',
    'Mumbai', 'Maharashtra', '400001', 'salon',
    '12 Linking Road, Bandra West',
    'Premium hair styling, coloring, and bridal packages. Walk-ins welcome.',
    '27AABCG1234A1Z5', 'https://glowstudio.in', 19.0596, 72.8295,
    'Preferred partner — fast KYC turnaround.', true, 'approved'
  ),
  (
    'a1000001-0000-4000-8000-000000000002',
    'Bliss Beauty Spa', 'Ananya Reddy',
    '+91 99887 76655', 'hello@blissbeautyspa.com', '+91 99887 76655', NULL,
    'New Delhi', 'Delhi', '110001', 'spa',
    '45 Connaught Place, Block C',
    'Full-body spa, aromatherapy, and wellness treatments in central Delhi.',
    '07AABCB5678B2Z9', 'https://blissbeautyspa.com', 28.6315, 77.2167,
    NULL, true, 'pending'
  ),
  (
    'a1000001-0000-4000-8000-000000000003',
    'Radiance Makeup Studio', 'Kavya Menon',
    '+91 87654 32109', 'bookings@radiancemakeup.in', '+91 87654 32109', '+91 90001 23456',
    'Bengaluru', 'Karnataka', '560034', 'beauty_studio',
    '88 5th Block, Koramangala',
    'Professional makeup for events, photoshoots, and bridal looks.',
    NULL, 'https://radiancemakeup.in', 12.9352, 77.6245,
    'Freelance artist team — verify GST before approval.', true, 'pending'
  ),
  (
    'a1000001-0000-4000-8000-000000000004',
    'Urban Groom Lounge', 'Rahul Verma',
    '+91 96543 21098', 'contact@urbangroom.in', '+91 96543 21098', '+91 98760 12345',
    'Hyderabad', 'Telangana', '500081', 'salon',
    '22 Hitech City Main Road, Madhapur',
    'Men''s grooming, beard styling, and premium haircuts.',
    '36AABCU9012C3Z1', NULL, 17.4486, 78.3908,
    NULL, true, 'approved'
  ),
  (
    'a1000001-0000-4000-8000-000000000005',
    'Pearl Bridal Studio', 'Meera Patel',
    '+91 95432 10987', 'meera@pearlbridal.com', '+91 95432 10987', NULL,
    'Pune', 'Maharashtra', '411001', 'freelance',
    '9 FC Road, Shivajinagar',
    'Bridal makeup, mehendi, and pre-wedding beauty consultations.',
    '27AABCP3456D4Z8', 'https://pearlbridal.com', 18.5204, 73.8567,
    'High demand during wedding season.', false, 'rejected'
  )
ON CONFLICT (id) DO NOTHING;

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
