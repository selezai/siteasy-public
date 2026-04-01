-- Create conversations table for unified messaging per client-sitter pair
CREATE TABLE conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  sitter_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  last_message_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(client_id, sitter_id)
);

-- Add conversation_id to messages table
ALTER TABLE messages ADD COLUMN conversation_id UUID REFERENCES conversations(id) ON DELETE CASCADE;

-- Create index for faster lookups
CREATE INDEX idx_conversations_client_id ON conversations(client_id);
CREATE INDEX idx_conversations_sitter_id ON conversations(sitter_id);
CREATE INDEX idx_conversations_last_message ON conversations(last_message_at DESC);
CREATE INDEX idx_messages_conversation_id ON messages(conversation_id);

-- Migrate existing messages to conversations
-- First, create conversations for all existing client-sitter pairs
INSERT INTO conversations (client_id, sitter_id, created_at, last_message_at)
SELECT DISTINCT 
  b.client_id,
  b.sitter_id,
  MIN(m.created_at),
  MAX(m.created_at)
FROM messages m
JOIN bookings b ON m.booking_id = b.id
GROUP BY b.client_id, b.sitter_id
ON CONFLICT (client_id, sitter_id) DO NOTHING;

-- Update existing messages with conversation_id
UPDATE messages m
SET conversation_id = c.id
FROM bookings b, conversations c
WHERE m.booking_id = b.id
  AND c.client_id = b.client_id
  AND c.sitter_id = b.sitter_id;

-- Enable RLS on conversations
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;

-- Policies for conversations
CREATE POLICY "Users can view their own conversations"
  ON conversations FOR SELECT
  USING (auth.uid() = client_id OR auth.uid() = sitter_id);

CREATE POLICY "Users can create conversations they're part of"
  ON conversations FOR INSERT
  WITH CHECK (auth.uid() = client_id OR auth.uid() = sitter_id);

CREATE POLICY "Users can update their own conversations"
  ON conversations FOR UPDATE
  USING (auth.uid() = client_id OR auth.uid() = sitter_id);

-- Update messages policies to include conversation-based access
DROP POLICY IF EXISTS "Users can view messages for their bookings" ON messages;
DROP POLICY IF EXISTS "Users can send messages for their bookings" ON messages;

CREATE POLICY "Users can view messages in their conversations"
  ON messages FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM conversations c
      WHERE c.id = messages.conversation_id
      AND (c.client_id = auth.uid() OR c.sitter_id = auth.uid())
    )
    OR
    EXISTS (
      SELECT 1 FROM bookings b
      WHERE b.id = messages.booking_id
      AND (b.client_id = auth.uid() OR b.sitter_id = auth.uid())
    )
  );

CREATE POLICY "Users can send messages in their conversations"
  ON messages FOR INSERT
  WITH CHECK (
    auth.uid() = sender_id
    AND (
      EXISTS (
        SELECT 1 FROM conversations c
        WHERE c.id = conversation_id
        AND (c.client_id = auth.uid() OR c.sitter_id = auth.uid())
      )
      OR
      EXISTS (
        SELECT 1 FROM bookings b
        WHERE b.id = booking_id
        AND (b.client_id = auth.uid() OR b.sitter_id = auth.uid())
      )
    )
  );

-- Function to update conversation last_message_at when a new message is sent
CREATE OR REPLACE FUNCTION update_conversation_last_message()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.conversation_id IS NOT NULL THEN
    UPDATE conversations
    SET last_message_at = NOW()
    WHERE id = NEW.conversation_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update last_message_at
DROP TRIGGER IF EXISTS update_conversation_timestamp ON messages;
CREATE TRIGGER update_conversation_timestamp
  AFTER INSERT ON messages
  FOR EACH ROW
  EXECUTE FUNCTION update_conversation_last_message();

-- Function to get or create a conversation
CREATE OR REPLACE FUNCTION get_or_create_conversation(p_client_id UUID, p_sitter_id UUID)
RETURNS UUID AS $$
DECLARE
  v_conversation_id UUID;
BEGIN
  -- Try to find existing conversation
  SELECT id INTO v_conversation_id
  FROM conversations
  WHERE client_id = p_client_id AND sitter_id = p_sitter_id;
  
  -- If not found, create one
  IF v_conversation_id IS NULL THEN
    INSERT INTO conversations (client_id, sitter_id)
    VALUES (p_client_id, p_sitter_id)
    RETURNING id INTO v_conversation_id;
  END IF;
  
  RETURN v_conversation_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
