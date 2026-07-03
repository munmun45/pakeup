-- Account approval status for partner bank details

ALTER TABLE partner_kyc_details
  ADD COLUMN IF NOT EXISTS account_status TEXT NOT NULL DEFAULT 'pending'
  CHECK (account_status IN ('pending', 'approved', 'rejected'));

CREATE OR REPLACE FUNCTION list_partner_accounts(caller_id TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  RETURN (
    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.business_name), '[]'::json)
    FROM (
      SELECT
        p.id AS partner_id,
        p.business_name,
        p.owner_name,
        coalesce(k.account_status, 'pending') AS account_status,
        k.bank_account_holder,
        k.bank_name,
        k.ifsc_code,
        k.account_number,
        k.passbook_doc_url,
        k.submitted_at AS kyc_submitted_at,
        k.updated_at AS account_updated_at
      FROM partners p
      LEFT JOIN partner_kyc_details k ON k.partner_id = p.id
    ) t
  );
END;
$$;

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

GRANT EXECUTE ON FUNCTION set_partner_account_status(TEXT, UUID, TEXT) TO anon, authenticated, service_role;
