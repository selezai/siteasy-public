-- Add Paystack transfer support for sitter payouts
-- Architecture: single payout after booking completion (50/50 is UI-only)

-- 0. Add new release types to the enum for cancellation transfers
ALTER TYPE escrow_release_type ADD VALUE IF NOT EXISTS 'cancellation_fee';
ALTER TYPE escrow_release_type ADD VALUE IF NOT EXISTS 'in_progress_cancellation';

-- 1. Add paystack_recipient_code to sitter_profiles
ALTER TABLE sitter_profiles
ADD COLUMN IF NOT EXISTS paystack_recipient_code TEXT;

COMMENT ON COLUMN sitter_profiles.paystack_recipient_code IS 'Paystack Transfer Recipient code (RCP_xxx) for automated payouts';

-- 2. Add transfer tracking columns to payout_releases
ALTER TABLE payout_releases
ADD COLUMN IF NOT EXISTS transfer_reference TEXT,
ADD COLUMN IF NOT EXISTS transfer_status TEXT DEFAULT 'pending'
  CHECK (transfer_status IN ('pending', 'initiated', 'success', 'failed', 'reversed')),
ADD COLUMN IF NOT EXISTS transfer_code TEXT,
ADD COLUMN IF NOT EXISTS transfer_initiated_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS transfer_completed_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS transfer_failure_reason TEXT;

COMMENT ON COLUMN payout_releases.transfer_reference IS 'Unique reference sent to Paystack for this transfer (used for idempotency)';
COMMENT ON COLUMN payout_releases.transfer_status IS 'Status of the actual Paystack transfer: pending (not yet initiated), initiated, success, failed, reversed';
COMMENT ON COLUMN payout_releases.transfer_code IS 'Paystack transfer code (TRF_xxx) returned after initiation';
COMMENT ON COLUMN payout_releases.transfer_initiated_at IS 'When the Paystack transfer API was called';
COMMENT ON COLUMN payout_releases.transfer_completed_at IS 'When the transfer was confirmed success/failed/reversed';
COMMENT ON COLUMN payout_releases.transfer_failure_reason IS 'Reason for transfer failure from Paystack';

-- 3. Index for finding transfers that need to be initiated or retried
CREATE INDEX IF NOT EXISTS idx_payout_releases_transfer_status
  ON payout_releases(transfer_status)
  WHERE transfer_status IN ('pending', 'initiated', 'failed');

-- 4. Unique index on transfer_reference for idempotency
CREATE UNIQUE INDEX IF NOT EXISTS idx_payout_releases_transfer_reference
  ON payout_releases(transfer_reference)
  WHERE transfer_reference IS NOT NULL;
