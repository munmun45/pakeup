-- Fix ambiguous column refs in update_partner_service (Save service)

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
