-- Add completed_bookings_count to sitter_profiles for accurate tier calculation

-- Add the column
ALTER TABLE sitter_profiles 
ADD COLUMN IF NOT EXISTS completed_bookings_count INTEGER DEFAULT 0;

-- Create function to update completed bookings count
CREATE OR REPLACE FUNCTION update_sitter_completed_bookings()
RETURNS TRIGGER AS $$
BEGIN
  -- When a booking status changes to 'completed'
  IF NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status != 'completed') THEN
    UPDATE sitter_profiles 
    SET completed_bookings_count = completed_bookings_count + 1
    WHERE user_id = NEW.sitter_id;
  END IF;
  
  -- If somehow a completed booking is reverted (edge case)
  IF OLD.status = 'completed' AND NEW.status != 'completed' THEN
    UPDATE sitter_profiles 
    SET completed_bookings_count = GREATEST(0, completed_bookings_count - 1)
    WHERE user_id = NEW.sitter_id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for booking status changes
DROP TRIGGER IF EXISTS trigger_update_sitter_completed_bookings ON bookings;
CREATE TRIGGER trigger_update_sitter_completed_bookings
  AFTER UPDATE OF status ON bookings
  FOR EACH ROW
  EXECUTE FUNCTION update_sitter_completed_bookings();

-- Backfill existing completed bookings count
UPDATE sitter_profiles sp
SET completed_bookings_count = (
  SELECT COUNT(*) 
  FROM bookings b 
  WHERE b.sitter_id = sp.user_id 
  AND b.status = 'completed'
);
