-- Add drop_in_visits as a new service type
-- This is for sitters who visit the home periodically during the day rather than staying overnight

-- Add visits_per_day field to bookings for drop-in visits
ALTER TABLE bookings
ADD COLUMN IF NOT EXISTS visits_per_day INTEGER DEFAULT 1,
ADD COLUMN IF NOT EXISTS visit_duration_minutes INTEGER DEFAULT 30,
ADD COLUMN IF NOT EXISTS preferred_visit_times TEXT[]; -- Array of preferred times like ['09:00', '14:00', '18:00']

COMMENT ON COLUMN bookings.visits_per_day IS 'Number of visits per day for drop-in visit bookings';
COMMENT ON COLUMN bookings.visit_duration_minutes IS 'Duration of each visit in minutes';
COMMENT ON COLUMN bookings.preferred_visit_times IS 'Preferred times for visits';

-- Update sitter_profiles to have rate_per_visit for drop-in services
-- (rate_per_visit column already exists from initial schema)
