-- Fix get_partner_bank_account: SELECT account_id was ambiguous with function parameter.

CREATE OR REPLACE FUNCTION get_partner_bank_account(caller_id TEXT, account_id UUID)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  PERFORM assert_admin_partner_access(caller_id);
  RETURN (
    SELECT row_to_json(t)
    FROM (
      SELECT
        b.account_id,
        b.bank_account_holder,
        b.bank_name,
        b.ifsc_code,
        b.account_number,
        b.account_type,
        b.upi_id,
        b.passbook_doc_url,
        b.account_status,
        b.updated_at
      FROM partner_bank_details b
      WHERE b.account_id = get_partner_bank_account.account_id
    ) t
  );
END;
$$;

CREATE OR REPLACE FUNCTION get_partner_bank_details(p_account_id UUID, p_login_pass TEXT)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  PERFORM assert_partner_account_access(p_account_id, p_login_pass);
  RETURN (
    SELECT row_to_json(t)
    FROM (
      SELECT
        b.bank_account_holder AS account_name,
        b.bank_name,
        b.ifsc_code AS ifsc,
        b.account_number,
        b.account_type,
        b.upi_id,
        b.passbook_doc_url,
        b.account_status,
        b.updated_at
      FROM partner_bank_details b
      WHERE b.account_id = p_account_id
    ) t
  );
END;
$$;

NOTIFY pgrst, 'reload schema';
