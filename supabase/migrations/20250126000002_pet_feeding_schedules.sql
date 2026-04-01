-- Add feeding schedule to pets table
ALTER TABLE pets ADD COLUMN IF NOT EXISTS feeding_schedule JSONB DEFAULT '[]';
-- Format: [{"time": "08:00", "label": "Breakfast"}, {"time": "18:00", "label": "Dinner"}]

-- Add pet-specific fields to check_ins for detailed feeding updates
ALTER TABLE check_ins ADD COLUMN IF NOT EXISTS pet_id UUID REFERENCES pets(id);
ALTER TABLE check_ins ADD COLUMN IF NOT EXISTS update_type TEXT DEFAULT 'general';
-- update_type: 'general', 'feeding', 'overnight', 'arrival', 'departure'

-- Feeding-specific fields
ALTER TABLE check_ins ADD COLUMN IF NOT EXISTS scheduled_feed_time TIME;
ALTER TABLE check_ins ADD COLUMN IF NOT EXISTS actual_feed_time TIME;
ALTER TABLE check_ins ADD COLUMN IF NOT EXISTS food_eaten TEXT CHECK (food_eaten IN ('all', 'most', 'some', 'none'));
ALTER TABLE check_ins ADD COLUMN IF NOT EXISTS water_consumed TEXT CHECK (water_consumed IN ('normal', 'less', 'more', 'none'));

-- Behavior/health tracking
ALTER TABLE check_ins ADD COLUMN IF NOT EXISTS is_abnormal BOOLEAN DEFAULT FALSE;
ALTER TABLE check_ins ADD COLUMN IF NOT EXISTS abnormal_description TEXT;
ALTER TABLE check_ins ADD COLUMN IF NOT EXISTS overnight_notes TEXT;

-- Photo categorization
ALTER TABLE check_in_photos ADD COLUMN IF NOT EXISTS photo_type TEXT DEFAULT 'general';
-- photo_type: 'general', 'pet', 'food', 'water', 'food_after', 'water_after'

-- Index for pet-specific queries
CREATE INDEX IF NOT EXISTS idx_check_ins_pet ON check_ins(pet_id);
CREATE INDEX IF NOT EXISTS idx_check_ins_update_type ON check_ins(update_type);

COMMENT ON COLUMN pets.feeding_schedule IS 'JSON array of feeding times: [{"time": "08:00", "label": "Breakfast"}]';
COMMENT ON COLUMN check_ins.pet_id IS 'Optional: specific pet this update is for';
COMMENT ON COLUMN check_ins.update_type IS 'Type of update: general, feeding, overnight, arrival, departure';
COMMENT ON COLUMN check_ins.food_eaten IS 'How much food was eaten: all, most, some, none';
COMMENT ON COLUMN check_ins.water_consumed IS 'Water consumption level: normal, less, more, none';
COMMENT ON COLUMN check_ins.is_abnormal IS 'Flag if pet is showing abnormal behavior';
COMMENT ON COLUMN check_in_photos.photo_type IS 'Category of photo: general, pet, food, water, food_after, water_after';
