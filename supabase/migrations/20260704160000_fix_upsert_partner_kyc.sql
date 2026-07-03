-- Fix ambiguous partner_id in upsert_partner_kyc (Save Account Details / Submit KYC)

CREATE OR REPLACE FUNCTION upsert_partner_kyc(
  caller_id           TEXT,
  partner_id          UUID,
  property_type       TEXT DEFAULT NULL,
  pan_number          TEXT DEFAULT NULL,
  aadhaar_number      TEXT DEFAULT NULL,
  bank_account_holder TEXT DEFAULT NULL,
  bank_name           TEXT DEFAULT NULL,
  ifsc_code           TEXT DEFAULT NULL,
  account_number      TEXT DEFAULT NULL,
  aadhaar_doc_url     TEXT DEFAULT NULL,
  pan_doc_url         TEXT DEFAULT NULL,
  agreement_doc_url   TEXT DEFAULT NULL,
  gst_doc_url         TEXT DEFAULT NULL,
  passbook_doc_url    TEXT DEFAULT NULL,
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
  v_partner_id          UUID := upsert_partner_kyc.partner_id;
  v_property_type       TEXT := upsert_partner_kyc.property_type;
  v_pan_number          TEXT := upsert_partner_kyc.pan_number;
  v_aadhaar_number      TEXT := upsert_partner_kyc.aadhaar_number;
  v_bank_account_holder TEXT := upsert_partner_kyc.bank_account_holder;
  v_bank_name           TEXT := upsert_partner_kyc.bank_name;
  v_ifsc_code           TEXT := upsert_partner_kyc.ifsc_code;
  v_account_number      TEXT := upsert_partner_kyc.account_number;
  v_aadhaar_doc_url     TEXT := upsert_partner_kyc.aadhaar_doc_url;
  v_pan_doc_url         TEXT := upsert_partner_kyc.pan_doc_url;
  v_agreement_doc_url   TEXT := upsert_partner_kyc.agreement_doc_url;
  v_gst_doc_url         TEXT := upsert_partner_kyc.gst_doc_url;
  v_passbook_doc_url    TEXT := upsert_partner_kyc.passbook_doc_url;
  v_other_doc_url       TEXT := upsert_partner_kyc.other_doc_url;
  v_other_doc_name      TEXT := upsert_partner_kyc.other_doc_name;
  v_mark_submitted      BOOLEAN := upsert_partner_kyc.mark_submitted;
  result_row partner_kyc_details%ROWTYPE;
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
    bank_account_holder,
    bank_name,
    ifsc_code,
    account_number,
    aadhaar_doc_url,
    pan_doc_url,
    agreement_doc_url,
    gst_doc_url,
    passbook_doc_url,
    other_doc_url,
    other_doc_name,
    submitted_at
  ) VALUES (
    v_partner_id,
    nullif(trim(v_property_type), ''),
    nullif(trim(v_pan_number), ''),
    nullif(trim(v_aadhaar_number), ''),
    nullif(trim(v_bank_account_holder), ''),
    nullif(trim(v_bank_name), ''),
    nullif(trim(v_ifsc_code), ''),
    nullif(trim(v_account_number), ''),
    nullif(trim(v_aadhaar_doc_url), ''),
    nullif(trim(v_pan_doc_url), ''),
    nullif(trim(v_agreement_doc_url), ''),
    nullif(trim(v_gst_doc_url), ''),
    nullif(trim(v_passbook_doc_url), ''),
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
    bank_account_holder = coalesce(
      nullif(trim(excluded.bank_account_holder), ''),
      partner_kyc_details.bank_account_holder
    ),
    bank_name = coalesce(
      nullif(trim(excluded.bank_name), ''),
      partner_kyc_details.bank_name
    ),
    ifsc_code = coalesce(
      nullif(trim(excluded.ifsc_code), ''),
      partner_kyc_details.ifsc_code
    ),
    account_number = coalesce(
      nullif(trim(excluded.account_number), ''),
      partner_kyc_details.account_number
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
    passbook_doc_url = coalesce(
      nullif(trim(excluded.passbook_doc_url), ''),
      partner_kyc_details.passbook_doc_url
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
