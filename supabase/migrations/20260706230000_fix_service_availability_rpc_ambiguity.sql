-- Fix ambiguous service_id / override_date in availability RPCs (PL/pgSQL param vs column)

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

  INSERT INTO service_availability_overrides AS sao (
    service_id,
    override_date,
    visit_type,
    note
  )
  VALUES (v_service_id, v_override_date, v_visit_type, v_note)
  ON CONFLICT (service_id, override_date) DO UPDATE
    SET visit_type = EXCLUDED.visit_type,
        note       = EXCLUDED.note;

  RETURN json_build_object('success', true);
END;
$$;

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
DECLARE
  v_service_id UUID := update_service_pricing.service_id;
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  UPDATE partner_services ps SET
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
  WHERE ps.id = v_service_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Service not found';
  END IF;

  RETURN json_build_object('success', true);
END;
$$;
