-- Check-in feature for sitters to provide updates during bookings

-- Activity types for check-ins
CREATE TYPE check_in_activity_type AS ENUM (
  'fed_pets',
  'walked_dogs',
  'played_with_pets',
  'gave_medication',
  'groomed_pets',
  'cleaned_litter',
  'watered_plants',
  'collected_mail',
  'security_check',
  'general_update',
  'arrival',
  'departure',
  'other'
);

-- Main check-ins table
CREATE TABLE check_ins (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  sitter_id UUID NOT NULL REFERENCES profiles(id),
  
  -- Content
  caption TEXT,
  
  -- Location verification (optional)
  latitude DECIMAL(10, 8),
  longitude DECIMAL(11, 8),
  location_verified BOOLEAN DEFAULT FALSE,
  location_accuracy_meters INTEGER,
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Metadata
  is_daily_required BOOLEAN DEFAULT TRUE -- Marks if this counts as the daily required check-in
);

-- Photos attached to check-ins
CREATE TABLE check_in_photos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  check_in_id UUID NOT NULL REFERENCES check_ins(id) ON DELETE CASCADE,
  photo_url TEXT NOT NULL,
  photo_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Activities logged with check-ins
CREATE TABLE check_in_activities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  check_in_id UUID NOT NULL REFERENCES check_ins(id) ON DELETE CASCADE,
  activity_type check_in_activity_type NOT NULL,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Track daily check-in status for each booking day
CREATE TABLE booking_check_in_status (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  check_in_date DATE NOT NULL,
  has_checked_in BOOLEAN DEFAULT FALSE,
  check_in_id UUID REFERENCES check_ins(id),
  reminder_sent BOOLEAN DEFAULT FALSE,
  warning_sent BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(booking_id, check_in_date)
);

-- Indexes for performance
CREATE INDEX idx_check_ins_booking ON check_ins(booking_id);
CREATE INDEX idx_check_ins_sitter ON check_ins(sitter_id);
CREATE INDEX idx_check_ins_created ON check_ins(created_at DESC);
CREATE INDEX idx_check_in_photos_check_in ON check_in_photos(check_in_id);
CREATE INDEX idx_check_in_activities_check_in ON check_in_activities(check_in_id);
CREATE INDEX idx_booking_check_in_status_booking ON booking_check_in_status(booking_id);
CREATE INDEX idx_booking_check_in_status_date ON booking_check_in_status(check_in_date);

-- RLS Policies
ALTER TABLE check_ins ENABLE ROW LEVEL SECURITY;
ALTER TABLE check_in_photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE check_in_activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE booking_check_in_status ENABLE ROW LEVEL SECURITY;

-- Sitters can create and view their own check-ins
CREATE POLICY "Sitters can create check-ins" ON check_ins
  FOR INSERT WITH CHECK (auth.uid() = sitter_id);

CREATE POLICY "Sitters can view their check-ins" ON check_ins
  FOR SELECT USING (auth.uid() = sitter_id);

-- Clients can view check-ins for their bookings
CREATE POLICY "Clients can view check-ins for their bookings" ON check_ins
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM bookings 
      WHERE bookings.id = check_ins.booking_id 
      AND bookings.client_id = auth.uid()
    )
  );

-- Photo policies
CREATE POLICY "Sitters can manage check-in photos" ON check_in_photos
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM check_ins 
      WHERE check_ins.id = check_in_photos.check_in_id 
      AND check_ins.sitter_id = auth.uid()
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

-- Activity policies
CREATE POLICY "Sitters can manage check-in activities" ON check_in_activities
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM check_ins 
      WHERE check_ins.id = check_in_activities.check_in_id 
      AND check_ins.sitter_id = auth.uid()
    )
  );

CREATE POLICY "Clients can view check-in activities" ON check_in_activities
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM check_ins 
      JOIN bookings ON bookings.id = check_ins.booking_id
      WHERE check_ins.id = check_in_activities.check_in_id 
      AND bookings.client_id = auth.uid()
    )
  );

-- Status policies
CREATE POLICY "Booking parties can view check-in status" ON booking_check_in_status
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM bookings 
      WHERE bookings.id = booking_check_in_status.booking_id 
      AND (bookings.client_id = auth.uid() OR bookings.sitter_id = auth.uid())
    )
  );

CREATE POLICY "System can manage check-in status" ON booking_check_in_status
  FOR ALL USING (true);

COMMENT ON TABLE check_ins IS 'Sitter check-ins during active bookings with photos and activities';
COMMENT ON TABLE check_in_photos IS 'Photos attached to check-ins';
COMMENT ON TABLE check_in_activities IS 'Activities logged during check-ins';
COMMENT ON TABLE booking_check_in_status IS 'Tracks daily check-in requirements for each booking day';
