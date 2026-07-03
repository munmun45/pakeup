-- Partner onboarding table + admin CRUD RPCs

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TABLE IF NOT EXISTS partners (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_name TEXT NOT NULL,
  owner_name    TEXT NOT NULL,
  phone         TEXT,
  email         TEXT,
  city          TEXT,
  category      TEXT NOT NULL DEFAULT 'salon',
  address_line  TEXT,
  notes         TEXT,
  is_active     BOOLEAN NOT NULL DEFAULT true,
  kyc_status    TEXT NOT NULL DEFAULT 'pending'
                CHECK (kyc_status IN ('pending', 'approved', 'rejected')),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_partners_active ON partners(is_active);
CREATE INDEX IF NOT EXISTS idx_partners_kyc ON partners(kyc_status);

DROP TRIGGER IF EXISTS partners_updated_at ON partners;
CREATE TRIGGER partners_updated_at
  BEFORE UPDATE ON partners
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

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
            AND apa.page_key IN ('add_partners', 'partner_kyc', 'partner_services')
        )
      )
  ) THEN
    RAISE EXCEPTION 'Access denied';
  END IF;
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
        id,
        business_name,
        owner_name,
        phone,
        email,
        city,
        category,
        address_line,
        notes,
        is_active,
        kyc_status,
        created_at
      FROM partners
    ) t
  );
END;
$$;

CREATE OR REPLACE FUNCTION create_partner(
  caller_id     TEXT,
  business_name TEXT,
  owner_name    TEXT,
  phone         TEXT DEFAULT NULL,
  email         TEXT DEFAULT NULL,
  city          TEXT DEFAULT NULL,
  category      TEXT DEFAULT 'salon',
  address_line  TEXT DEFAULT NULL,
  notes         TEXT DEFAULT NULL
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
    business_name, owner_name, phone, email, city, category, address_line, notes
  ) VALUES (
    trim(business_name),
    trim(owner_name),
    nullif(trim(phone), ''),
    nullif(trim(email), ''),
    nullif(trim(city), ''),
    coalesce(nullif(trim(category), ''), 'salon'),
    nullif(trim(address_line), ''),
    nullif(trim(notes), '')
  )
  RETURNING * INTO new_row;

  RETURN row_to_json(new_row);
END;
$$;

CREATE OR REPLACE FUNCTION update_partner(
  caller_id     TEXT,
  partner_id    UUID,
  business_name TEXT,
  owner_name    TEXT,
  phone         TEXT DEFAULT NULL,
  email         TEXT DEFAULT NULL,
  city          TEXT DEFAULT NULL,
  category      TEXT DEFAULT 'salon',
  address_line  TEXT DEFAULT NULL,
  notes         TEXT DEFAULT NULL
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
    business_name = trim(business_name),
    owner_name = trim(owner_name),
    phone = nullif(trim(phone), ''),
    email = nullif(trim(email), ''),
    city = nullif(trim(city), ''),
    category = coalesce(nullif(trim(category), ''), 'salon'),
    address_line = nullif(trim(address_line), ''),
    notes = nullif(trim(notes), '')
  WHERE id = partner_id
  RETURNING * INTO updated_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Partner not found';
  END IF;

  RETURN row_to_json(updated_row);
END;
$$;

CREATE OR REPLACE FUNCTION delete_partner(
  caller_id  TEXT,
  partner_id UUID
)
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

  UPDATE partners SET is_active = active
  WHERE id = partner_id
  RETURNING * INTO updated_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Partner not found';
  END IF;

  RETURN row_to_json(updated_row);
END;
$$;

GRANT EXECUTE ON FUNCTION list_partners(TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION create_partner(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION update_partner(TEXT, UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION delete_partner(TEXT, UUID) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION set_partner_active(TEXT, UUID, BOOLEAN) TO anon, authenticated, service_role;
