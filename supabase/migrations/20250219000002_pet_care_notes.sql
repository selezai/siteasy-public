-- Per-pet care notes that sitters keep across bookings
-- These persist and carry forward to future bookings with the same client
-- e.g. "Max doesn't like loud noises", "Give medication at 8am", "Prefers the blue bowl"

CREATE TABLE IF NOT EXISTS pet_care_notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sitter_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  pet_id UUID NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
  booking_id UUID REFERENCES bookings(id) ON DELETE SET NULL,
  
  content TEXT NOT NULL,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_pet_care_notes_sitter ON pet_care_notes(sitter_id);
CREATE INDEX IF NOT EXISTS idx_pet_care_notes_pet ON pet_care_notes(pet_id);
CREATE INDEX IF NOT EXISTS idx_pet_care_notes_sitter_pet ON pet_care_notes(sitter_id, pet_id);
CREATE INDEX IF NOT EXISTS idx_pet_care_notes_booking ON pet_care_notes(booking_id);

-- RLS
ALTER TABLE pet_care_notes ENABLE ROW LEVEL SECURITY;

-- Sitters can view their own pet care notes
DROP POLICY IF EXISTS "Sitters can view their own pet care notes" ON pet_care_notes;
CREATE POLICY "Sitters can view their own pet care notes" ON pet_care_notes
  FOR SELECT USING (sitter_id = auth.uid());

-- Sitters can insert their own pet care notes
DROP POLICY IF EXISTS "Sitters can insert their own pet care notes" ON pet_care_notes;
CREATE POLICY "Sitters can insert their own pet care notes" ON pet_care_notes
  FOR INSERT WITH CHECK (sitter_id = auth.uid());

-- Sitters can update their own pet care notes
DROP POLICY IF EXISTS "Sitters can update their own pet care notes" ON pet_care_notes;
CREATE POLICY "Sitters can update their own pet care notes" ON pet_care_notes
  FOR UPDATE USING (sitter_id = auth.uid());

-- Sitters can delete their own pet care notes
DROP POLICY IF EXISTS "Sitters can delete their own pet care notes" ON pet_care_notes;
CREATE POLICY "Sitters can delete their own pet care notes" ON pet_care_notes
  FOR DELETE USING (sitter_id = auth.uid());

COMMENT ON TABLE pet_care_notes IS 'Per-pet care notes sitters keep that persist across bookings. Used to remember pet preferences, quirks, and care instructions.';
