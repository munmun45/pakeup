-- Move any remaining bank data from partner_kyc_details → partner_bank_details, then drop bank columns from KYC.

INSERT INTO partner_bank_details (
  account_id,
  bank_account_holder,
  bank_name,
  ifsc_code,
  account_number,
  passbook_doc_url,
  account_status,
  account_type,
  upi_id
)
SELECT DISTINCT ON (src.acc_id)
  src.acc_id,
  src.bank_account_holder,
  src.bank_name,
  src.ifsc_code,
  src.account_number,
  src.passbook_doc_url,
  src.account_status,
  src.account_type,
  src.upi_id
FROM (
  SELECT
    COALESCE(k.account_id, p.account_id) AS acc_id,
    nullif(trim(k.bank_account_holder), '') AS bank_account_holder,
    nullif(trim(k.bank_name), '') AS bank_name,
    nullif(trim(k.ifsc_code), '') AS ifsc_code,
    nullif(trim(k.account_number), '') AS account_number,
    nullif(trim(k.passbook_doc_url), '') AS passbook_doc_url,
    COALESCE(nullif(trim(k.account_status), ''), 'pending') AS account_status,
    COALESCE(nullif(trim(k.account_type), ''), 'savings') AS account_type,
    nullif(trim(k.upi_id), '') AS upi_id,
    k.updated_at
  FROM partner_kyc_details k
  JOIN partners p ON p.id = k.partner_id
  WHERE COALESCE(k.account_id, p.account_id) IS NOT NULL
) src
WHERE src.acc_id IS NOT NULL
  AND (
    src.bank_account_holder IS NOT NULL
    OR src.bank_name IS NOT NULL
    OR src.ifsc_code IS NOT NULL
    OR src.account_number IS NOT NULL
    OR src.passbook_doc_url IS NOT NULL
    OR src.account_type IS NOT NULL
    OR src.upi_id IS NOT NULL
    OR src.account_status <> 'pending'
  )
ORDER BY src.acc_id, src.updated_at DESC NULLS LAST
ON CONFLICT (account_id) DO UPDATE SET
  bank_account_holder = COALESCE(partner_bank_details.bank_account_holder, EXCLUDED.bank_account_holder),
  bank_name           = COALESCE(partner_bank_details.bank_name, EXCLUDED.bank_name),
  ifsc_code           = COALESCE(partner_bank_details.ifsc_code, EXCLUDED.ifsc_code),
  account_number      = COALESCE(partner_bank_details.account_number, EXCLUDED.account_number),
  passbook_doc_url    = COALESCE(partner_bank_details.passbook_doc_url, EXCLUDED.passbook_doc_url),
  account_type        = COALESCE(nullif(trim(partner_bank_details.account_type), ''), EXCLUDED.account_type),
  upi_id              = COALESCE(partner_bank_details.upi_id, EXCLUDED.upi_id),
  account_status      = CASE
    WHEN partner_bank_details.account_status IN ('approved', 'rejected')
      THEN partner_bank_details.account_status
    ELSE EXCLUDED.account_status
  END,
  updated_at          = now();

-- Admin KYC save: identity + documents only (no bank fields).
DROP FUNCTION IF EXISTS upsert_partner_kyc(
  TEXT, UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, BOOLEAN
);

