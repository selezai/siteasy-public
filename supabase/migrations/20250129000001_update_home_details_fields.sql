-- Update home details fields: replace has_pool with has_camera_system and add has_wifi

-- Add new columns
ALTER TABLE client_profiles ADD COLUMN IF NOT EXISTS has_camera_system BOOLEAN DEFAULT false;
ALTER TABLE client_profiles ADD COLUMN IF NOT EXISTS has_wifi BOOLEAN DEFAULT false;

-- Migrate existing has_pool data to has_camera_system (optional - can be removed if not needed)
-- UPDATE client_profiles SET has_camera_system = has_pool WHERE has_pool = true;

-- Drop the old column
ALTER TABLE client_profiles DROP COLUMN IF EXISTS has_pool;
