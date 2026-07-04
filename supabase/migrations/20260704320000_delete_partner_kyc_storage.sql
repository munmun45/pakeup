-- Remove partner KYC files from storage when a store or account is deleted

CREATE OR REPLACE FUNCTION delete_partner_kyc_storage(p_partner_id UUID)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, storage
AS $$
DECLARE
  deleted_count INT;
  v_prefix TEXT := p_partner_id::text;
BEGIN
  DELETE FROM storage.objects o
  WHERE o.bucket_id = 'partner-kyc'
    AND (
      o.name = v_prefix
      OR o.name LIKE v_prefix || '/%'
    );

  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count;
END;
$$;

CREATE OR REPLACE FUNCTION delete_partner(
  caller_id  TEXT,
  partner_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, storage
AS $$
DECLARE
  v_partner_id UUID := delete_partner.partner_id;
  files_deleted  INT;
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  IF NOT EXISTS (SELECT 1 FROM partners p WHERE p.id = v_partner_id) THEN
    RAISE EXCEPTION 'Partner not found';
  END IF;

  files_deleted := delete_partner_kyc_storage(v_partner_id);

  DELETE FROM partners p WHERE p.id = v_partner_id;

  RETURN json_build_object(
    'deleted', true,
    'files_deleted', files_deleted
  );
END;
$$;

CREATE OR REPLACE FUNCTION delete_partner_account(
  caller_id  TEXT,
  account_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, storage
AS $$
DECLARE
  v_account_id   UUID := delete_partner_account.account_id;
  deleted_stores INT;
  files_deleted  INT := 0;
  r              RECORD;
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  IF NOT EXISTS (SELECT 1 FROM partner_accounts a WHERE a.id = v_account_id) THEN
    RAISE EXCEPTION 'Partner account not found';
  END IF;

  SELECT count(*)::int INTO deleted_stores
  FROM partners p
  WHERE p.account_id = v_account_id;

  FOR r IN
    SELECT p.id FROM partners p WHERE p.account_id = v_account_id
  LOOP
    files_deleted := files_deleted + delete_partner_kyc_storage(r.id);
  END LOOP;

  DELETE FROM partners p WHERE p.account_id = v_account_id;

  DELETE FROM partner_kyc_details k WHERE k.account_id = v_account_id;

  DELETE FROM partner_accounts a WHERE a.id = v_account_id;

  RETURN json_build_object(
    'deleted', true,
    'stores_deleted', deleted_stores,
    'files_deleted', files_deleted
  );
END;
$$;

GRANT EXECUTE ON FUNCTION delete_partner(TEXT, UUID)
  TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION delete_partner_account(TEXT, UUID)
  TO anon, authenticated, service_role;
