-- Partner store app dashboard: bookings + revenue summary.
-- Returns zeros until bookings are linked to partner stores.

CREATE OR REPLACE FUNCTION get_partner_dashboard_stats(
  p_account_id TEXT,
  p_login_pass TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_account_id UUID;
  v_today DATE := (now() AT TIME ZONE 'Asia/Kolkata')::date;
  v_tomorrow DATE := v_today + 1;
  v_month_start DATE := date_trunc('month', v_today)::date;
  v_prev_month_start DATE := (date_trunc('month', v_today) - interval '1 month')::date;
  v_prev_month_end DATE := v_month_start - 1;
BEGIN
  SELECT pa.id INTO v_account_id
  FROM partner_accounts pa
  WHERE pa.id::text = p_account_id
    AND pa.login_pass = crypt(p_login_pass, pa.login_pass);

  IF v_account_id IS NULL THEN
    RAISE EXCEPTION 'Invalid partner credentials';
  END IF;

  RETURN (
    SELECT json_build_object(
      'total_bookings', COALESCE(COUNT(b.id), 0),
      'today_bookings', COALESCE(COUNT(b.id) FILTER (
        WHERE (b.scheduled_at AT TIME ZONE 'Asia/Kolkata')::date = v_today
      ), 0),
      'tomorrow_bookings', COALESCE(COUNT(b.id) FILTER (
        WHERE (b.scheduled_at AT TIME ZONE 'Asia/Kolkata')::date = v_tomorrow
      ), 0),
      'lifetime_revenue', COALESCE(SUM(b.total_amount) FILTER (
        WHERE b.payment_status = 'paid'
      ), 0),
      'past_month_revenue', COALESCE(SUM(b.total_amount) FILTER (
        WHERE b.payment_status = 'paid'
          AND (b.scheduled_at AT TIME ZONE 'Asia/Kolkata')::date
              BETWEEN v_prev_month_start AND v_prev_month_end
      ), 0),
      'this_month_revenue', COALESCE(SUM(b.total_amount) FILTER (
        WHERE b.payment_status = 'paid'
          AND (b.scheduled_at AT TIME ZONE 'Asia/Kolkata')::date >= v_month_start
      ), 0)
    )
    FROM partners p
    LEFT JOIN bookings b ON b.salon_id = p.id
    WHERE p.account_id = v_account_id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION get_partner_dashboard_stats(TEXT, TEXT)
  TO anon, authenticated, service_role;

NOTIFY pgrst, 'reload schema';
