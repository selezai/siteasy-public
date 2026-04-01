-- Add INSERT policy for payment_transactions
-- Clients can insert payment transactions for their own bookings

CREATE POLICY "Clients can insert payment transactions for their bookings" ON payment_transactions
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM bookings 
      WHERE bookings.id = payment_transactions.booking_id 
      AND bookings.client_id = auth.uid()
    )
  );

-- Also add INSERT policy for escrow_releases (in case needed)
CREATE POLICY "System can insert escrow releases" ON escrow_releases
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM bookings 
      WHERE bookings.id = escrow_releases.booking_id 
      AND (bookings.client_id = auth.uid() OR bookings.sitter_id = auth.uid())
    )
  );
