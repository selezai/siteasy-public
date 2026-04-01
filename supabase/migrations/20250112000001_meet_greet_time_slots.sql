-- Migration: Change meet & greet availability from date range to time slots array
-- This allows clients to specify multiple specific date+time windows

-- Drop the old columns
ALTER TABLE bookings 
DROP COLUMN IF EXISTS meet_greet_start_date,
DROP COLUMN IF EXISTS meet_greet_end_date,
DROP COLUMN IF EXISTS meet_greet_start_time,
DROP COLUMN IF EXISTS meet_greet_end_time;

-- Add new JSONB column for time slots
-- Format: [{"date": "2026-01-15", "start_time": "14:00", "end_time": "16:00"}, ...]
ALTER TABLE bookings 
ADD COLUMN IF NOT EXISTS meet_greet_slots JSONB DEFAULT '[]'::jsonb;

-- Add comment for documentation
COMMENT ON COLUMN bookings.meet_greet_slots IS 'Array of available time slots for meet & greet. Format: [{"date": "YYYY-MM-DD", "start_time": "HH:MM", "end_time": "HH:MM"}, ...]';
