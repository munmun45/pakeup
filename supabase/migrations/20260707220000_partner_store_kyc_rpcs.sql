-- Partner store app: per-store KYC get / upsert

CREATE OR REPLACE FUNCTION get_partner_store_kyc(
  p_account_id UUID,
  p_login_pass TEXT,
  p_store_id   UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM assert_partner_store_owned(p_account_id, p_login_pass, p_store_id);

  RETURN (
    SELECT row_to_json(k)
    FROM partner_kyc_details k
    WHERE k.partner_id = get_partner_store_kyc.p_store_id
  );
END;
$$;

CREATE OR REPLACE FUNCTION upsert_partner_store_kyc(
  p_account_id        UUID,
  p_login_pass        TEXT,
  p_store_id          UUID,
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
  v_aadhaar_doc_url     TEXT := upsert_partner_store_kyc.p_aadhaar_doc_url;
  v_pan_doc_url         TEXT := upsert_partner_store_kyc.p_pan_doc_url;
  v_agreement_doc_url   TEXT := upsert_partner_store_kyc.p_agreement_doc_url;
  v_gst_doc_url         TEXT := upsert_partner_store_kyc.p_gst_doc_url;
  v_other_doc_url       TEXT := upsert_partner_store_kyc.p_other_doc_url;
  v_other_doc_name      TEXT := upsert_partner_store_kyc.p_other_doc_name;
  v_mark_submitted      BOOLEAN := upsert_partner_store_kyc.p_mark_submitted;
  v_account_id          UUID;
  result_row            partner_kyc_details%ROWTYPE;
BEGIN
  PERFORM assert_partner_store_owned(p_account_id, p_login_pass, v_store_id);

  SELECT account_id INTO v_account_id
  FROM partners
  WHERE id = v_store_id;

  INSERT INTO partner_kyc_details (
    partner_id,
    account_id,
    aadhaar_doc_url,
    pan_doc_url,
    agreement_doc_url,
    gst_doc_url,
    other_doc_url,
    other_doc_name,
    submitted_at
  ) VALUES (
    v_store_id,
    v_account_id,
    nullif(trim(v_aadhaar_doc_url), ''),
    nullif(trim(v_pan_doc_url), ''),
    nullif(trim(v_agreement_doc_url), ''),
    nullif(trim(v_gst_doc_url), ''),
    nullif(trim(v_other_doc_url), ''),
    nullif(trim(v_other_doc_name), ''),
    CASE WHEN v_mark_submitted THEN now() ELSE NULL END
  )
  ON CONFLICT ON CONSTRAINT partner_kyc_details_partner_id_key DO UPDATE SET
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
    UPDATE partners
    SET kyc_status = 'pending'
    WHERE id = v_store_id
      AND kyc_status IN ('rejected', 'pending');
  END IF;

  RETURN row_to_json(result_row);
END;
$$;

GRANT EXECUTE ON FUNCTION get_partner_store_kyc(UUID, TEXT, UUID)
  TO anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION upsert_partner_store_kyc(
  UUID, TEXT, UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, BOOLEAN
) TO anon, authenticated, service_role;

NOTIFY pgrst, 'reload schema';
