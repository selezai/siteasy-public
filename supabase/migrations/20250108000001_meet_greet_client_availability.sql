-- Migration: Change meet & greet flow to client-driven availability
-- Client selects date range when booking, sitter picks from that range
-- Meet & greet always at client's house (remove video call option)

-- Add client's meet & greet availability to bookings table
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS meet_greet_start_date DATE;
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS meet_greet_end_date DATE;
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS meet_greet_start_time TIME;
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS meet_greet_end_time TIME;

-- Remove video call columns from meet_greets table (no longer needed)
ALTER TABLE meet_greets DROP COLUMN IF EXISTS is_video_call;
ALTER TABLE meet_greets DROP COLUMN IF EXISTS video_call_link;
ALTER TABLE meet_greets DROP COLUMN IF EXISTS video_call_completed_at;

-- Remove video call from bookings table if it exists
ALTER TABLE bookings DROP COLUMN IF EXISTS is_video_call;

-- Add comment for clarity
COMMENT ON COLUMN bookings.meet_greet_start_date IS 'Start of date range when client is available for meet & greet';
COMMENT ON COLUMN bookings.meet_greet_end_date IS 'End of date range when client is available for meet & greet';
COMMENT ON COLUMN bookings.meet_greet_start_time IS 'Earliest time client is available each day for meet & greet';
COMMENT ON COLUMN bookings.meet_greet_end_time IS 'Latest time client is available each day for meet & greet';
