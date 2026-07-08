-- Fix ambiguous service_id / override_date in inventory RPCs.
-- Avoid ON CONFLICT (service_id, ...) — param names clash with column names in PL/pgSQL.

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
  ELSE
    UPDATE service_availability_overrides sao
    SET visit_type = 'None'
    WHERE sao.service_id = v_service_id
      AND sao.override_date = v_override_date;

    IF NOT FOUND THEN
      INSERT INTO service_availability_overrides (service_id, override_date, visit_type)
      VALUES (v_service_id, v_override_date, 'None');
    END IF;
  END IF;

  RETURN json_build_object('success', true);
END;
$$;

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
DECLARE
  v_service_id    UUID := set_service_availability_override.service_id;
  v_override_date DATE := set_service_availability_override.override_date;
  v_visit_type    TEXT := set_service_availability_override.visit_type;
  v_note          TEXT := set_service_availability_override.note;
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  UPDATE service_availability_overrides sao
  SET visit_type = v_visit_type,
      note       = v_note
  WHERE sao.service_id = v_service_id
    AND sao.override_date = v_override_date;

  IF NOT FOUND THEN
    INSERT INTO service_availability_overrides (service_id, override_date, visit_type, note)
    VALUES (v_service_id, v_override_date, v_visit_type, v_note);
  END IF;

  RETURN json_build_object('success', true);
END;
$$;

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
  SET parlour_price_men      = upsert_service_day_pricing.parlour_price_men,
      parlour_price_women    = upsert_service_day_pricing.parlour_price_women,
      home_price_men         = upsert_service_day_pricing.home_price_men,
      home_price_women       = upsert_service_day_pricing.home_price_women,
      parlour_duration_men   = upsert_service_day_pricing.parlour_duration_men,
      parlour_duration_women = upsert_service_day_pricing.parlour_duration_women,
      home_duration_men      = upsert_service_day_pricing.home_duration_men,
      home_duration_women    = upsert_service_day_pricing.home_duration_women
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
