-- Remove client ID verification columns
-- Clients do not need ID verification; trust is established through payment method.
-- Sitter verification remains unchanged.

ALTER TABLE client_profiles DROP COLUMN IF EXISTS id_document_url;
ALTER TABLE client_profiles DROP COLUMN IF EXISTS id_verified;
ALTER TABLE client_profiles DROP COLUMN IF EXISTS selfie_url;
ALTER TABLE client_profiles DROP COLUMN IF EXISTS selfie_verified;
