-- Rename escrow terminology to payment hold terminology
-- This migration renames columns and tables to avoid "escrow" terminology
-- Made idempotent: checks if columns/tables already renamed before attempting

-- 1. Rename escrow_releases table to payout_releases
ALTER TABLE IF EXISTS escrow_releases RENAME TO payout_releases;

-- 2. Rename escrow_amount column to held_amount in bookings table (if not already renamed)
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'bookings' AND column_name = 'escrow_amount') THEN
    ALTER TABLE bookings RENAME COLUMN escrow_amount TO held_amount;
  END IF;
END $$;

-- 3. Rename escrow_released_at column to payout_completed_at in bookings table (if not already renamed)
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'bookings' AND column_name = 'escrow_released_at') THEN
    ALTER TABLE bookings RENAME COLUMN escrow_released_at TO payout_completed_at;
  END IF;
END $$;

-- 4. Update payment_status - keep using in_escrow in database but code uses payment_secured
-- The application code will handle the mapping. We'll keep in_escrow as the DB value
-- to avoid enum modification issues. The UI/code uses "payment_secured" terminology.

-- 5. Add comment explaining the terminology change
COMMENT ON TABLE payout_releases IS 'Records of sitter payouts released from held funds (formerly escrow_releases)';
COMMENT ON COLUMN bookings.held_amount IS 'Amount held for sitter payout after platform fee deduction (formerly escrow_amount)';
COMMENT ON COLUMN bookings.payout_completed_at IS 'Timestamp when full payout was completed (formerly escrow_released_at)';
