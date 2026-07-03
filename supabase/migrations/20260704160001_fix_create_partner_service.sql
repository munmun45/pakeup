-- Fix ambiguous column refs in create_partner_service

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
