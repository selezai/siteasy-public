-- Affiliate recruiters system
-- Affiliates are external people who recruit sitters via unique links.
-- Their commission (5% of platform_fee) is calculated at read-time in the admin dashboard,
-- NOT stored on bookings. Zero changes to booking flow.

-- 1. Affiliates table
CREATE TABLE IF NOT EXISTS affiliates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  phone TEXT,
  affiliate_code TEXT NOT NULL UNIQUE,
  is_active BOOLEAN NOT NULL DEFAULT true,
  commission_rate NUMERIC(5,4) NOT NULL DEFAULT 0.3333,
  -- 0.3333 = affiliate gets 1/3 of platform_fee (5% out of 15%)
  -- Stored as fraction of platform_fee, NOT fraction of total_amount
  -- So affiliate_earning = platform_fee * commission_rate
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Link waitlist signups to the affiliate who recruited them
ALTER TABLE sitter_waitlist
  ADD COLUMN IF NOT EXISTS affiliate_id UUID REFERENCES affiliates(id);

-- 3. Permanent link: sitter → affiliate (copied from waitlist on signup)
ALTER TABLE sitter_profiles
  ADD COLUMN IF NOT EXISTS affiliate_id UUID REFERENCES affiliates(id);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_affiliates_code ON affiliates (affiliate_code);
CREATE INDEX IF NOT EXISTS idx_affiliates_active ON affiliates (is_active);
CREATE INDEX IF NOT EXISTS idx_sitter_profiles_affiliate ON sitter_profiles (affiliate_id);
CREATE INDEX IF NOT EXISTS idx_waitlist_affiliate ON sitter_waitlist (affiliate_id);

-- RLS (service_role + admin read)
ALTER TABLE affiliates ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can read affiliates"
  ON affiliates FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
  );

-- Updated_at trigger
CREATE OR REPLACE FUNCTION update_affiliates_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER affiliates_updated_at
  BEFORE UPDATE ON affiliates
  FOR EACH ROW
  EXECUTE FUNCTION update_affiliates_updated_at();
