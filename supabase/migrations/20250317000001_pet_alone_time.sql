-- Add alone_time fields to pets table
-- alone_time: required dropdown value for how long the pet can be left alone
-- alone_time_notes: optional text for additional context

ALTER TABLE pets
ADD COLUMN alone_time TEXT NOT NULL DEFAULT 'not_set',
ADD COLUMN alone_time_notes TEXT;

-- Update existing pets to have a default value (they'll need to update on next edit)
-- The 'not_set' default allows existing pets to remain valid while new pets must select a value

COMMENT ON COLUMN pets.alone_time IS 'How long the pet can be left alone: cannot_be_left_alone, up_to_1_hour, 1_to_2_hours, 2_to_4_hours, 4_to_6_hours, 6_to_8_hours, 8_plus_hours';
COMMENT ON COLUMN pets.alone_time_notes IS 'Optional notes about alone time requirements';
