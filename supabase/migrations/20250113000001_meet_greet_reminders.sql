-- Migration: Add meet & greet reminder tracking fields
-- Tracks when reminders were sent and enables auto-cancellation after 72 hours

-- Add reminder tracking fields to meet_greets table
ALTER TABLE meet_greets
ADD COLUMN IF NOT EXISTS reminder_24h_sent_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS reminder_48h_sent_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS auto_cancelled_at TIMESTAMPTZ;

-- Add comments for documentation
COMMENT ON COLUMN meet_greets.reminder_24h_sent_at IS 'Timestamp when 24-hour reminder was sent after meet & greet date passed';
COMMENT ON COLUMN meet_greets.reminder_48h_sent_at IS 'Timestamp when 48-hour final warning was sent';
COMMENT ON COLUMN meet_greets.auto_cancelled_at IS 'Timestamp when booking was auto-cancelled due to no confirmation';
