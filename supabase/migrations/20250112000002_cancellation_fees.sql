-- Migration: Add cancellation fee tracking to bookings
-- Tracks fees charged when clients cancel or change dates

-- Add cancellation fee fields to bookings table
ALTER TABLE bookings
ADD COLUMN IF NOT EXISTS cancellation_fee DECIMAL(10,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS cancellation_fee_sitter_portion DECIMAL(10,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS cancellation_fee_platform_portion DECIMAL(10,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS cancellation_reason TEXT;

-- Add comments for documentation
COMMENT ON COLUMN bookings.cancellation_fee IS 'Total cancellation fee charged to client';
COMMENT ON COLUMN bookings.cancellation_fee_sitter_portion IS 'Portion of cancellation fee paid to sitter';
COMMENT ON COLUMN bookings.cancellation_fee_platform_portion IS 'Portion of cancellation fee kept by platform';
COMMENT ON COLUMN bookings.cancelled_at IS 'Timestamp when booking was cancelled';
COMMENT ON COLUMN bookings.cancellation_reason IS 'Reason provided for cancellation';
