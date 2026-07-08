-- Return full availability fields expected by admin client (id was missing).

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
          sao.id,
          sao.service_id,
          sao.override_date::TEXT AS override_date,
          sao.visit_type,
          sao.note
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
