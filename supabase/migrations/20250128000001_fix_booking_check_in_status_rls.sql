-- Fix RLS policy for booking_check_in_status to allow sitters to upsert

-- Drop the existing overly permissive policy
DROP POLICY IF EXISTS "System can manage check-in status" ON booking_check_in_status;

-- Create proper policy for sitters to insert/update check-in status
CREATE POLICY "Sitters can manage check-in status" ON booking_check_in_status
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM bookings 
      WHERE bookings.id = booking_check_in_status.booking_id 
      AND bookings.sitter_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM bookings 
      WHERE bookings.id = booking_check_in_status.booking_id 
      AND bookings.sitter_id = auth.uid()
    )
  );
