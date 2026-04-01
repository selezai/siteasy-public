-- Add UPDATE policy for messages to allow marking messages as read
-- Only the recipient (non-sender) can mark messages as read

CREATE POLICY "Recipients can mark messages as read" ON messages
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM bookings 
            WHERE bookings.id = messages.booking_id 
            AND (bookings.client_id = auth.uid() OR bookings.sitter_id = auth.uid())
        )
        AND sender_id != auth.uid()
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM bookings 
            WHERE bookings.id = messages.booking_id 
            AND (bookings.client_id = auth.uid() OR bookings.sitter_id = auth.uid())
        )
        AND sender_id != auth.uid()
    );
