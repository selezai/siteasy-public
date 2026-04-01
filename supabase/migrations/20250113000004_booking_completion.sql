-- Add booking completion tracking fields
ALTER TABLE bookings
ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS completion_confirmed_by_client BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS completion_confirmed_by_sitter BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS no_show_reported_by UUID REFERENCES profiles(id),
ADD COLUMN IF NOT EXISTS no_show_reported_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS no_show_party TEXT; -- 'client' or 'sitter'

COMMENT ON COLUMN bookings.completed_at IS 'Timestamp when booking was marked as completed';
COMMENT ON COLUMN bookings.completion_confirmed_by_client IS 'Whether client confirmed the booking happened';
COMMENT ON COLUMN bookings.completion_confirmed_by_sitter IS 'Whether sitter confirmed the booking happened';
COMMENT ON COLUMN bookings.no_show_reported_by IS 'User who reported a no-show';
COMMENT ON COLUMN bookings.no_show_reported_at IS 'Timestamp when no-show was reported';
COMMENT ON COLUMN bookings.no_show_party IS 'Which party did not show up: client or sitter';
