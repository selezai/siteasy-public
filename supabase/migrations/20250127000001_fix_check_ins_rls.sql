-- Fix RLS policy for check_ins to allow sitters to view check-ins for bookings they're assigned to

-- Drop existing select policies
DROP POLICY IF EXISTS "Sitters can view their check-ins" ON check_ins;
DROP POLICY IF EXISTS "Clients can view check-ins for their bookings" ON check_ins;

-- Create new policy that allows sitters to view check-ins for their bookings
CREATE POLICY "Sitters can view check-ins for their bookings" ON check_ins
  FOR SELECT USING (
    auth.uid() = sitter_id
    OR
    EXISTS (
      SELECT 1 FROM bookings 
      WHERE bookings.id = check_ins.booking_id 
      AND bookings.sitter_id = auth.uid()
    )
  );

-- Recreate client policy
CREATE POLICY "Clients can view check-ins for their bookings" ON check_ins
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM bookings 
      WHERE bookings.id = check_ins.booking_id 
      AND bookings.client_id = auth.uid()
    )
  );

-- Also fix check_in_photos policy to allow sitters to view photos for their bookings
DROP POLICY IF EXISTS "Sitters can manage check-in photos" ON check_in_photos;
DROP POLICY IF EXISTS "Clients can view check-in photos" ON check_in_photos;

CREATE POLICY "Sitters can manage check-in photos" ON check_in_photos
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM check_ins 
      JOIN bookings ON bookings.id = check_ins.booking_id
      WHERE check_ins.id = check_in_photos.check_in_id 
      AND bookings.sitter_id = auth.uid()
    )
  );

CREATE POLICY "Clients can view check-in photos" ON check_in_photos
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM check_ins 
      JOIN bookings ON bookings.id = check_ins.booking_id
      WHERE check_ins.id = check_in_photos.check_in_id 
      AND bookings.client_id = auth.uid()
    )
  );
