CREATE OR REPLACE FUNCTION set_partner_kyc(
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
  updated_row partners%ROWTYPE;
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  IF new_status NOT IN ('pending', 'approved', 'rejected') THEN
    RAISE EXCEPTION 'Invalid KYC status';
  END IF;

  UPDATE partners SET kyc_status = new_status
  WHERE id = partner_id
  RETURNING * INTO updated_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Partner not found';
  END IF;

  RETURN row_to_json(updated_row);
END;
$$;

GRANT EXECUTE ON FUNCTION set_partner_kyc(TEXT, UUID, TEXT) TO anon, authenticated, service_role;
