-- Supabase blocks direct DELETE on storage.objects; cleanup is done via Storage API.
-- Revert DB functions and allow admin app to delete KYC files.

DROP FUNCTION IF EXISTS delete_partner_kyc_storage(UUID);

CREATE OR REPLACE FUNCTION delete_partner(
  caller_id  TEXT,
  partner_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_partner_id UUID := delete_partner.partner_id;
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  DELETE FROM partners p WHERE p.id = v_partner_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Partner not found';
  END IF;

  RETURN json_build_object('deleted', true);
END;
$$;

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
  v_account_id   UUID := delete_partner_account.account_id;
  deleted_stores INT;
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  IF NOT EXISTS (SELECT 1 FROM partner_accounts a WHERE a.id = v_account_id) THEN
    RAISE EXCEPTION 'Partner account not found';
  END IF;

  SELECT count(*)::int INTO deleted_stores
  FROM partners p
  WHERE p.account_id = v_account_id;

  DELETE FROM partners p WHERE p.account_id = v_account_id;

  DELETE FROM partner_kyc_details k WHERE k.account_id = v_account_id;

  DELETE FROM partner_accounts a WHERE a.id = v_account_id;

  RETURN json_build_object(
    'deleted', true,
    'stores_deleted', deleted_stores
  );
END;
$$;

GRANT EXECUTE ON FUNCTION delete_partner(TEXT, UUID)
  TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION delete_partner_account(TEXT, UUID)
  TO anon, authenticated, service_role;

DROP POLICY IF EXISTS "partner_kyc_anon_delete" ON storage.objects;
CREATE POLICY "partner_kyc_anon_delete"
ON storage.objects FOR DELETE
USING (bucket_id = 'partner-kyc');
