-- KYC storage: 1 MB default uploads, agreement up to 2 MB (enforced in app)

UPDATE storage.buckets
SET file_size_limit = 2097152
WHERE id = 'partner-kyc';
