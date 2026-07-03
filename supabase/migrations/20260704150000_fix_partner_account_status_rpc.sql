-- Fix ambiguous partner_id reference in set_partner_account_status

CREATE OR REPLACE FUNCTION set_partner_account_status(
  caller_id  TEXT,
  partner_id UUID,
  new_status TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_partner_id UUID := set_partner_account_status.partner_id;
  v_new_status TEXT := set_partner_account_status.new_status;
  result_row partner_kyc_details%ROWTYPE;
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  IF v_new_status NOT IN ('pending', 'approved', 'rejected') THEN
    RAISE EXCEPTION 'Invalid account status';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM partners WHERE id = v_partner_id) THEN
    RAISE EXCEPTION 'Partner not found';
  END IF;

  INSERT INTO partner_kyc_details (partner_id, account_status)
  VALUES (v_partner_id, v_new_status)
  ON CONFLICT ON CONSTRAINT partner_kyc_details_partner_id_key DO UPDATE SET
    account_status = EXCLUDED.account_status
  RETURNING * INTO result_row;

  RETURN row_to_json(result_row);
END;
$$;
