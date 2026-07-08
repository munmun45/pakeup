-- Add per-date duration overrides alongside price overrides

ALTER TABLE service_pricing_overrides
  ADD COLUMN IF NOT EXISTS parlour_duration_men   INT DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS parlour_duration_women INT DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS home_duration_men      INT DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS home_duration_women    INT DEFAULT NULL;

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
          spo.home_price_women,
          spo.parlour_duration_men,
          spo.parlour_duration_women,
          spo.home_duration_men,
          spo.home_duration_women
        FROM service_pricing_overrides spo
        JOIN partner_services ps ON ps.id = spo.service_id
        WHERE ps.partner_id = v_partner_id
          AND spo.override_date BETWEEN v_start AND v_end
      ) t
    ), '[]'::json)
  );
END;
$$;

CREATE OR REPLACE FUNCTION upsert_service_day_pricing(
  caller_id             TEXT,
  service_id            UUID,
  override_date         DATE,
  parlour_price_men     NUMERIC DEFAULT NULL,
  parlour_price_women   NUMERIC DEFAULT NULL,
  home_price_men        NUMERIC DEFAULT NULL,
  home_price_women      NUMERIC DEFAULT NULL,
  parlour_duration_men  INT     DEFAULT NULL,
  parlour_duration_women INT    DEFAULT NULL,
  home_duration_men     INT     DEFAULT NULL,
  home_duration_women   INT     DEFAULT NULL
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
    home_price_women,
    parlour_duration_men,
    parlour_duration_women,
    home_duration_men,
    home_duration_women
  )
  VALUES (
    v_service_id,
    v_override_date,
    upsert_service_day_pricing.parlour_price_men,
    upsert_service_day_pricing.parlour_price_women,
    upsert_service_day_pricing.home_price_men,
    upsert_service_day_pricing.home_price_women,
    upsert_service_day_pricing.parlour_duration_men,
    upsert_service_day_pricing.parlour_duration_women,
    upsert_service_day_pricing.home_duration_men,
    upsert_service_day_pricing.home_duration_women
  )
  ON CONFLICT (service_id, override_date) DO UPDATE
    SET parlour_price_men      = EXCLUDED.parlour_price_men,
        parlour_price_women    = EXCLUDED.parlour_price_women,
        home_price_men         = EXCLUDED.home_price_men,
        home_price_women       = EXCLUDED.home_price_women,
        parlour_duration_men   = EXCLUDED.parlour_duration_men,
        parlour_duration_women = EXCLUDED.parlour_duration_women,
        home_duration_men      = EXCLUDED.home_duration_men,
        home_duration_women    = EXCLUDED.home_duration_women;

  RETURN json_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION upsert_service_day_pricing(TEXT, UUID, DATE, NUMERIC, NUMERIC, NUMERIC, NUMERIC, INT, INT, INT, INT)
  TO anon, authenticated, service_role;
