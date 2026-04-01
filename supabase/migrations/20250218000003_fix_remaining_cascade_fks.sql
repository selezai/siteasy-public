-- Fix remaining FK constraints missing ON DELETE CASCADE that block account deletion

-- ============================================
-- BOOKINGS: waiver_signed_by (nullable, added in meet_greet_requirements)
-- ============================================
ALTER TABLE bookings DROP CONSTRAINT IF EXISTS bookings_waiver_signed_by_fkey;
ALTER TABLE bookings ADD CONSTRAINT bookings_waiver_signed_by_fkey
  FOREIGN KEY (waiver_signed_by) REFERENCES profiles(id) ON DELETE SET NULL;

-- ============================================
-- BOOKINGS: no_show_reported_by (nullable, added in booking_completion)
-- ============================================
ALTER TABLE bookings DROP CONSTRAINT IF EXISTS bookings_no_show_reported_by_fkey;
ALTER TABLE bookings ADD CONSTRAINT bookings_no_show_reported_by_fkey
  FOREIGN KEY (no_show_reported_by) REFERENCES profiles(id) ON DELETE SET NULL;

-- ============================================
-- WAIVERS: signed_by (added in meet_greet_requirements)
-- ============================================
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'waivers') THEN
    ALTER TABLE waivers DROP CONSTRAINT IF EXISTS waivers_signed_by_fkey;
    ALTER TABLE waivers ADD CONSTRAINT waivers_signed_by_fkey
      FOREIGN KEY (signed_by) REFERENCES profiles(id) ON DELETE CASCADE;
  END IF;
END $$;
