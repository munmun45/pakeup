-- ============================================================
-- PakeUp – Initial Database Schema (Supabase / PostgreSQL)
-- Run via: supabase db reset   OR   paste in SQL Editor
-- ============================================================

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS postgis;

-- ============================================================
-- ENUMS
-- ============================================================
CREATE TYPE user_role AS ENUM ('customer', 'salon_partner', 'admin');
CREATE TYPE salon_status AS ENUM ('pending', 'approved', 'rejected', 'suspended');
CREATE TYPE subscription_tier AS ENUM ('free', 'verified', 'pro', 'premium');
CREATE TYPE booking_type AS ENUM ('in_salon', 'home_visit', 'bridal');
CREATE TYPE booking_status AS ENUM (
  'pending', 'confirmed', 'rejected', 'in_progress',
  'completed', 'cancelled', 'no_show'
);
CREATE TYPE payment_status AS ENUM ('pending', 'paid', 'failed', 'refunded');
CREATE TYPE kyc_status AS ENUM ('not_submitted', 'pending', 'approved', 'rejected');
CREATE TYPE ai_plan_type AS ENUM ('free', 'pack_10', 'pack_25', 'unlimited');
CREATE TYPE coupon_type AS ENUM ('flat', 'percentage');
CREATE TYPE transaction_type AS ENUM ('credit', 'debit');
CREATE TYPE wallet_source AS ENUM (
  'referral', 'refund', 'cashback', 'admin_credit', 'booking_payment'
);

-- ============================================================
-- PROFILES (extends auth.users)
-- ============================================================

