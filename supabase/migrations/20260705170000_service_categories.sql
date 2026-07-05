-- ============================================================
-- Service Categories Table & RPC functions
-- Run this in your Supabase SQL Editor
-- ============================================================

-- 1. Create the service_categories table
CREATE TABLE IF NOT EXISTS service_categories (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL,
  slug        TEXT NOT NULL UNIQUE,
  is_active   BOOLEAN NOT NULL DEFAULT true,
  sort_order  INT NOT NULL DEFAULT 0,
  created_at  TIMESTAMPTZ DEFAULT now()
);

-- 2. Seed with the existing hard-coded service categories from the app
INSERT INTO service_categories (name, slug, sort_order) VALUES
  ('Hair Styling',          'hair_styling',          1),
  ('Hair Treatment',        'hair_treatment',         2),
  ('Makeup',                'makeup',                 3),
  ('Facial & Skin Care',    'facial_skin_care',       4),
  ('Massage & Spa',         'massage_spa',            5),
  ('Manicure & Pedicure',   'manicure_pedicure',      6),
  ('Bridal Package',        'bridal_package',         7),
  ('Others',                'others',                 8)
ON CONFLICT (slug) DO NOTHING;

-- 3. Drop old UUID-typed overloads (if any) to avoid overload conflict
DROP FUNCTION IF EXISTS list_service_categories(UUID);
DROP FUNCTION IF EXISTS create_service_category(UUID, TEXT, TEXT);
DROP FUNCTION IF EXISTS update_service_category(UUID, UUID, TEXT, TEXT);
DROP FUNCTION IF EXISTS delete_service_category(UUID, UUID);
DROP FUNCTION IF EXISTS set_service_category_active(UUID, UUID, BOOLEAN);

-- 4. list_service_categories
CREATE OR REPLACE FUNCTION list_service_categories(caller_id TEXT)
RETURNS TABLE (
  id          UUID,
  name        TEXT,
  slug        TEXT,
  is_active   BOOLEAN,
  sort_order  INT,
  created_at  TIMESTAMPTZ
)
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RETURN QUERY
    SELECT sc.id, sc.name, sc.slug, sc.is_active, sc.sort_order, sc.created_at
    FROM service_categories sc
    ORDER BY sc.sort_order, sc.name;
END;
$$;

-- 5. create_service_category
CREATE OR REPLACE FUNCTION create_service_category(
  caller_id TEXT,
  cat_name  TEXT,
  cat_slug  TEXT DEFAULT NULL
)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  generated_slug TEXT;
BEGIN
  generated_slug := COALESCE(
    NULLIF(TRIM(cat_slug), ''),
    LOWER(REGEXP_REPLACE(TRIM(cat_name), '[^a-zA-Z0-9]+', '_', 'g'))
  );
  INSERT INTO service_categories (name, slug)
  VALUES (TRIM(cat_name), generated_slug);
END;
$$;

-- 6. update_service_category
CREATE OR REPLACE FUNCTION update_service_category(
  caller_id   TEXT,
  category_id UUID,
  cat_name    TEXT,
  cat_slug    TEXT DEFAULT NULL
)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  generated_slug TEXT;
BEGIN
  generated_slug := COALESCE(
    NULLIF(TRIM(cat_slug), ''),
    LOWER(REGEXP_REPLACE(TRIM(cat_name), '[^a-zA-Z0-9]+', '_', 'g'))
  );
  UPDATE service_categories
  SET name = TRIM(cat_name), slug = generated_slug
  WHERE id = category_id;
END;
$$;

-- 7. delete_service_category
CREATE OR REPLACE FUNCTION delete_service_category(
  caller_id   TEXT,
  category_id UUID
)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  DELETE FROM service_categories WHERE id = category_id;
END;
$$;

-- 8. set_service_category_active
CREATE OR REPLACE FUNCTION set_service_category_active(
  caller_id   TEXT,
  category_id UUID,
  active      BOOLEAN
)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE service_categories SET is_active = active WHERE id = category_id;
END;
$$;
