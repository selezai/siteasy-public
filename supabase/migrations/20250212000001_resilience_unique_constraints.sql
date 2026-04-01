-- Resilience fixes: Add unique constraints to prevent duplicate records
-- See RESILIENCE_AUDIT.md for full context

-- 1. Prevent duplicate transactions for the same payment reference
-- Without this, retried verify calls or webhook+verify race conditions create duplicate rows
CREATE UNIQUE INDEX IF NOT EXISTS idx_transactions_payment_provider_ref 
  ON transactions(payment_provider_ref) 
  WHERE payment_provider_ref IS NOT NULL;

-- 2. Prevent duplicate reviews per booking per reviewer
-- Without this, opening two tabs and submitting both creates duplicate reviews that skew ratings
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'unique_review_per_booking_reviewer') THEN
    ALTER TABLE reviews ADD CONSTRAINT unique_review_per_booking_reviewer UNIQUE(booking_id, reviewer_id);
  END IF;
END $$;

-- 3. Prevent duplicate payout releases per booking per release type
-- Without this, cron retries can create duplicate payout records
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'unique_payout_per_booking_release_type') THEN
    ALTER TABLE payout_releases ADD CONSTRAINT unique_payout_per_booking_release_type UNIQUE(booking_id, release_type);
  END IF;
END $$;

-- 4. Prevent overlapping bookings for the same sitter
-- Without this, two clients can book the same sitter for overlapping dates
-- Requires btree_gist extension for exclusion constraints with non-geometric types
CREATE EXTENSION IF NOT EXISTS btree_gist;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'no_overlapping_sitter_bookings') THEN
    ALTER TABLE bookings ADD CONSTRAINT no_overlapping_sitter_bookings 
      EXCLUDE USING gist (
        sitter_id WITH =, 
        daterange(start_date, end_date, '[]') WITH &&
      ) WHERE (status NOT IN ('cancelled'));
  END IF;
END $$;
