-- Add index on profiles.city for faster location-based sitter search
-- Also add index on agencies.city for agency location filtering

CREATE INDEX IF NOT EXISTS idx_profiles_city ON profiles(city);
CREATE INDEX IF NOT EXISTS idx_profiles_suburb ON profiles(suburb);
