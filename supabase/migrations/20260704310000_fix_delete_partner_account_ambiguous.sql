-- Fix ambiguous account_id reference (function param vs column name)

CREATE OR REPLACE FUNCTION delete_partner_account(
  caller_id  TEXT,
  account_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_account_id UUID := delete_partner_account.account_id;
  deleted_stores INT;
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  IF NOT EXISTS (SELECT 1 FROM partner_accounts a WHERE a.id = v_account_id) THEN
    RAISE EXCEPTION 'Partner account not found';
  END IF;

  SELECT count(*)::int INTO deleted_stores
  FROM partners p
  WHERE p.account_id = v_account_id;

  -- partner_services cascade from partners(id); KYC rows may exist at account level too
  DELETE FROM partners p WHERE p.account_id = v_account_id;

  DELETE FROM partner_kyc_details k WHERE k.account_id = v_account_id;

  DELETE FROM partner_accounts a WHERE a.id = v_account_id;

  RETURN json_build_object(
    'deleted', true,
    'stores_deleted', deleted_stores
  );
END;
$$;

GRANT EXECUTE ON FUNCTION delete_partner_account(TEXT, UUID)
  TO anon, authenticated, service_role;
