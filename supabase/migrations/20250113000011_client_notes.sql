-- Client notes table for sitters to keep private notes about clients
CREATE TABLE client_notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sitter_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  client_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  
  content TEXT NOT NULL,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_client_notes_sitter ON client_notes(sitter_id);
CREATE INDEX idx_client_notes_client ON client_notes(client_id);
CREATE INDEX idx_client_notes_sitter_client ON client_notes(sitter_id, client_id);

-- RLS
ALTER TABLE client_notes ENABLE ROW LEVEL SECURITY;

-- Sitters can view their own notes
CREATE POLICY "Sitters can view their own notes" ON client_notes
  FOR SELECT USING (sitter_id = auth.uid());

-- Sitters can insert their own notes
CREATE POLICY "Sitters can insert their own notes" ON client_notes
  FOR INSERT WITH CHECK (sitter_id = auth.uid());

-- Sitters can update their own notes
CREATE POLICY "Sitters can update their own notes" ON client_notes
  FOR UPDATE USING (sitter_id = auth.uid());

-- Sitters can delete their own notes
CREATE POLICY "Sitters can delete their own notes" ON client_notes
  FOR DELETE USING (sitter_id = auth.uid());

COMMENT ON TABLE client_notes IS 'Private notes sitters keep about their clients';
