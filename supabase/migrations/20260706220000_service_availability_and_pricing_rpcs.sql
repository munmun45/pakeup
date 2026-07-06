-- ============================================================
-- Service Availability Overrides
-- Manages date-wise availability per service (Parlour/Home/Both/None)
-- ============================================================

-- 1. Create the overrides table
CREATE TABLE IF NOT EXISTS service_availability_overrides (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  service_id    UUID NOT NULL REFERENCES partner_services(id) ON DELETE CASCADE,
  override_date DATE NOT NULL,
  visit_type    TEXT NOT NULL DEFAULT 'Both',
  note          TEXT DEFAULT NULL,
  created_at    TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT uq_service_date UNIQUE (service_id, override_date),
  CONSTRAINT chk_visit_type CHECK (visit_type IN ('Parlour', 'Home', 'Both', 'None'))
);

-- Index for fast date-range lookups
CREATE INDEX IF NOT EXISTS idx_sao_service_date ON service_availability_overrides(service_id, override_date);

-- 2. get_service_availability_overrides — fetch overrides for a service in a given month
CREATE OR REPLACE FUNCTION get_service_availability_overrides(
  caller_id   TEXT,
  service_id  UUID,
  year_month  TEXT -- format: 'YYYY-MM'
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  RETURN (
    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.override_date), '[]'::json)
    FROM (
      SELECT
        sao.id,
        sao.service_id,
        sao.override_date::TEXT AS override_date,
        sao.visit_type,
        sao.note
      FROM service_availability_overrides sao
      WHERE sao.service_id = get_service_availability_overrides.service_id
        AND to_char(sao.override_date, 'YYYY-MM') = get_service_availability_overrides.year_month
    ) t
  );
END;
$$;

GRANT EXECUTE ON FUNCTION get_service_availability_overrides(TEXT, UUID, TEXT) TO anon, authenticated, service_role;

-- 3. set_service_availability_override — upsert a date override
CREATE OR REPLACE FUNCTION set_service_availability_override(
  caller_id     TEXT,
  service_id    UUID,
  override_date DATE,
  visit_type    TEXT,
  note          TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  INSERT INTO service_availability_overrides (service_id, override_date, visit_type, note)
  VALUES (service_id, override_date, visit_type, note)
  ON CONFLICT (service_id, override_date) DO UPDATE
    SET visit_type = EXCLUDED.visit_type,
        note       = EXCLUDED.note;

  RETURN json_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION set_service_availability_override(TEXT, UUID, DATE, TEXT, TEXT) TO anon, authenticated, service_role;

-- 4. clear_service_availability_override — remove a date override
CREATE OR REPLACE FUNCTION clear_service_availability_override(
  caller_id     TEXT,
  service_id    UUID,
  override_date DATE
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  DELETE FROM service_availability_overrides sao
  WHERE sao.service_id = clear_service_availability_override.service_id
    AND sao.override_date = clear_service_availability_override.override_date;

  RETURN json_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION clear_service_availability_override(TEXT, UUID, DATE) TO anon, authenticated, service_role;

-- 5. update_service_pricing — lightweight RPC to update only pricing/availability fields
CREATE OR REPLACE FUNCTION update_service_pricing(
  caller_id              TEXT,
  service_id             UUID,
  is_parlour_available   BOOLEAN,
  parlour_price_men      NUMERIC DEFAULT NULL,
  parlour_duration_men   INT     DEFAULT NULL,
  parlour_price_women    NUMERIC DEFAULT NULL,
  parlour_duration_women INT     DEFAULT NULL,
  is_home_available      BOOLEAN DEFAULT false,
  home_price_men         NUMERIC DEFAULT NULL,
  home_duration_men      INT     DEFAULT NULL,
  home_price_women       NUMERIC DEFAULT NULL,
  home_duration_women    INT     DEFAULT NULL,
  free_radius_km         INT     DEFAULT 0,
  per_km_charge          NUMERIC DEFAULT 0,
  discount_price         NUMERIC DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  UPDATE partner_services SET
    is_parlour_available   = update_service_pricing.is_parlour_available,
    parlour_price_men      = update_service_pricing.parlour_price_men,
    parlour_duration_men   = update_service_pricing.parlour_duration_men,
    parlour_price_women    = update_service_pricing.parlour_price_women,
    parlour_duration_women = update_service_pricing.parlour_duration_women,
    is_home_available      = update_service_pricing.is_home_available,
    home_price_men         = update_service_pricing.home_price_men,
    home_duration_men      = update_service_pricing.home_duration_men,
    home_price_women       = update_service_pricing.home_price_women,
    home_duration_women    = update_service_pricing.home_duration_women,
    free_radius_km         = update_service_pricing.free_radius_km,
    per_km_charge          = update_service_pricing.per_km_charge,
    discount_price         = update_service_pricing.discount_price
  WHERE id = service_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Service not found';
  END IF;

  RETURN json_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION update_service_pricing(TEXT, UUID, BOOLEAN, NUMERIC, INT, NUMERIC, INT, BOOLEAN, NUMERIC, INT, NUMERIC, INT, INT, NUMERIC, NUMERIC) TO anon, authenticated, service_role;
