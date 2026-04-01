-- Add selfie with ID verification fields to sitter_profiles
-- This is required for the "Verified" tier badge

-- Add selfie_with_id_url column to store the uploaded selfie image
ALTER TABLE sitter_profiles 
ADD COLUMN IF NOT EXISTS selfie_with_id_url TEXT;

-- Add is_selfie_verified column for admin verification status
ALTER TABLE sitter_profiles 
ADD COLUMN IF NOT EXISTS is_selfie_verified BOOLEAN DEFAULT FALSE;

-- Rename existing columns for consistency (if they exist with old names)
-- is_id_verified and has_police_clearance should already exist from previous migrations

-- Add comment explaining the verification flow
COMMENT ON COLUMN sitter_profiles.selfie_with_id_url IS 'URL to selfie image where sitter holds their ID next to their face';
COMMENT ON COLUMN sitter_profiles.is_selfie_verified IS 'Admin-verified that selfie matches the ID document';
