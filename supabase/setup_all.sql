-- ============================================================
-- PakeUp – Admin-Only Database Schema (Supabase / PostgreSQL)
-- Consolidated from all admin migrations.
-- Run via: supabase db reset   OR   paste in Supabase SQL Editor
--
-- TABLES:
--   admin                     – admin user accounts
--   admin_pages               – available page keys for access control
--   admin_page_access         – which pages each admin can access
--   partners                  – salon/beauty partner onboarding
--   partner_categories        – dynamic partner category dropdown
--   partner_kyc_details       – KYC details per partner
--   partner_otp_verifications – phone/WhatsApp/email verification OTPs
--   partner_services          – services offered by each partner
--   partner_accounts          – partner store login accounts
-- ============================================================

-- ============================================================
-- ENUMS
-- ============================================================
DO $$ BEGIN
  CREATE TYPE admin_role AS ENUM ('super_admin', 'admin');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ============================================================
-- HELPER FUNCTIONS
-- ============================================================
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- ============================================================
-- ADMIN TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS admin (
  id         TEXT PRIMARY KEY,
  pass       TEXT NOT NULL,
  role       admin_role NOT NULL DEFAULT 'admin',
  name       TEXT,
  phone      TEXT,
  notes      TEXT,
  is_active  BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE admin ENABLE ROW LEVEL SECURITY;

INSERT INTO admin (id, pass, role, name) VALUES
  ('superadmin', 'admin123', 'super_admin', 'Super Admin'),
  ('admin',      'admin123', 'admin',       'Admin User')
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- ADMIN PAGE ACCESS CONTROL
-- ============================================================
CREATE TABLE IF NOT EXISTS admin_pages (
  page_key   TEXT PRIMARY KEY,
  label      TEXT NOT NULL,
  sort_order INT NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS admin_page_access (
  admin_id  TEXT NOT NULL REFERENCES admin(id) ON DELETE CASCADE ON UPDATE CASCADE,
  page_key  TEXT NOT NULL REFERENCES admin_pages(page_key) ON DELETE CASCADE,
  PRIMARY KEY (admin_id, page_key)
);

INSERT INTO admin_pages (page_key, label, sort_order) VALUES
  ('dashboard',          'Dashboard',          1),
  ('users',              'Users',              2),
  ('salons',             'Salons',             3),
  ('bookings',           'Bookings',           4),
  ('payments',           'Payments',           5),
  ('commissions',        'Commissions',        6),
  ('coupons',            'Coupons',            7),
  ('ai_monitor',         'AI Monitor',         8),
  ('ads',                'Ads',                9),
  ('affiliates',         'Affiliates',         10),
  ('moderation',         'Moderation',         11),
  ('reports',            'Reports',            12),
  ('notifications',      'Notifications',      13),
  ('settings',           'Settings',           14),
  ('manage_admins',      'Manage Admins',      15),
  ('add_partners',       'Add Partners',       16),
  ('partner_kyc',        'KYC',                17),
  ('partner_services',   'Partner Services',   18),
  ('partner_accounts',   'Partner Accounts',   19),
  ('partner_categories', 'Partner Categories', 20)
ON CONFLICT (page_key) DO NOTHING;

INSERT INTO admin_page_access (admin_id, page_key)
SELECT 'admin', page_key FROM admin_pages
WHERE page_key IN (
  'dashboard', 'users', 'salons', 'bookings',
  'add_partners', 'partner_kyc', 'partner_services', 'partner_categories'
)
ON CONFLICT DO NOTHING;

-- ============================================================
-- PARTNER ACCOUNTS (store login)
-- ============================================================
CREATE TABLE IF NOT EXISTS partner_accounts (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_name      TEXT NOT NULL,
  phone           TEXT,
  email           TEXT,
  whatsapp        TEXT,
  alternate_phone TEXT,
  login_id        TEXT,
  pass            TEXT,
  is_active       BOOLEAN NOT NULL DEFAULT true,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

DROP TRIGGER IF EXISTS partner_accounts_updated_at ON partner_accounts;
CREATE TRIGGER partner_accounts_updated_at
  BEFORE UPDATE ON partner_accounts
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ============================================================
-- PARTNERS
-- ============================================================
CREATE TABLE IF NOT EXISTS partners (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id       UUID REFERENCES partner_accounts(id) ON DELETE SET NULL,
  business_name    TEXT NOT NULL,
  owner_name       TEXT NOT NULL,
  phone            TEXT,
  email            TEXT,
  whatsapp         TEXT,
  alternate_phone  TEXT,
  city             TEXT,
  state            TEXT,
  pincode          TEXT,
  category         TEXT NOT NULL DEFAULT 'salon',
  address_line     TEXT,
  description      TEXT,
  gst_number       TEXT,
  website          TEXT,
  google_map_embed TEXT,
  latitude         DOUBLE PRECISION,
  longitude        DOUBLE PRECISION,
  notes            TEXT,
  is_active        BOOLEAN NOT NULL DEFAULT true,
  kyc_status       TEXT NOT NULL DEFAULT 'pending'
                   CHECK (kyc_status IN ('pending', 'approved', 'rejected')),
  login_id         TEXT,
  pass             TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_partners_active ON partners(is_active);
CREATE INDEX IF NOT EXISTS idx_partners_kyc    ON partners(kyc_status);

DROP TRIGGER IF EXISTS partners_updated_at ON partners;
CREATE TRIGGER partners_updated_at
  BEFORE UPDATE ON partners
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ============================================================
-- PARTNER CATEGORIES
-- ============================================================
CREATE TABLE IF NOT EXISTS partner_categories (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug       TEXT NOT NULL UNIQUE,
  name       TEXT NOT NULL,
  is_active  BOOLEAN NOT NULL DEFAULT true,
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO partner_categories (slug, name, sort_order) VALUES
  ('salon',          'Salon',          1),
  ('spa',            'Spa',            2),
  ('beauty_studio',  'Beauty Studio',  3),
  ('freelance',      'Freelance',      4)
ON CONFLICT (slug) DO NOTHING;

-- ============================================================
-- PARTNER KYC DETAILS
-- ============================================================
CREATE TABLE IF NOT EXISTS partner_kyc_details (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  partner_id            UUID NOT NULL UNIQUE REFERENCES partners(id) ON DELETE CASCADE,
  property_type         TEXT CHECK (property_type IN ('own', 'lease', 'rent')),
  pan_number            TEXT,
  aadhaar_number        TEXT,
  bank_account_holder   TEXT,
  bank_name             TEXT,
  ifsc_code             TEXT,
  account_number        TEXT,
  aadhaar_doc_url       TEXT,
  pan_doc_url           TEXT,
  agreement_doc_url     TEXT,
  gst_doc_url           TEXT,
  passbook_doc_url      TEXT,
  other_doc_url         TEXT,
  other_doc_name        TEXT,
  submitted_at          TIMESTAMPTZ,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_partner_kyc_details_partner ON partner_kyc_details(partner_id);

DROP TRIGGER IF EXISTS partner_kyc_details_updated_at ON partner_kyc_details;
CREATE TRIGGER partner_kyc_details_updated_at
  BEFORE UPDATE ON partner_kyc_details
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ============================================================
-- PARTNER OTP VERIFICATIONS
-- ============================================================
CREATE TABLE IF NOT EXISTS partner_otp_verifications (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id    TEXT NOT NULL,
  phone       TEXT NOT NULL,
  channel     TEXT NOT NULL CHECK (channel IN ('mobile', 'whatsapp', 'email', 'alternate')),
  otp_code    TEXT NOT NULL,
  token       UUID UNIQUE,
  verified_at TIMESTAMPTZ,
  consumed_at TIMESTAMPTZ,
  expires_at  TIMESTAMPTZ NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_partner_otp_admin_phone_channel
  ON partner_otp_verifications (admin_id, phone, channel, created_at DESC);

-- ============================================================
-- PARTNER SERVICES
-- ============================================================
CREATE TABLE IF NOT EXISTS partner_services (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  partner_id       UUID NOT NULL REFERENCES partners(id) ON DELETE CASCADE,
  name             TEXT NOT NULL,
  description      TEXT,
  price            DECIMAL(10,2),
  duration_minutes INT,
  is_active        BOOLEAN NOT NULL DEFAULT true,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

DROP TRIGGER IF EXISTS partner_services_updated_at ON partner_services;
CREATE TRIGGER partner_services_updated_at
  BEFORE UPDATE ON partner_services
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ============================================================
-- RPCs – ADMIN LOGIN
-- ============================================================
CREATE OR REPLACE FUNCTION verify_admin(login_id TEXT, login_pass TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  admin_row admin%ROWTYPE;
  pages     JSON;
BEGIN
  SELECT * INTO admin_row
  FROM admin
  WHERE id = login_id AND pass = login_pass;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  IF NOT admin_row.is_active THEN
    RETURN json_build_object('error', 'deactivated');
  END IF;

  IF admin_row.role = 'super_admin' THEN
    SELECT COALESCE(json_agg(page_key ORDER BY sort_order), '[]'::json)
    INTO pages
    FROM admin_pages;
  ELSE
    SELECT COALESCE(json_agg(a.page_key ORDER BY p.sort_order), '[]'::json)
    INTO pages
    FROM admin_page_access a
    JOIN admin_pages p ON p.page_key = a.page_key
    WHERE a.admin_id = admin_row.id;
  END IF;

  RETURN json_build_object(
    'id',         admin_row.id,
    'role',       admin_row.role::text,
    'name',       admin_row.name,
    'phone',      admin_row.phone,
    'notes',      admin_row.notes,
    'is_active',  admin_row.is_active,
    'created_at', admin_row.created_at,
    'pages',      pages
  );
END;
$$;

GRANT EXECUTE ON FUNCTION verify_admin(TEXT, TEXT) TO anon, authenticated, service_role;

-- ============================================================
-- RPCs – ADMIN PROFILE
-- ============================================================
CREATE OR REPLACE FUNCTION get_admin_profile(caller_id TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  admin_row admin%ROWTYPE;
  pages     JSON;
BEGIN
  SELECT * INTO admin_row FROM admin WHERE id = caller_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Admin account not found';
  END IF;

  IF admin_row.role = 'super_admin' THEN
    SELECT COALESCE(json_agg(page_key ORDER BY sort_order), '[]'::json)
    INTO pages FROM admin_pages;
  ELSE
    SELECT COALESCE(json_agg(a.page_key ORDER BY p.sort_order), '[]'::json)
    INTO pages
    FROM admin_page_access a
    JOIN admin_pages p ON p.page_key = a.page_key
    WHERE a.admin_id = admin_row.id;
  END IF;

  RETURN json_build_object(
    'id',         admin_row.id,
    'role',       admin_row.role::text,
    'name',       admin_row.name,
    'phone',      admin_row.phone,
    'notes',      admin_row.notes,
    'is_active',  admin_row.is_active,
    'created_at', admin_row.created_at,
    'pages',      pages
  );
END;
$$;

GRANT EXECUTE ON FUNCTION get_admin_profile(TEXT) TO anon, authenticated, service_role;

-- ============================================================
-- RPCs – ADMIN USER MANAGEMENT
-- ============================================================
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
    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json)
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
      ORDER BY a.role DESC, a.id
    ) t
  );
END;
$$;

CREATE OR REPLACE FUNCTION create_admin_user(
  caller_id   TEXT,
  new_id      TEXT,
  new_pass    TEXT,
  page_keys   TEXT[],
  admin_name  TEXT DEFAULT NULL,
  admin_phone TEXT DEFAULT NULL,
  admin_notes TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM admin WHERE id = caller_id AND role = 'super_admin'
  ) THEN
    RAISE EXCEPTION 'Only Super Admin can create admins';
  END IF;

  IF new_id IS NULL OR trim(new_id) = '' THEN
    RAISE EXCEPTION 'Admin ID is required';
  END IF;

  IF new_pass IS NULL OR length(new_pass) < 4 THEN
    RAISE EXCEPTION 'Password must be at least 4 characters';
  END IF;

  IF EXISTS (SELECT 1 FROM admin WHERE id = new_id) THEN
    RAISE EXCEPTION 'Admin ID already exists';
  END IF;

  INSERT INTO admin (id, pass, role, name, phone, notes)
  VALUES (
    new_id, new_pass, 'admin',
    NULLIF(trim(admin_name), ''),
    NULLIF(trim(admin_phone), ''),
    NULLIF(trim(admin_notes), '')
  );

  INSERT INTO admin_page_access (admin_id, page_key)
  SELECT new_id, pk
  FROM unnest(page_keys) AS pk
  WHERE pk IN (SELECT page_key FROM admin_pages WHERE page_key != 'manage_admins');

  RETURN json_build_object('id', new_id, 'role', 'admin');
END;
$$;

CREATE OR REPLACE FUNCTION update_admin_user(
  caller_id   TEXT,
  target_id   TEXT,
  page_keys   TEXT[],
  admin_name  TEXT DEFAULT NULL,
  admin_phone TEXT DEFAULT NULL,
  admin_notes TEXT DEFAULT NULL,
  new_id      TEXT DEFAULT NULL,
  new_pass    TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_final_id TEXT;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM admin WHERE id = caller_id AND role = 'super_admin'
  ) THEN
    RAISE EXCEPTION 'Only Super Admin can update admins';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM admin WHERE id = target_id AND role = 'admin') THEN
    RAISE EXCEPTION 'Can only update regular admin accounts';
  END IF;

  v_final_id := COALESCE(NULLIF(trim(new_id), ''), target_id);

  IF v_final_id <> target_id THEN
    IF EXISTS (SELECT 1 FROM admin WHERE id = v_final_id) THEN
      RAISE EXCEPTION 'Admin ID already exists';
    END IF;
  END IF;

  IF new_pass IS NOT NULL AND trim(new_pass) <> '' AND length(trim(new_pass)) < 4 THEN
    RAISE EXCEPTION 'Password must be at least 4 characters';
  END IF;

  UPDATE admin
  SET
    id    = v_final_id,
    name  = NULLIF(trim(admin_name), ''),
    phone = NULLIF(trim(admin_phone), ''),
    notes = NULLIF(trim(admin_notes), ''),
    pass  = CASE
      WHEN new_pass IS NOT NULL AND trim(new_pass) <> '' THEN trim(new_pass)
      ELSE pass
    END
  WHERE id = target_id;

  DELETE FROM admin_page_access WHERE admin_id = v_final_id;

  INSERT INTO admin_page_access (admin_id, page_key)
  SELECT v_final_id, pk
  FROM unnest(page_keys) AS pk
  WHERE pk IN (SELECT page_key FROM admin_pages WHERE page_key != 'manage_admins');

  RETURN json_build_object('id', v_final_id, 'updated', true);
END;
$$;

CREATE OR REPLACE FUNCTION delete_admin_user(caller_id TEXT, target_id TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM admin WHERE id = caller_id AND role = 'super_admin'
  ) THEN
    RAISE EXCEPTION 'Only Super Admin can delete admins';
  END IF;

  IF target_id = caller_id THEN
    RAISE EXCEPTION 'Cannot delete your own account';
  END IF;

  IF EXISTS (SELECT 1 FROM admin WHERE id = target_id AND role = 'super_admin') THEN
    RAISE EXCEPTION 'Cannot delete Super Admin accounts';
  END IF;

  DELETE FROM admin WHERE id = target_id AND role = 'admin';

  RETURN json_build_object('deleted', target_id);
END;
$$;

CREATE OR REPLACE FUNCTION set_admin_active(
  caller_id TEXT,
  target_id TEXT,
  active    BOOLEAN
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM admin WHERE id = caller_id AND role = 'super_admin'
  ) THEN
    RAISE EXCEPTION 'Only Super Admin can change admin status';
  END IF;

  IF caller_id = target_id THEN
    RAISE EXCEPTION 'You cannot change your own account status';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM admin WHERE id = target_id AND role = 'admin') THEN
    RAISE EXCEPTION 'Can only change status for regular admin accounts';
  END IF;

  UPDATE admin SET is_active = active WHERE id = target_id AND role = 'admin';

  RETURN json_build_object('id', target_id, 'is_active', active);
END;
$$;

CREATE OR REPLACE FUNCTION list_admin_pages()
RETURNS JSON
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(json_agg(json_build_object(
    'page_key',   page_key,
    'label',      label,
    'sort_order', sort_order
  ) ORDER BY sort_order), '[]'::json)
  FROM admin_pages
  WHERE page_key != 'manage_admins';
$$;

GRANT EXECUTE ON FUNCTION list_admin_users(TEXT)                             TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION create_admin_user(TEXT, TEXT, TEXT, TEXT[], TEXT, TEXT, TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION update_admin_user(TEXT, TEXT, TEXT[], TEXT, TEXT, TEXT, TEXT, TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION delete_admin_user(TEXT, TEXT)                      TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION set_admin_active(TEXT, TEXT, BOOLEAN)              TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION list_admin_pages()                                 TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION get_admin_profile(TEXT)                            TO anon, authenticated, service_role;

-- ============================================================
-- RPCs – PARTNER ACCESS GUARD
-- ============================================================
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
              'add_partners', 'partner_kyc', 'partner_services', 'partner_categories', 'partner_accounts'
            )
        )
      )
  ) THEN
    RAISE EXCEPTION 'Access denied';
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION assert_admin_partner_access(TEXT) TO anon, authenticated, service_role;

-- ============================================================
-- RPCs – PARTNER ACCOUNTS LIST (RECENT TOP)
-- ============================================================
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

-- ============================================================
-- RPCs – PARTNERS CRUD
-- ============================================================
CREATE OR REPLACE FUNCTION list_partners(caller_id TEXT)
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
        p.id,
        p.account_id,
        p.business_name,
        p.owner_name,
        p.phone,
        p.email,
        p.whatsapp,
        p.alternate_phone,
        p.city,
        p.state,
        p.pincode,
        p.category,
        COALESCE(pc.name, p.category) AS category_name,
        p.address_line,
        p.description,
        p.gst_number,
        p.website,
        p.google_map_embed,
        p.latitude,
        p.longitude,
        p.notes,
        p.is_active,
        p.kyc_status,
        p.created_at
      FROM partners p
      LEFT JOIN partner_categories pc ON pc.slug = p.category
    ) t
  );
END;
$$;

CREATE OR REPLACE FUNCTION create_partner(
  caller_id        TEXT,
  business_name    TEXT,
  owner_name       TEXT,
  phone            TEXT DEFAULT NULL,
  email            TEXT DEFAULT NULL,
  whatsapp         TEXT DEFAULT NULL,
  alternate_phone  TEXT DEFAULT NULL,
  city             TEXT DEFAULT NULL,
  state            TEXT DEFAULT NULL,
  pincode          TEXT DEFAULT NULL,
  category         TEXT DEFAULT 'salon',
  address_line     TEXT DEFAULT NULL,
  description      TEXT DEFAULT NULL,
  gst_number       TEXT DEFAULT NULL,
  website          TEXT DEFAULT NULL,
  google_map_embed TEXT DEFAULT NULL,
  latitude         DOUBLE PRECISION DEFAULT NULL,
  longitude        DOUBLE PRECISION DEFAULT NULL,
  notes            TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  new_row partners%ROWTYPE;
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  IF trim(business_name) = '' OR trim(owner_name) = '' THEN
    RAISE EXCEPTION 'Business name and owner name are required';
  END IF;

  INSERT INTO partners (
    business_name, owner_name, phone, email, whatsapp, alternate_phone,
    city, state, pincode, category, address_line, description,
    gst_number, website, google_map_embed, latitude, longitude, notes
  ) VALUES (
    trim(business_name),
    trim(owner_name),
    nullif(trim(phone), ''),
    nullif(trim(email), ''),
    nullif(trim(whatsapp), ''),
    nullif(trim(alternate_phone), ''),
    nullif(trim(city), ''),
    nullif(trim(state), ''),
    nullif(trim(pincode), ''),
    coalesce(nullif(trim(category), ''), 'salon'),
    nullif(trim(address_line), ''),
    nullif(trim(description), ''),
    nullif(trim(gst_number), ''),
    nullif(trim(website), ''),
    nullif(trim(google_map_embed), ''),
    create_partner.latitude,
    create_partner.longitude,
    nullif(trim(notes), '')
  )
  RETURNING * INTO new_row;

  RETURN row_to_json(new_row);
END;
$$;

CREATE OR REPLACE FUNCTION update_partner(
  caller_id        TEXT,
  partner_id       UUID,
  business_name    TEXT,
  owner_name       TEXT,
  phone            TEXT DEFAULT NULL,
  email            TEXT DEFAULT NULL,
  whatsapp         TEXT DEFAULT NULL,
  alternate_phone  TEXT DEFAULT NULL,
  city             TEXT DEFAULT NULL,
  state            TEXT DEFAULT NULL,
  pincode          TEXT DEFAULT NULL,
  category         TEXT DEFAULT 'salon',
  address_line     TEXT DEFAULT NULL,
  description      TEXT DEFAULT NULL,
  gst_number       TEXT DEFAULT NULL,
  website          TEXT DEFAULT NULL,
  google_map_embed TEXT DEFAULT NULL,
  latitude         DOUBLE PRECISION DEFAULT NULL,
  longitude        DOUBLE PRECISION DEFAULT NULL,
  notes            TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  updated_row partners%ROWTYPE;
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  IF trim(business_name) = '' OR trim(owner_name) = '' THEN
    RAISE EXCEPTION 'Business name and owner name are required';
  END IF;

  UPDATE partners SET
    business_name    = trim(business_name),
    owner_name       = trim(owner_name),
    phone            = nullif(trim(phone), ''),
    email            = nullif(trim(email), ''),
    whatsapp         = nullif(trim(whatsapp), ''),
    alternate_phone  = nullif(trim(alternate_phone), ''),
    city             = nullif(trim(city), ''),
    state            = nullif(trim(state), ''),
    pincode          = nullif(trim(pincode), ''),
    category         = coalesce(nullif(trim(category), ''), 'salon'),
    address_line     = nullif(trim(address_line), ''),
    description      = nullif(trim(description), ''),
    gst_number       = nullif(trim(gst_number), ''),
    website          = nullif(trim(website), ''),
    google_map_embed = nullif(trim(google_map_embed), ''),
    latitude         = update_partner.latitude,
    longitude        = update_partner.longitude,
    notes            = nullif(trim(notes), '')
  WHERE id = partner_id
  RETURNING * INTO updated_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Partner not found';
  END IF;

  RETURN row_to_json(updated_row);
END;
$$;

CREATE OR REPLACE FUNCTION delete_partner(caller_id TEXT, partner_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM assert_admin_partner_access(caller_id);
  DELETE FROM partners WHERE id = partner_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Partner not found';
  END IF;
  RETURN json_build_object('deleted', true);
END;
$$;

CREATE OR REPLACE FUNCTION set_partner_active(
  caller_id  TEXT,
  partner_id UUID,
  active     BOOLEAN
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  updated_row partners%ROWTYPE;
BEGIN
  PERFORM assert_admin_partner_access(caller_id);
  UPDATE partners SET is_active = active WHERE id = partner_id RETURNING * INTO updated_row;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Partner not found';
  END IF;
  RETURN row_to_json(updated_row);
END;
$$;

GRANT EXECUTE ON FUNCTION list_partners(TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION create_partner(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION update_partner(TEXT, UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION delete_partner(TEXT, UUID) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION set_partner_active(TEXT, UUID, BOOLEAN) TO anon, authenticated, service_role;

-- ============================================================
-- RPCs – PARTNER CATEGORIES
-- ============================================================
CREATE OR REPLACE FUNCTION list_partner_categories(caller_id TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  RETURN (
    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.sort_order, t.name), '[]'::json)
    FROM (
      SELECT id, slug, name, is_active, sort_order, created_at
      FROM partner_categories
    ) t
  );
END;
$$;

CREATE OR REPLACE FUNCTION create_partner_category(
  caller_id TEXT,
  cat_name  TEXT,
  cat_slug  TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  new_row    partner_categories%ROWTYPE;
  final_slug TEXT;
  next_order INT;
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  IF trim(cat_name) = '' THEN
    RAISE EXCEPTION 'Category name is required';
  END IF;

  final_slug := coalesce(
    nullif(trim(lower(cat_slug)), ''),
    lower(regexp_replace(trim(cat_name), '[^a-zA-Z0-9]+', '_', 'g'))
  );

  SELECT coalesce(max(sort_order), 0) + 1 INTO next_order FROM partner_categories;

  INSERT INTO partner_categories (slug, name, sort_order)
  VALUES (final_slug, trim(cat_name), next_order)
  RETURNING * INTO new_row;

  RETURN row_to_json(new_row);
EXCEPTION
  WHEN unique_violation THEN
    RAISE EXCEPTION 'Category slug already exists';
END;
$$;

CREATE OR REPLACE FUNCTION update_partner_category(
  caller_id   TEXT,
  category_id UUID,
  cat_name    TEXT,
  cat_slug    TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  updated_row partner_categories%ROWTYPE;
  old_slug    TEXT;
  final_slug  TEXT;
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  IF trim(cat_name) = '' THEN RAISE EXCEPTION 'Category name is required'; END IF;

  SELECT slug INTO old_slug FROM partner_categories WHERE id = category_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Category not found'; END IF;

  final_slug := coalesce(
    nullif(trim(lower(cat_slug)), ''),
    lower(regexp_replace(trim(cat_name), '[^a-zA-Z0-9]+', '_', 'g'))
  );

  UPDATE partner_categories SET name = trim(cat_name), slug = final_slug
  WHERE id = category_id
  RETURNING * INTO updated_row;

  UPDATE partners SET category = final_slug WHERE category = old_slug;

  RETURN row_to_json(updated_row);
EXCEPTION
  WHEN unique_violation THEN RAISE EXCEPTION 'Category slug already exists';
END;
$$;

CREATE OR REPLACE FUNCTION delete_partner_category(caller_id TEXT, category_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  cat_slug    TEXT;
  usage_count INT;
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  SELECT slug INTO cat_slug FROM partner_categories WHERE id = category_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Category not found'; END IF;

  SELECT count(*) INTO usage_count FROM partners WHERE category = cat_slug;
  IF usage_count > 0 THEN
    RAISE EXCEPTION 'Cannot delete — % partner(s) use this category', usage_count;
  END IF;

  DELETE FROM partner_categories WHERE id = category_id;

  RETURN json_build_object('deleted', true);
END;
$$;

CREATE OR REPLACE FUNCTION set_partner_category_active(
  caller_id   TEXT,
  category_id UUID,
  active      BOOLEAN
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  updated_row partner_categories%ROWTYPE;
BEGIN
  PERFORM assert_admin_partner_access(caller_id);
  UPDATE partner_categories SET is_active = active WHERE id = category_id RETURNING * INTO updated_row;
  IF NOT FOUND THEN RAISE EXCEPTION 'Category not found'; END IF;
  RETURN row_to_json(updated_row);
END;
$$;

GRANT EXECUTE ON FUNCTION list_partner_categories(TEXT)              TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION create_partner_category(TEXT, TEXT, TEXT)  TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION update_partner_category(TEXT, UUID, TEXT, TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION delete_partner_category(TEXT, UUID)        TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION set_partner_category_active(TEXT, UUID, BOOLEAN) TO anon, authenticated, service_role;
