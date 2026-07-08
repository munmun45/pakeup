-- ============================================================
-- Partner week inventory — date-wise availability + pricing
-- ============================================================

CREATE TABLE IF NOT EXISTS service_pricing_overrides (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  service_id          UUID NOT NULL REFERENCES partner_services(id) ON DELETE CASCADE,
  override_date       DATE NOT NULL,
  parlour_price_men   NUMERIC(10, 2) DEFAULT NULL,
  parlour_price_women NUMERIC(10, 2) DEFAULT NULL,
  home_price_men      NUMERIC(10, 2) DEFAULT NULL,
  home_price_women    NUMERIC(10, 2) DEFAULT NULL,
  created_at          TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT uq_service_pricing_date UNIQUE (service_id, override_date)
);

CREATE INDEX IF NOT EXISTS idx_spo_service_date
  ON service_pricing_overrides(service_id, override_date);

-- Fetch availability + pricing overrides for all services of a partner in a date range
CREATE OR REPLACE FUNCTION get_partner_week_inventory(
  caller_id   TEXT,
  partner_id  UUID,
  start_date  DATE,
  end_date    DATE
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_partner_id UUID := get_partner_week_inventory.partner_id;
  v_start      DATE := get_partner_week_inventory.start_date;
  v_end        DATE := get_partner_week_inventory.end_date;
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  RETURN json_build_object(
    'availability', COALESCE((
      SELECT json_agg(row_to_json(t) ORDER BY t.service_id, t.override_date)
      FROM (
        SELECT
          sao.service_id,
          sao.override_date::TEXT AS override_date,
          sao.visit_type
        FROM service_availability_overrides sao
        JOIN partner_services ps ON ps.id = sao.service_id
        WHERE ps.partner_id = v_partner_id
          AND sao.override_date BETWEEN v_start AND v_end
      ) t
    ), '[]'::json),
    'pricing', COALESCE((
      SELECT json_agg(row_to_json(t) ORDER BY t.service_id, t.override_date)
      FROM (
        SELECT
          spo.service_id,
          spo.override_date::TEXT AS override_date,
          spo.parlour_price_men,
          spo.parlour_price_women,
          spo.home_price_men,
          spo.home_price_women
        FROM service_pricing_overrides spo
        JOIN partner_services ps ON ps.id = spo.service_id
        WHERE ps.partner_id = v_partner_id
          AND spo.override_date BETWEEN v_start AND v_end
      ) t
    ), '[]'::json)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION get_partner_week_inventory(TEXT, UUID, DATE, DATE)
  TO anon, authenticated, service_role;

-- Simple available / unavailable toggle for a service on a date
CREATE OR REPLACE FUNCTION set_service_day_available(
  caller_id     TEXT,
  service_id    UUID,
  override_date DATE,
  is_available  BOOLEAN
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_service_id    UUID := set_service_day_available.service_id;
  v_override_date DATE := set_service_day_available.override_date;
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  IF is_available THEN
    DELETE FROM service_availability_overrides sao
    WHERE sao.service_id = v_service_id
      AND sao.override_date = v_override_date;
    RETURN json_build_object('success', true);
  ELSE
    INSERT INTO service_availability_overrides AS sao (
      service_id, override_date, visit_type
    )
    VALUES (v_service_id, v_override_date, 'None')
    ON CONFLICT (service_id, override_date) DO UPDATE
      SET visit_type = 'None';
    RETURN json_build_object('success', true);
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION set_service_day_available(TEXT, UUID, DATE, BOOLEAN)
  TO anon, authenticated, service_role;

-- Upsert date-specific pricing for a service
CREATE OR REPLACE FUNCTION upsert_service_day_pricing(
  caller_id           TEXT,
  service_id          UUID,
  override_date       DATE,
  parlour_price_men   NUMERIC DEFAULT NULL,
  parlour_price_women NUMERIC DEFAULT NULL,
  home_price_men      NUMERIC DEFAULT NULL,
  home_price_women    NUMERIC DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_service_id    UUID := upsert_service_day_pricing.service_id;
  v_override_date DATE := upsert_service_day_pricing.override_date;
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  INSERT INTO service_pricing_overrides AS spo (
    service_id,
    override_date,
    parlour_price_men,
    parlour_price_women,
    home_price_men,
    home_price_women
  )
  VALUES (
    v_service_id,
    v_override_date,
    upsert_service_day_pricing.parlour_price_men,
    upsert_service_day_pricing.parlour_price_women,
    upsert_service_day_pricing.home_price_men,
    upsert_service_day_pricing.home_price_women
  )
  ON CONFLICT (service_id, override_date) DO UPDATE
    SET parlour_price_men   = EXCLUDED.parlour_price_men,
        parlour_price_women = EXCLUDED.parlour_price_women,
        home_price_men      = EXCLUDED.home_price_men,
        home_price_women    = EXCLUDED.home_price_women;

  RETURN json_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION upsert_service_day_pricing(TEXT, UUID, DATE, NUMERIC, NUMERIC, NUMERIC, NUMERIC)
  TO anon, authenticated, service_role;
