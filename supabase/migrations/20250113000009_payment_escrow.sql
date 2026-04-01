-- Payment escrow system for 50/50 split
-- Client pays 100% upfront, held in escrow
-- 50% released to sitter when booking starts
-- 50% released to sitter when booking completes

-- Payment status enum
CREATE TYPE payment_status AS ENUM (
  'pending',
  'paid',
  'in_escrow',
  'partially_released',
  'fully_released',
  'refunded',
  'disputed'
);

-- Escrow release type
CREATE TYPE escrow_release_type AS ENUM (
  'booking_started',
  'booking_completed',
  'dispute_resolved',
  'cancellation_refund'
);

-- Update bookings table with escrow fields
ALTER TABLE bookings
ADD COLUMN IF NOT EXISTS payment_status payment_status DEFAULT 'pending',
ADD COLUMN IF NOT EXISTS escrow_amount INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS amount_released_to_sitter INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS amount_refunded_to_client INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS paid_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS escrow_released_at TIMESTAMPTZ;

-- Payment transactions table for tracking all money movements
CREATE TABLE payment_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  
  -- Transaction details
  transaction_type TEXT NOT NULL, -- 'client_payment', 'sitter_payout', 'platform_fee', 'refund'
  amount INTEGER NOT NULL, -- Amount in cents
  
  -- For dummy transactions
  is_dummy BOOLEAN DEFAULT TRUE,
  
  -- Reference IDs (for real payment integration later)
  external_reference TEXT,
  
  -- Status
  status TEXT NOT NULL DEFAULT 'completed', -- 'pending', 'completed', 'failed'
  
  -- Metadata
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Escrow releases table
CREATE TABLE escrow_releases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  
  release_type escrow_release_type NOT NULL,
  amount INTEGER NOT NULL, -- Amount released in cents
  recipient_id UUID NOT NULL REFERENCES profiles(id), -- Who received the money
  recipient_type TEXT NOT NULL, -- 'sitter' or 'client'
  
  -- For tracking
  release_percentage INTEGER, -- e.g., 50 for 50%
  notes TEXT,
  
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_payment_transactions_booking ON payment_transactions(booking_id);
CREATE INDEX idx_escrow_releases_booking ON escrow_releases(booking_id);
CREATE INDEX idx_bookings_payment_status ON bookings(payment_status);

-- RLS Policies
ALTER TABLE payment_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE escrow_releases ENABLE ROW LEVEL SECURITY;

-- Both parties can view payment transactions for their bookings
CREATE POLICY "Booking parties can view payment transactions" ON payment_transactions
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM bookings 
      WHERE bookings.id = payment_transactions.booking_id 
      AND (bookings.client_id = auth.uid() OR bookings.sitter_id = auth.uid())
    )
  );

-- Both parties can view escrow releases for their bookings
CREATE POLICY "Booking parties can view escrow releases" ON escrow_releases
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM bookings 
      WHERE bookings.id = escrow_releases.booking_id 
      AND (bookings.client_id = auth.uid() OR bookings.sitter_id = auth.uid())
    )
  );

COMMENT ON TABLE payment_transactions IS 'Tracks all payment movements for bookings';
COMMENT ON TABLE escrow_releases IS 'Tracks escrow releases to sitters and refunds to clients';
