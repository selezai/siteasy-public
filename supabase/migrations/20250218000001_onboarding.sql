-- Add onboarding tracking fields to profiles table
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS onboarding_completed BOOLEAN DEFAULT FALSE;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS onboarding_completed_at TIMESTAMPTZ;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS onboarding_preferences JSONB DEFAULT '{}';

-- Grandfather ALL existing users — they should NOT be forced through onboarding
-- Any profile that exists at migration time is an existing user by definition
UPDATE profiles SET onboarding_completed = TRUE;

-- Index for middleware lookups (checking onboarding status on every request)
CREATE INDEX IF NOT EXISTS idx_profiles_onboarding ON profiles(id, onboarding_completed);
