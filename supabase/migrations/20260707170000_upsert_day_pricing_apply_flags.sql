-- Allow clearing day prices: apply_* flags mean "set these columns (NULL allowed)".

CREATE OR REPLACE FUNCTION upsert_service_day_pricing(
  caller_id              TEXT,
  service_id             UUID,
  override_date          DATE,
  parlour_price_men      NUMERIC DEFAULT NULL,
  parlour_price_women    NUMERIC DEFAULT NULL,
  home_price_men         NUMERIC DEFAULT NULL,
  home_price_women       NUMERIC DEFAULT NULL,
  parlour_duration_men   INT     DEFAULT NULL,
  parlour_duration_women INT     DEFAULT NULL,
  home_duration_men      INT     DEFAULT NULL,
  home_duration_women    INT     DEFAULT NULL,
  apply_parlour_prices   BOOLEAN DEFAULT FALSE,
  apply_home_prices      BOOLEAN DEFAULT FALSE
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

  UPDATE service_pricing_overrides spo
  SET parlour_price_men = CASE
        WHEN upsert_service_day_pricing.apply_parlour_prices
          THEN upsert_service_day_pricing.parlour_price_men
        ELSE spo.parlour_price_men END,
      parlour_price_women = CASE
        WHEN upsert_service_day_pricing.apply_parlour_prices
          THEN upsert_service_day_pricing.parlour_price_women
        ELSE spo.parlour_price_women END,
      parlour_duration_men = CASE
        WHEN upsert_service_day_pricing.apply_parlour_prices
          THEN upsert_service_day_pricing.parlour_duration_men
        ELSE spo.parlour_duration_men END,
      parlour_duration_women = CASE
        WHEN upsert_service_day_pricing.apply_parlour_prices
          THEN upsert_service_day_pricing.parlour_duration_women
        ELSE spo.parlour_duration_women END,
      home_price_men = CASE
        WHEN upsert_service_day_pricing.apply_home_prices
          THEN upsert_service_day_pricing.home_price_men
        ELSE spo.home_price_men END,
      home_price_women = CASE
        WHEN upsert_service_day_pricing.apply_home_prices
          THEN upsert_service_day_pricing.home_price_women
        ELSE spo.home_price_women END,
      home_duration_men = CASE
        WHEN upsert_service_day_pricing.apply_home_prices
          THEN upsert_service_day_pricing.home_duration_men
        ELSE spo.home_duration_men END,
      home_duration_women = CASE
        WHEN upsert_service_day_pricing.apply_home_prices
          THEN upsert_service_day_pricing.home_duration_women
        ELSE spo.home_duration_women END
  WHERE spo.service_id = v_service_id
    AND spo.override_date = v_override_date;

  IF NOT FOUND THEN
    INSERT INTO service_pricing_overrides (
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
      CASE WHEN upsert_service_day_pricing.apply_parlour_prices
        THEN upsert_service_day_pricing.parlour_price_men END,
      CASE WHEN upsert_service_day_pricing.apply_parlour_prices
        THEN upsert_service_day_pricing.parlour_price_women END,
      CASE WHEN upsert_service_day_pricing.apply_home_prices
        THEN upsert_service_day_pricing.home_price_men END,
      CASE WHEN upsert_service_day_pricing.apply_home_prices
        THEN upsert_service_day_pricing.home_price_women END,
      CASE WHEN upsert_service_day_pricing.apply_parlour_prices
        THEN upsert_service_day_pricing.parlour_duration_men END,
      CASE WHEN upsert_service_day_pricing.apply_parlour_prices
        THEN upsert_service_day_pricing.parlour_duration_women END,
      CASE WHEN upsert_service_day_pricing.apply_home_prices
        THEN upsert_service_day_pricing.home_duration_men END,
      CASE WHEN upsert_service_day_pricing.apply_home_prices
        THEN upsert_service_day_pricing.home_duration_women END
    );
  END IF;

  RETURN json_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION upsert_service_day_pricing(
  TEXT, UUID, DATE, NUMERIC, NUMERIC, NUMERIC, NUMERIC, INT, INT, INT, INT, BOOLEAN, BOOLEAN
) TO anon, authenticated, service_role;
