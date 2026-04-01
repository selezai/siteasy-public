-- Replace years_experience with pet_care_background array
-- This is more inclusive for newcomers and captures qualitative experience

ALTER TABLE sitter_profiles ADD COLUMN pet_care_background TEXT[] DEFAULT '{}';

-- Migrate existing data: if years_experience > 0, add "professional_experience"
UPDATE sitter_profiles 
SET pet_care_background = ARRAY['professional_experience']
WHERE years_experience > 0;

-- Note: We keep years_experience column for now to avoid breaking changes
-- It can be removed in a future migration after confirming no dependencies
