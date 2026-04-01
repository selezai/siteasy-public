-- Add referral tracking columns to sitter_waitlist

ALTER TABLE sitter_waitlist
  ADD COLUMN IF NOT EXISTS referral_code TEXT UNIQUE,
  ADD COLUMN IF NOT EXISTS referred_by TEXT,
  ADD COLUMN IF NOT EXISTS referral_count INTEGER NOT NULL DEFAULT 0;

-- Index for referral code lookups
CREATE INDEX IF NOT EXISTS idx_waitlist_referral_code ON sitter_waitlist (referral_code);

-- Index for referred_by lookups (to find who referred whom)
CREATE INDEX IF NOT EXISTS idx_waitlist_referred_by ON sitter_waitlist (referred_by);

-- RPC function to atomically increment referral_count
CREATE OR REPLACE FUNCTION increment_referral_count(code TEXT)
RETURNS VOID AS $$
BEGIN
  UPDATE sitter_waitlist
  SET referral_count = referral_count + 1
  WHERE referral_code = code;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