CREATE OR REPLACE FUNCTION upsert_partner_kyc(
  caller_id           TEXT,
  partner_id          UUID,
  property_type       TEXT DEFAULT NULL,
  pan_number          TEXT DEFAULT NULL,
  aadhaar_number      TEXT DEFAULT NULL,
  aadhaar_doc_url     TEXT DEFAULT NULL,
  pan_doc_url         TEXT DEFAULT NULL,
  agreement_doc_url   TEXT DEFAULT NULL,
  gst_doc_url         TEXT DEFAULT NULL,
  other_doc_url       TEXT DEFAULT NULL,
  other_doc_name      TEXT DEFAULT NULL,
  mark_submitted      BOOLEAN DEFAULT true
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_partner_id        UUID := upsert_partner_kyc.partner_id;
  v_property_type     TEXT := upsert_partner_kyc.property_type;
  v_pan_number        TEXT := upsert_partner_kyc.pan_number;
  v_aadhaar_number    TEXT := upsert_partner_kyc.aadhaar_number;
  v_aadhaar_doc_url   TEXT := upsert_partner_kyc.aadhaar_doc_url;
  v_pan_doc_url       TEXT := upsert_partner_kyc.pan_doc_url;
  v_agreement_doc_url TEXT := upsert_partner_kyc.agreement_doc_url;
  v_gst_doc_url       TEXT := upsert_partner_kyc.gst_doc_url;
  v_other_doc_url     TEXT := upsert_partner_kyc.other_doc_url;
  v_other_doc_name    TEXT := upsert_partner_kyc.other_doc_name;
  v_mark_submitted    BOOLEAN := upsert_partner_kyc.mark_submitted;
  result_row          partner_kyc_details%ROWTYPE;
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  IF NOT EXISTS (SELECT 1 FROM partners WHERE id = v_partner_id) THEN
    RAISE EXCEPTION 'Partner not found';
  END IF;

  IF v_property_type IS NOT NULL
     AND v_property_type NOT IN ('own', 'lease', 'rent') THEN
    RAISE EXCEPTION 'Invalid property type';
  END IF;

  INSERT INTO partner_kyc_details (
    partner_id,
    property_type,
    pan_number,
    aadhaar_number,
    aadhaar_doc_url,
    pan_doc_url,
    agreement_doc_url,
    gst_doc_url,
    other_doc_url,
    other_doc_name,
    submitted_at
  ) VALUES (
    v_partner_id,
    nullif(trim(v_property_type), ''),
    nullif(trim(v_pan_number), ''),
    nullif(trim(v_aadhaar_number), ''),
    nullif(trim(v_aadhaar_doc_url), ''),
    nullif(trim(v_pan_doc_url), ''),
    nullif(trim(v_agreement_doc_url), ''),
    nullif(trim(v_gst_doc_url), ''),
    nullif(trim(v_other_doc_url), ''),
    nullif(trim(v_other_doc_name), ''),
    CASE WHEN v_mark_submitted THEN now() ELSE NULL END
  )
  ON CONFLICT ON CONSTRAINT partner_kyc_details_partner_id_key DO UPDATE SET
    property_type = coalesce(
      nullif(trim(excluded.property_type), ''),
      partner_kyc_details.property_type
    ),
    pan_number = coalesce(
      nullif(trim(excluded.pan_number), ''),
      partner_kyc_details.pan_number
    ),
    aadhaar_number = coalesce(
      nullif(trim(excluded.aadhaar_number), ''),
      partner_kyc_details.aadhaar_number
    ),
    aadhaar_doc_url = coalesce(
      nullif(trim(excluded.aadhaar_doc_url), ''),
      partner_kyc_details.aadhaar_doc_url
    ),
    pan_doc_url = coalesce(
      nullif(trim(excluded.pan_doc_url), ''),
      partner_kyc_details.pan_doc_url
    ),
    agreement_doc_url = coalesce(
      nullif(trim(excluded.agreement_doc_url), ''),
      partner_kyc_details.agreement_doc_url
    ),
    gst_doc_url = coalesce(
      nullif(trim(excluded.gst_doc_url), ''),
      partner_kyc_details.gst_doc_url
    ),
    other_doc_url = coalesce(
      nullif(trim(excluded.other_doc_url), ''),
      partner_kyc_details.other_doc_url
    ),
    other_doc_name = coalesce(
      nullif(trim(excluded.other_doc_name), ''),
      partner_kyc_details.other_doc_name
    ),
    submitted_at = CASE
      WHEN v_mark_submitted THEN now()
      ELSE partner_kyc_details.submitted_at
    END
  RETURNING * INTO result_row;

  IF v_mark_submitted THEN
    UPDATE partners SET kyc_status = 'pending'
    WHERE id = v_partner_id AND kyc_status = 'rejected';
  END IF;

  RETURN row_to_json(result_row);
END;
$$;

GRANT EXECUTE ON FUNCTION upsert_partner_kyc(
  TEXT, UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, BOOLEAN
) TO anon, authenticated, service_role;

-- Store app KYC: no account_id on KYC rows.
CREATE OR REPLACE FUNCTION upsert_partner_store_kyc(
  p_account_id        UUID,
  p_login_pass        TEXT,
  p_store_id          UUID,
  p_property_type     TEXT DEFAULT NULL,
  p_pan_number        TEXT DEFAULT NULL,
  p_aadhaar_number    TEXT DEFAULT NULL,
  p_aadhaar_doc_url   TEXT DEFAULT NULL,
  p_pan_doc_url       TEXT DEFAULT NULL,
  p_agreement_doc_url TEXT DEFAULT NULL,
  p_gst_doc_url       TEXT DEFAULT NULL,
  p_other_doc_url     TEXT DEFAULT NULL,
  p_other_doc_name    TEXT DEFAULT NULL,
  p_mark_submitted    BOOLEAN DEFAULT true
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_store_id            UUID := upsert_partner_store_kyc.p_store_id;
  v_property_type       TEXT := upsert_partner_store_kyc.p_property_type;
  v_pan_number          TEXT := upsert_partner_store_kyc.p_pan_number;
  v_aadhaar_number      TEXT := upsert_partner_store_kyc.p_aadhaar_number;
  v_aadhaar_doc_url     TEXT := upsert_partner_store_kyc.p_aadhaar_doc_url;
  v_pan_doc_url         TEXT := upsert_partner_store_kyc.p_pan_doc_url;
  v_agreement_doc_url   TEXT := upsert_partner_store_kyc.p_agreement_doc_url;
  v_gst_doc_url         TEXT := upsert_partner_store_kyc.p_gst_doc_url;
  v_other_doc_url       TEXT := upsert_partner_store_kyc.p_other_doc_url;
  v_other_doc_name      TEXT := upsert_partner_store_kyc.p_other_doc_name;
  v_mark_submitted      BOOLEAN := upsert_partner_store_kyc.p_mark_submitted;
  result_row            partner_kyc_details%ROWTYPE;
BEGIN
  PERFORM assert_partner_store_owned(p_account_id, p_login_pass, v_store_id);

  IF v_property_type IS NOT NULL
     AND v_property_type NOT IN ('own', 'lease', 'rent') THEN
    RAISE EXCEPTION 'Invalid property_type: %', v_property_type;
  END IF;

  INSERT INTO partner_kyc_details (
    partner_id,
    property_type,
    pan_number,
    aadhaar_number,
    aadhaar_doc_url,
    pan_doc_url,
    agreement_doc_url,
    gst_doc_url,
    other_doc_url,
    other_doc_name,
    submitted_at
  ) VALUES (
    v_store_id,
    nullif(trim(v_property_type), ''),
    nullif(trim(v_pan_number), ''),
    nullif(trim(v_aadhaar_number), ''),
    nullif(trim(v_aadhaar_doc_url), ''),
    nullif(trim(v_pan_doc_url), ''),
    nullif(trim(v_agreement_doc_url), ''),
    nullif(trim(v_gst_doc_url), ''),
    nullif(trim(v_other_doc_url), ''),
    nullif(trim(v_other_doc_name), ''),
    CASE WHEN v_mark_submitted THEN now() ELSE NULL END
  )
  ON CONFLICT ON CONSTRAINT partner_kyc_details_partner_id_key DO UPDATE SET
    property_type = coalesce(nullif(trim(excluded.property_type), ''), partner_kyc_details.property_type),
    pan_number = coalesce(nullif(trim(excluded.pan_number), ''), partner_kyc_details.pan_number),
    aadhaar_number = coalesce(nullif(trim(excluded.aadhaar_number), ''), partner_kyc_details.aadhaar_number),
    aadhaar_doc_url = coalesce(nullif(trim(excluded.aadhaar_doc_url), ''), partner_kyc_details.aadhaar_doc_url),
    pan_doc_url = coalesce(nullif(trim(excluded.pan_doc_url), ''), partner_kyc_details.pan_doc_url),
    agreement_doc_url = coalesce(nullif(trim(excluded.agreement_doc_url), ''), partner_kyc_details.agreement_doc_url),
    gst_doc_url = coalesce(nullif(trim(excluded.gst_doc_url), ''), partner_kyc_details.gst_doc_url),
    other_doc_url = coalesce(nullif(trim(excluded.other_doc_url), ''), partner_kyc_details.other_doc_url),
    other_doc_name = coalesce(nullif(trim(excluded.other_doc_name), ''), partner_kyc_details.other_doc_name),
    submitted_at = CASE
      WHEN v_mark_submitted THEN now()
      ELSE partner_kyc_details.submitted_at
    END
  RETURNING * INTO result_row;

  IF v_mark_submitted THEN
    UPDATE partners
    SET kyc_status = 'pending'
    WHERE id = v_store_id
      AND kyc_status IN ('rejected', 'pending');
  END IF;

  RETURN row_to_json(result_row);
END;
$$;

-- KYC overview: passbook flag from partner_bank_details (per login account).
CREATE OR REPLACE FUNCTION list_partner_kyc_overview(caller_id TEXT)
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
        coalesce(a.owner_name, p.owner_name) AS owner_name,
        coalesce(a.phone, p.phone) AS phone,
        p.primary_image,
        p.images,
        p.is_active,
        coalesce(p.kyc_status, 'pending') AS kyc_status,
        k.pan_number,
        k.aadhaar_number,
        coalesce(nullif(trim(k.aadhaar_doc_url), ''), '') <> '' AS has_aadhaar_doc,
        coalesce(nullif(trim(k.pan_doc_url), ''), '') <> '' AS has_pan_doc,
        coalesce(nullif(trim(k.agreement_doc_url), ''), '') <> '' AS has_agreement_doc,
        coalesce(nullif(trim(k.gst_doc_url), ''), '') <> '' AS has_gst_doc,
        coalesce(nullif(trim(k.other_doc_url), ''), '') <> '' AS has_other_doc,
        coalesce(nullif(trim(b.passbook_doc_url), ''), '') <> '' AS has_passbook_doc
      FROM partners p
      LEFT JOIN partner_accounts a ON a.id = p.account_id
      LEFT JOIN partner_kyc_details k ON k.partner_id = p.id
      LEFT JOIN partner_bank_details b ON b.account_id = p.account_id
    ) t
  );
