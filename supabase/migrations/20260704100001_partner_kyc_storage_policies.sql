-- Storage policies for partner KYC document uploads (admin app uses anon key)

DROP POLICY IF EXISTS "partner_kyc_public_read" ON storage.objects;
CREATE POLICY "partner_kyc_public_read"
ON storage.objects FOR SELECT
USING (bucket_id = 'partner-kyc');

DROP POLICY IF EXISTS "partner_kyc_anon_insert" ON storage.objects;
CREATE POLICY "partner_kyc_anon_insert"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'partner-kyc');

DROP POLICY IF EXISTS "partner_kyc_anon_update" ON storage.objects;
CREATE POLICY "partner_kyc_anon_update"
ON storage.objects FOR UPDATE
USING (bucket_id = 'partner-kyc')
WITH CHECK (bucket_id = 'partner-kyc');
