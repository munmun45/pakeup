-- Partner services catalog (per partner)

CREATE TABLE IF NOT EXISTS partner_services (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  partner_id       UUID NOT NULL REFERENCES partners(id) ON DELETE CASCADE,
  name             TEXT NOT NULL,
  description      TEXT,
  price            DECIMAL(10, 2) NOT NULL DEFAULT 0,
  duration_minutes INT NOT NULL DEFAULT 30,
  is_active        BOOLEAN NOT NULL DEFAULT true,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_partner_services_partner
  ON partner_services(partner_id);

DROP TRIGGER IF EXISTS partner_services_updated_at ON partner_services;
CREATE TRIGGER partner_services_updated_at
  BEFORE UPDATE ON partner_services
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE OR REPLACE FUNCTION list_partner_services(caller_id TEXT)
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
        ps.id,
        ps.partner_id,
        p.business_name AS partner_name,
        ps.name,
        ps.description,
        ps.price,
        ps.duration_minutes,
        ps.is_active,
        ps.created_at
      FROM partner_services ps
      JOIN partners p ON p.id = ps.partner_id
    ) t
  );
END;
$$;

CREATE OR REPLACE FUNCTION create_partner_service(
  caller_id         TEXT,
  partner_id        UUID,
  service_name      TEXT,
  description       TEXT DEFAULT NULL,
  price             DECIMAL DEFAULT 0,
  duration_minutes  INT DEFAULT 30
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_partner_id       UUID := create_partner_service.partner_id;
  v_service_name     TEXT := create_partner_service.service_name;
  v_description      TEXT := create_partner_service.description;
  v_price            DECIMAL := create_partner_service.price;
  v_duration_minutes INT := create_partner_service.duration_minutes;
  new_row partner_services%ROWTYPE;
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  IF trim(v_service_name) = '' THEN
    RAISE EXCEPTION 'Service name is required';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM partners WHERE id = v_partner_id) THEN
    RAISE EXCEPTION 'Partner not found';
  END IF;

  INSERT INTO partner_services (
    partner_id, name, description, price, duration_minutes
  ) VALUES (
    v_partner_id,
    trim(v_service_name),
    nullif(trim(v_description), ''),
    coalesce(v_price, 0),
    coalesce(v_duration_minutes, 30)
  )
  RETURNING * INTO new_row;

  RETURN row_to_json(new_row);
END;
$$;

CREATE OR REPLACE FUNCTION update_partner_service(
  caller_id         TEXT,
  service_id        UUID,
  partner_id        UUID,
  service_name      TEXT,
  description       TEXT DEFAULT NULL,
  price             DECIMAL DEFAULT 0,
  duration_minutes  INT DEFAULT 30,
  active            BOOLEAN DEFAULT true
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_service_id       UUID := update_partner_service.service_id;
  v_partner_id       UUID := update_partner_service.partner_id;
  v_service_name     TEXT := update_partner_service.service_name;
  v_description      TEXT := update_partner_service.description;
  v_price            DECIMAL := update_partner_service.price;
  v_duration_minutes INT := update_partner_service.duration_minutes;
  v_active           BOOLEAN := update_partner_service.active;
  updated_row partner_services%ROWTYPE;
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  IF trim(v_service_name) = '' THEN
    RAISE EXCEPTION 'Service name is required';
  END IF;

  UPDATE partner_services SET
    partner_id = v_partner_id,
    name = trim(v_service_name),
    description = nullif(trim(v_description), ''),
    price = coalesce(v_price, 0),
    duration_minutes = coalesce(v_duration_minutes, 30),
    is_active = v_active
  WHERE id = v_service_id
  RETURNING * INTO updated_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Service not found';
  END IF;

  RETURN row_to_json(updated_row);
END;
$$;

CREATE OR REPLACE FUNCTION delete_partner_service(
  caller_id  TEXT,
  service_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  DELETE FROM partner_services WHERE id = service_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Service not found';
  END IF;

  RETURN json_build_object('deleted', true);
END;
$$;

GRANT EXECUTE ON FUNCTION list_partner_services(TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION create_partner_service(TEXT, UUID, TEXT, TEXT, DECIMAL, INT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION update_partner_service(TEXT, UUID, UUID, TEXT, TEXT, DECIMAL, INT, BOOLEAN) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION delete_partner_service(TEXT, UUID) TO anon, authenticated, service_role;
