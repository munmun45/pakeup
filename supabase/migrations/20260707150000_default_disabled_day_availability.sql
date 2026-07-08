-- Default: no override row = day disabled.
-- Enable  -> visit_type Both
-- Disable -> remove override row

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
    UPDATE service_availability_overrides sao
    SET visit_type = 'Both'
    WHERE sao.service_id = v_service_id
      AND sao.override_date = v_override_date;

    IF NOT FOUND THEN
      INSERT INTO service_availability_overrides (service_id, override_date, visit_type)
      VALUES (v_service_id, v_override_date, 'Both');
    END IF;
  ELSE
    DELETE FROM service_availability_overrides sao
    WHERE sao.service_id = v_service_id
      AND sao.override_date = v_override_date;
  END IF;

  RETURN json_build_object('success', true);
END;
$$;
