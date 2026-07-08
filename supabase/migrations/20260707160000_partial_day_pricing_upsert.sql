-- Partial day pricing upsert: NULL param = keep existing value on UPDATE.

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
  home_duration_women    INT     DEFAULT NULL
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
  SET parlour_price_men      = COALESCE(
        upsert_service_day_pricing.parlour_price_men, spo.parlour_price_men),
      parlour_price_women    = COALESCE(
        upsert_service_day_pricing.parlour_price_women, spo.parlour_price_women),
      home_price_men         = COALESCE(
        upsert_service_day_pricing.home_price_men, spo.home_price_men),
      home_price_women       = COALESCE(
        upsert_service_day_pricing.home_price_women, spo.home_price_women),
      parlour_duration_men   = COALESCE(
        upsert_service_day_pricing.parlour_duration_men, spo.parlour_duration_men),
      parlour_duration_women = COALESCE(
        upsert_service_day_pricing.parlour_duration_women, spo.parlour_duration_women),
      home_duration_men      = COALESCE(
        upsert_service_day_pricing.home_duration_men, spo.home_duration_men),
      home_duration_women    = COALESCE(
        upsert_service_day_pricing.home_duration_women, spo.home_duration_women)
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
      upsert_service_day_pricing.parlour_price_men,
      upsert_service_day_pricing.parlour_price_women,
      upsert_service_day_pricing.home_price_men,
      upsert_service_day_pricing.home_price_women,
      upsert_service_day_pricing.parlour_duration_men,
      upsert_service_day_pricing.parlour_duration_women,
      upsert_service_day_pricing.home_duration_men,
      upsert_service_day_pricing.home_duration_women
    );
  END IF;

  RETURN json_build_object('success', true);
END;
$$;
