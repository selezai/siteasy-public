-- ============================================
-- BOOKING OVERLAP PROTECTION
-- Prevents double-booking sitters on overlapping dates
-- ============================================

-- Function to check if a sitter has conflicting bookings for given dates
-- Returns true if there IS a conflict (caller should block the action)
-- Excludes a specific booking ID (for reschedule scenarios)
CREATE OR REPLACE FUNCTION check_sitter_date_conflict(
  p_sitter_id UUID,
  p_start_date DATE,
  p_end_date DATE,
  p_exclude_booking_id UUID DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM bookings
    WHERE sitter_id = p_sitter_id
      AND status IN ('confirmed', 'in_progress', 'meet_greet_scheduled')
      AND start_date <= p_end_date
      AND end_date >= p_start_date
      AND (p_exclude_booking_id IS NULL OR id != p_exclude_booking_id)
  );
END;
$$;

-- Atomic accept: confirms a booking only if no overlapping confirmed/in_progress bookings exist
-- Returns the booking ID on success, NULL if conflict detected
-- Uses SELECT ... FOR UPDATE to lock the row and prevent race conditions
CREATE OR REPLACE FUNCTION accept_booking_if_no_conflict(
  p_booking_id UUID,
  p_sitter_id UUID
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_booking RECORD;
  v_has_conflict BOOLEAN;
BEGIN
  -- Lock the booking row to prevent concurrent modifications
  SELECT id, sitter_id, start_date, end_date, status
  INTO v_booking
  FROM bookings
  WHERE id = p_booking_id
  FOR UPDATE;

  IF v_booking IS NULL THEN
    RETURN NULL;
  END IF;

  -- Verify it's still pending and belongs to this sitter
  IF v_booking.status != 'pending' OR v_booking.sitter_id != p_sitter_id THEN
    RETURN NULL;
  END IF;

  -- Check for overlapping confirmed/in_progress/meet_greet_scheduled bookings
  SELECT EXISTS (
    SELECT 1 FROM bookings
    WHERE sitter_id = p_sitter_id
      AND id != p_booking_id
      AND status IN ('confirmed', 'in_progress', 'meet_greet_scheduled')
      AND start_date <= v_booking.end_date
      AND end_date >= v_booking.start_date
  ) INTO v_has_conflict;

  IF v_has_conflict THEN
    RETURN NULL;
  END IF;

  -- No conflict — confirm the booking
  UPDATE bookings
  SET status = 'confirmed'
  WHERE id = p_booking_id
    AND status = 'pending';

  RETURN p_booking_id;
END;
$$;

-- Index to speed up overlap queries
CREATE INDEX IF NOT EXISTS idx_bookings_sitter_dates 
  ON bookings (sitter_id, start_date, end_date) 
  WHERE status IN ('confirmed', 'in_progress', 'meet_greet_scheduled');