CREATE TABLE profiles (
  id              UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role            user_role NOT NULL DEFAULT 'customer',
  full_name       TEXT,
  phone           TEXT UNIQUE,
  email           TEXT,
  avatar_url      TEXT,
  referral_code   TEXT UNIQUE,
  referred_by     UUID REFERENCES profiles(id),
  fcm_token       TEXT,
  device_id       TEXT,
  is_active       BOOLEAN NOT NULL DEFAULT true,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, phone, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name'),
    NEW.phone,
    COALESCE((NEW.raw_user_meta_data->>'role')::user_role, 'customer')
  );
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- updated_at helper
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ============================================================
-- SALONS
-- ============================================================
CREATE TABLE salons (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id              UUID NOT NULL REFERENCES profiles(id),
  name                  TEXT NOT NULL,
  slug                  TEXT UNIQUE,
  description           TEXT,
  logo_url              TEXT,
  cover_url             TEXT,
  phone                 TEXT,
  email                 TEXT,
  address_line          TEXT,
  city                  TEXT,
  state                 TEXT,
  pincode               TEXT,
  latitude              DOUBLE PRECISION,
  longitude             DOUBLE PRECISION,
  location              GEOGRAPHY(POINT, 4326),
  status                salon_status NOT NULL DEFAULT 'pending',
  kyc_status            kyc_status NOT NULL DEFAULT 'not_submitted',
  subscription          subscription_tier NOT NULL DEFAULT 'free',
  subscription_expires_at TIMESTAMPTZ,
  rating_avg            DECIMAL(3,2) NOT NULL DEFAULT 0,
  rating_count          INT NOT NULL DEFAULT 0,
  is_featured           BOOLEAN NOT NULL DEFAULT false,
  home_visit_enabled    BOOLEAN NOT NULL DEFAULT false,
  home_visit_radius_km  DECIMAL(5,2),
  travel_fee_per_km     DECIMAL(10,2),
  commission_rate       DECIMAL(5,2) NOT NULL DEFAULT 10.00,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER salons_updated_at
  BEFORE UPDATE ON salons
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE salon_kyc (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  salon_id          UUID NOT NULL REFERENCES salons(id) ON DELETE CASCADE,
  business_name     TEXT,
  gst_number        TEXT,
  pan_number        TEXT,
  id_proof_url      TEXT,
  address_proof_url TEXT,
  status            kyc_status NOT NULL DEFAULT 'pending',
  reviewed_by       UUID REFERENCES profiles(id),
  reviewed_at       TIMESTAMPTZ,
  rejection_reason  TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- CATEGORIES & SERVICES
-- ============================================================
CREATE TABLE categories (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL,
  slug        TEXT UNIQUE NOT NULL,
  icon_url    TEXT,
  sort_order  INT NOT NULL DEFAULT 0,
  is_active   BOOLEAN NOT NULL DEFAULT true
);

CREATE TABLE salon_categories (
  salon_id    UUID NOT NULL REFERENCES salons(id) ON DELETE CASCADE,
  category_id UUID NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
  PRIMARY KEY (salon_id, category_id)
);

CREATE TABLE services (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  salon_id         UUID NOT NULL REFERENCES salons(id) ON DELETE CASCADE,
  category_id      UUID REFERENCES categories(id),
  name             TEXT NOT NULL,
  description      TEXT,
  duration_minutes INT NOT NULL,
  price            DECIMAL(10,2) NOT NULL,
  home_visit_price DECIMAL(10,2),
  is_bridal        BOOLEAN NOT NULL DEFAULT false,
  is_active        BOOLEAN NOT NULL DEFAULT true,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE salon_schedules (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  salon_id    UUID NOT NULL REFERENCES salons(id) ON DELETE CASCADE,
  day_of_week INT NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
  open_time   TIME NOT NULL,
  close_time  TIME NOT NULL,
  is_closed   BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE salon_staff (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  salon_id    UUID NOT NULL REFERENCES salons(id) ON DELETE CASCADE,
  profile_id  UUID REFERENCES profiles(id),
  name        TEXT NOT NULL,
  role        TEXT,
  is_active   BOOLEAN NOT NULL DEFAULT true
);

-- ============================================================
-- BOOKINGS
-- ============================================================
CREATE TABLE bookings (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_number      TEXT UNIQUE,
  customer_id         UUID NOT NULL REFERENCES profiles(id),
  salon_id            UUID NOT NULL REFERENCES salons(id),
  staff_id            UUID REFERENCES salon_staff(id),
  booking_type        booking_type NOT NULL,
  status              booking_status NOT NULL DEFAULT 'pending',
  scheduled_at        TIMESTAMPTZ NOT NULL,
  service_total       DECIMAL(10,2) NOT NULL,
  travel_fee          DECIMAL(10,2) NOT NULL DEFAULT 0,
  discount_amount     DECIMAL(10,2) NOT NULL DEFAULT 0,
  total_amount        DECIMAL(10,2) NOT NULL,
  commission_rate     DECIMAL(5,2) NOT NULL DEFAULT 10.00,
  commission_amount   DECIMAL(10,2),
  salon_payout        DECIMAL(10,2),
  payment_status      payment_status NOT NULL DEFAULT 'pending',
  payment_id          TEXT,
  coupon_id           UUID,
  home_address        JSONB,
  distance_km         DECIMAL(6,2),
  notes               TEXT,
  cancelled_by        UUID REFERENCES profiles(id),
  cancellation_reason TEXT,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER bookings_updated_at
  BEFORE UPDATE ON bookings
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE booking_services (
  booking_id       UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  service_id       UUID REFERENCES services(id),
  service_name     TEXT NOT NULL,
  price            DECIMAL(10,2) NOT NULL,
  duration_minutes INT NOT NULL,
  PRIMARY KEY (booking_id, service_id)
);

-- Auto booking number
CREATE OR REPLACE FUNCTION public.generate_booking_number()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.booking_number IS NULL THEN
    NEW.booking_number := 'BK-' || LPAD(nextval('booking_number_seq')::TEXT, 6, '0');
  END IF;
  RETURN NEW;
END;
$$;

CREATE SEQUENCE booking_number_seq START 1000;

CREATE TRIGGER bookings_set_number
  BEFORE INSERT ON bookings
  FOR EACH ROW EXECUTE FUNCTION public.generate_booking_number();

-- ============================================================
-- REELS & REVIEWS
-- ============================================================
CREATE TABLE reels (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  salon_id          UUID NOT NULL REFERENCES salons(id) ON DELETE CASCADE,
  video_url         TEXT NOT NULL,
  thumbnail_url     TEXT,
  caption           TEXT,
  service_id        UUID REFERENCES services(id),
  view_count        INT NOT NULL DEFAULT 0,
  like_count        INT NOT NULL DEFAULT 0,
  is_active         BOOLEAN NOT NULL DEFAULT true,
  moderation_status TEXT NOT NULL DEFAULT 'pending',
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE reel_likes (
  reel_id     UUID NOT NULL REFERENCES reels(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (reel_id, user_id)
);

CREATE TABLE reel_saves (
  reel_id     UUID NOT NULL REFERENCES reels(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (reel_id, user_id)
);

CREATE TABLE reviews (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id  UUID UNIQUE REFERENCES bookings(id),
  customer_id UUID NOT NULL REFERENCES profiles(id),
  salon_id    UUID NOT NULL REFERENCES salons(id),
  rating      INT NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment     TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- WALLET & COUPONS
-- ============================================================
CREATE TABLE wallets (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL UNIQUE REFERENCES profiles(id),
  balance     DECIMAL(10,2) NOT NULL DEFAULT 0,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE wallet_transactions (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id     UUID NOT NULL REFERENCES wallets(id),
  type          transaction_type NOT NULL,
  amount        DECIMAL(10,2) NOT NULL,
  source        wallet_source NOT NULL,
  reference_id  UUID,
  description   TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE coupons (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code          TEXT NOT NULL UNIQUE,
  type          coupon_type NOT NULL,
  value         DECIMAL(10,2) NOT NULL,
  min_order     DECIMAL(10,2) NOT NULL DEFAULT 0,
  max_discount  DECIMAL(10,2),
  usage_limit   INT,
  used_count    INT NOT NULL DEFAULT 0,
  valid_from    TIMESTAMPTZ,
  valid_until   TIMESTAMPTZ,
  salon_id      UUID REFERENCES salons(id),
  is_active     BOOLEAN NOT NULL DEFAULT true,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- AI
-- ============================================================
CREATE TABLE ai_usage (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES profiles(id),
  month_year      TEXT NOT NULL,
  free_used       INT NOT NULL DEFAULT 0,
  paid_used       INT NOT NULL DEFAULT 0,
  ad_earned       INT NOT NULL DEFAULT 0,
  plan_type       ai_plan_type NOT NULL DEFAULT 'free',
  plan_expires_at TIMESTAMPTZ,
  UNIQUE (user_id, month_year)
);

CREATE TABLE ai_analyses (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES profiles(id),
  selfie_url  TEXT,
  result_json JSONB,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE ai_purchases (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES profiles(id),
  plan_type   ai_plan_type NOT NULL,
  amount      DECIMAL(10,2) NOT NULL,
  payment_id  TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- AFFILIATE & PROMOTIONS
-- ============================================================
CREATE TABLE affiliate_products (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name            TEXT NOT NULL,
  brand           TEXT,
  category        TEXT,
  image_url       TEXT,
  price_display   TEXT,
  affiliate_url   TEXT NOT NULL,
  commission_pct  DECIMAL(5,2),
  is_active       BOOLEAN NOT NULL DEFAULT true,
  sort_order      INT NOT NULL DEFAULT 0,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE affiliate_clicks (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id  UUID REFERENCES affiliate_products(id),
  user_id     UUID REFERENCES profiles(id),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE salon_subscriptions (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  salon_id    UUID NOT NULL REFERENCES salons(id),
  tier        subscription_tier NOT NULL,
  amount      DECIMAL(10,2) NOT NULL,
  payment_id  TEXT,
  starts_at   TIMESTAMPTZ NOT NULL,
  expires_at  TIMESTAMPTZ NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE promotions (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  salon_id      UUID REFERENCES salons(id),
  title         TEXT NOT NULL,
  description   TEXT,
  banner_url    TEXT,
  discount_pct  DECIMAL(5,2),
  starts_at     TIMESTAMPTZ,
  ends_at       TIMESTAMPTZ,
  is_active     BOOLEAN NOT NULL DEFAULT true,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- NOTIFICATIONS & SECURITY
-- ============================================================
CREATE TABLE notifications (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES profiles(id),
  title       TEXT NOT NULL,
  body        TEXT,
  type        TEXT,
  data        JSONB,
  is_read     BOOLEAN NOT NULL DEFAULT false,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE device_sessions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES profiles(id),
  device_id       TEXT NOT NULL,
  platform        TEXT,
  last_active_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, device_id)
);

CREATE TABLE platform_settings (
  key         TEXT PRIMARY KEY,
  value       JSONB NOT NULL,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- INDEXES
-- ============================================================
CREATE INDEX idx_profiles_role ON profiles(role);
CREATE INDEX idx_profiles_phone ON profiles(phone);
CREATE INDEX idx_salons_owner ON salons(owner_id);
CREATE INDEX idx_salons_status ON salons(status) WHERE status = 'approved';
CREATE INDEX idx_salons_location ON salons USING GIST (location);
CREATE INDEX idx_salons_city ON salons(city);
CREATE INDEX idx_bookings_customer ON bookings(customer_id, created_at DESC);
CREATE INDEX idx_bookings_salon ON bookings(salon_id, scheduled_at);
CREATE INDEX idx_bookings_status ON bookings(status);
CREATE INDEX idx_reels_salon ON reels(salon_id, created_at DESC);
CREATE INDEX idx_reels_feed ON reels(is_active, moderation_status, created_at DESC);
CREATE INDEX idx_notifications_user ON notifications(user_id, created_at DESC);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE salons ENABLE ROW LEVEL SECURITY;
ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE reels ENABLE ROW LEVEL SECURITY;
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Helper: check if current user is admin
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid() AND role = 'admin'
  );
$$;

-- Profiles
CREATE POLICY "Users read own profile"
  ON profiles FOR SELECT
  USING (auth.uid() = id OR public.is_admin());

CREATE POLICY "Users update own profile"
  ON profiles FOR UPDATE
  USING (auth.uid() = id OR public.is_admin());

CREATE POLICY "Admin manage all profiles"
  ON profiles FOR ALL
  USING (public.is_admin());

-- Salons
CREATE POLICY "Public read approved salons"
  ON salons FOR SELECT
  USING (status = 'approved' OR owner_id = auth.uid() OR public.is_admin());

CREATE POLICY "Owner manage own salon"
  ON salons FOR ALL
  USING (owner_id = auth.uid() OR public.is_admin());

-- Bookings
CREATE POLICY "Customer read own bookings"
  ON bookings FOR SELECT
  USING (
    customer_id = auth.uid()
    OR salon_id IN (SELECT id FROM salons WHERE owner_id = auth.uid())
    OR public.is_admin()
  );

CREATE POLICY "Customer create bookings"
  ON bookings FOR INSERT
  WITH CHECK (customer_id = auth.uid());

CREATE POLICY "Salon owner update bookings"
  ON bookings FOR UPDATE
  USING (
    salon_id IN (SELECT id FROM salons WHERE owner_id = auth.uid())
    OR public.is_admin()
  );

-- Reels
CREATE POLICY "Public read approved reels"
  ON reels FOR SELECT
  USING (
    (is_active = true AND moderation_status = 'approved')
    OR salon_id IN (SELECT id FROM salons WHERE owner_id = auth.uid())
    OR public.is_admin()
  );

CREATE POLICY "Salon owner manage reels"
  ON reels FOR ALL
  USING (
    salon_id IN (SELECT id FROM salons WHERE owner_id = auth.uid())
    OR public.is_admin()
  );

-- Reviews
CREATE POLICY "Public read reviews"
  ON reviews FOR SELECT USING (true);

CREATE POLICY "Customer create review"
  ON reviews FOR INSERT
  WITH CHECK (customer_id = auth.uid());

-- Wallets
CREATE POLICY "User read own wallet"
  ON wallets FOR SELECT
  USING (user_id = auth.uid() OR public.is_admin());

-- Notifications
CREATE POLICY "User read own notifications"
  ON notifications FOR SELECT
  USING (user_id = auth.uid() OR public.is_admin());

CREATE POLICY "User update own notifications"
  ON notifications FOR UPDATE
  USING (user_id = auth.uid());
