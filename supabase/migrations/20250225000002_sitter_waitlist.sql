-- Sitter Waitlist table for pre-launch signup collection
-- Sitters join the waitlist with basic info; once a region hits threshold,
-- they receive an invite to complete full signup + onboarding.

CREATE TABLE IF NOT EXISTS sitter_waitlist (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  phone TEXT NOT NULL,
  city TEXT NOT NULL,
  suburb TEXT NOT NULL,
  pet_types TEXT[] NOT NULL DEFAULT '{}',
  pet_care_background TEXT[] NOT NULL DEFAULT '{}',
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'invited', 'signed_up', 'rejected')),
  invited_at TIMESTAMPTZ,
  signed_up_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index for filtering by city (admin queries)
CREATE INDEX IF NOT EXISTS idx_waitlist_city ON sitter_waitlist (city);

-- Index for filtering by status
CREATE INDEX IF NOT EXISTS idx_waitlist_status ON sitter_waitlist (status);

-- Index for email lookups (uniqueness + queries)
CREATE INDEX IF NOT EXISTS idx_waitlist_email ON sitter_waitlist (email);

-- Enable RLS (no public access — only service_role via API routes)
ALTER TABLE sitter_waitlist ENABLE ROW LEVEL SECURITY;

-- No RLS policies = only service_role can read/write (exactly what we want)

-- Updated_at trigger
CREATE OR REPLACE FUNCTION update_waitlist_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS waitlist_updated_at ON sitter_waitlist;
CREATE TRIGGER waitlist_updated_at
  BEFORE UPDATE ON sitter_waitlist
  FOR EACH ROW
  EXECUTE FUNCTION update_waitlist_updated_at();
