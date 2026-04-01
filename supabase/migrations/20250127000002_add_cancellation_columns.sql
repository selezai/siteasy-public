-- Add columns for in-progress booking cancellation tracking

ALTER TABLE bookings 
ADD COLUMN IF NOT EXISTS days_worked_at_cancellation INTEGER,
ADD COLUMN IF NOT EXISTS client_refund_amount DECIMAL(10,2);

-- Note: sitter_payout and platform_fee columns already exist
-- cancellation_fee, cancellation_fee_sitter_portion, cancellation_fee_platform_portion already exist
