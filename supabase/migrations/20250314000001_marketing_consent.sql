-- Add marketing consent column to profiles table for POPIA/ECTA compliance
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS marketing_consent BOOLEAN DEFAULT FALSE;

-- Add comment explaining the column
COMMENT ON COLUMN profiles.marketing_consent IS 'User consent to receive promotional emails and updates (POPIA/ECTA compliant opt-in)';
