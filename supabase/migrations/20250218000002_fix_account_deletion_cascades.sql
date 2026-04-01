-- Fix foreign key constraints that block account deletion
-- These FKs reference profiles(id) but are missing ON DELETE CASCADE

-- ============================================
-- BOOKINGS: client_id and sitter_id
-- ============================================
ALTER TABLE bookings DROP CONSTRAINT IF EXISTS bookings_client_id_fkey;
ALTER TABLE bookings ADD CONSTRAINT bookings_client_id_fkey
  FOREIGN KEY (client_id) REFERENCES profiles(id) ON DELETE CASCADE;

ALTER TABLE bookings DROP CONSTRAINT IF EXISTS bookings_sitter_id_fkey;
ALTER TABLE bookings ADD CONSTRAINT bookings_sitter_id_fkey
  FOREIGN KEY (sitter_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- ============================================
-- MESSAGES: sender_id
-- ============================================
ALTER TABLE messages DROP CONSTRAINT IF EXISTS messages_sender_id_fkey;
ALTER TABLE messages ADD CONSTRAINT messages_sender_id_fkey
  FOREIGN KEY (sender_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- ============================================
-- REVIEWS: reviewer_id and reviewee_id
-- ============================================
ALTER TABLE reviews DROP CONSTRAINT IF EXISTS reviews_reviewer_id_fkey;
ALTER TABLE reviews ADD CONSTRAINT reviews_reviewer_id_fkey
  FOREIGN KEY (reviewer_id) REFERENCES profiles(id) ON DELETE CASCADE;

ALTER TABLE reviews DROP CONSTRAINT IF EXISTS reviews_reviewee_id_fkey;
ALTER TABLE reviews ADD CONSTRAINT reviews_reviewee_id_fkey
  FOREIGN KEY (reviewee_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- ============================================
-- CHECK_INS: sitter_id
-- ============================================
ALTER TABLE check_ins DROP CONSTRAINT IF EXISTS check_ins_sitter_id_fkey;
ALTER TABLE check_ins ADD CONSTRAINT check_ins_sitter_id_fkey
  FOREIGN KEY (sitter_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- ============================================
-- SAFETY_WAIVERS: sitter_id
-- ============================================
ALTER TABLE safety_waivers DROP CONSTRAINT IF EXISTS safety_waivers_sitter_id_fkey;
ALTER TABLE safety_waivers ADD CONSTRAINT safety_waivers_sitter_id_fkey
  FOREIGN KEY (sitter_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- ============================================
-- INCIDENT_REPORTS: reporter_id and reported_user_id
-- ============================================
ALTER TABLE incident_reports DROP CONSTRAINT IF EXISTS incident_reports_reporter_id_fkey;
ALTER TABLE incident_reports ADD CONSTRAINT incident_reports_reporter_id_fkey
  FOREIGN KEY (reporter_id) REFERENCES profiles(id) ON DELETE CASCADE;

ALTER TABLE incident_reports DROP CONSTRAINT IF EXISTS incident_reports_reported_user_id_fkey;
ALTER TABLE incident_reports ADD CONSTRAINT incident_reports_reported_user_id_fkey
  FOREIGN KEY (reported_user_id) REFERENCES profiles(id) ON DELETE CASCADE;

