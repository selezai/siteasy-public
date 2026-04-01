-- Fix messages table - make booking_id nullable for conversation-based messaging
ALTER TABLE messages ALTER COLUMN booking_id DROP NOT NULL;

-- Fix messages INSERT policy - drop old policy that requires booking_id
DROP POLICY IF EXISTS "Booking participants can send messages" ON messages;
DROP POLICY IF EXISTS "Booking participants can view messages" ON messages;

-- Recreate the INSERT policy to allow conversation-based messaging
DROP POLICY IF EXISTS "Users can send messages in their conversations" ON messages;

CREATE POLICY "Users can send messages in their conversations"
  ON messages FOR INSERT
  WITH CHECK (
    auth.uid() = sender_id
    AND (
      -- Allow if user is part of the conversation
      EXISTS (
        SELECT 1 FROM conversations c
        WHERE c.id = conversation_id
        AND (c.client_id = auth.uid() OR c.sitter_id = auth.uid())
      )
      OR
      -- Also allow if user is part of the booking (for legacy messages)
      (
        booking_id IS NOT NULL
        AND EXISTS (
          SELECT 1 FROM bookings b
          WHERE b.id = booking_id
          AND (b.client_id = auth.uid() OR b.sitter_id = auth.uid())
        )
      )
    )
  );
