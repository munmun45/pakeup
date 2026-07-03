-- Partner categories (dynamic dropdown for Add Partner form)

CREATE TABLE IF NOT EXISTS partner_categories (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug       TEXT NOT NULL UNIQUE,
  name       TEXT NOT NULL,
  is_active  BOOLEAN NOT NULL DEFAULT true,
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO partner_categories (slug, name, sort_order) VALUES
  ('salon', 'Salon', 1),
  ('spa', 'Spa', 2),
  ('beauty_studio', 'Beauty Studio', 3),
  ('freelance', 'Freelance', 4)
ON CONFLICT (slug) DO NOTHING;

INSERT INTO admin_pages (page_key, label, sort_order) VALUES
  ('partner_categories', 'Partner Categories', 19)
ON CONFLICT (page_key) DO NOTHING;

INSERT INTO admin_page_access (admin_id, page_key)
SELECT 'admin', 'partner_categories'
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
              'add_partners', 'partner_kyc', 'partner_services', 'partner_categories'
            )
        )
      )
  ) THEN
    RAISE EXCEPTION 'Access denied';
  END IF;
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
  new_row partner_categories%ROWTYPE;
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
  old_slug TEXT;
  final_slug TEXT;
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  IF trim(cat_name) = '' THEN
    RAISE EXCEPTION 'Category name is required';
  END IF;

  SELECT slug INTO old_slug FROM partner_categories WHERE id = category_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Category not found';
  END IF;

  final_slug := coalesce(
    nullif(trim(lower(cat_slug)), ''),
    lower(regexp_replace(trim(cat_name), '[^a-zA-Z0-9]+', '_', 'g'))
  );

  UPDATE partner_categories SET
    name = trim(cat_name),
    slug = final_slug
  WHERE id = category_id
  RETURNING * INTO updated_row;

  UPDATE partners SET category = final_slug WHERE category = old_slug;

  RETURN row_to_json(updated_row);
EXCEPTION
  WHEN unique_violation THEN
    RAISE EXCEPTION 'Category slug already exists';
END;
$$;

CREATE OR REPLACE FUNCTION delete_partner_category(
  caller_id   TEXT,
  category_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  cat_slug TEXT;
  usage_count INT;
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  SELECT slug INTO cat_slug FROM partner_categories WHERE id = category_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Category not found';
  END IF;

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

  UPDATE partner_categories SET is_active = active
  WHERE id = category_id
  RETURNING * INTO updated_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Category not found';
  END IF;

  RETURN row_to_json(updated_row);
END;
$$;

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
        p.business_name,
        p.owner_name,
        p.phone,
        p.email,
        p.city,
        p.state,
        p.pincode,
        p.category,
        coalesce(pc.name, p.category) AS category_name,
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

GRANT EXECUTE ON FUNCTION list_partner_categories(TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION create_partner_category(TEXT, TEXT, TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION update_partner_category(TEXT, UUID, TEXT, TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION delete_partner_category(TEXT, UUID) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION set_partner_category_active(TEXT, UUID, BOOLEAN) TO anon, authenticated, service_role;