END;
$$;

-- Account delete: bank rows cascade from partner_accounts; KYC cascades from partners.
CREATE OR REPLACE FUNCTION delete_partner_account(caller_id TEXT, account_id UUID)
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
  DELETE FROM partner_bank_details b WHERE b.account_id = v_account_id;
  DELETE FROM partner_accounts a WHERE a.id = v_account_id;

  RETURN json_build_object(
    'deleted', true,
    'stores_deleted', deleted_stores
  );
END;
$$;

-- Drop bank columns from partner_kyc_details.
ALTER TABLE partner_kyc_details DROP CONSTRAINT IF EXISTS partner_kyc_details_account_status_check;
ALTER TABLE partner_kyc_details DROP CONSTRAINT IF EXISTS partner_kyc_details_account_id_fkey;

ALTER TABLE partner_kyc_details
  DROP COLUMN IF EXISTS bank_account_holder,
  DROP COLUMN IF EXISTS bank_name,
  DROP COLUMN IF EXISTS ifsc_code,
  DROP COLUMN IF EXISTS account_number,
  DROP COLUMN IF EXISTS passbook_doc_url,
  DROP COLUMN IF EXISTS account_status,
  DROP COLUMN IF EXISTS account_id,
  DROP COLUMN IF EXISTS account_type,
  DROP COLUMN IF EXISTS upi_id;

NOTIFY pgrst, 'reload schema';
