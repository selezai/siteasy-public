-- Add sitter response column to reviews table
ALTER TABLE reviews ADD COLUMN IF NOT EXISTS sitter_response TEXT;
ALTER TABLE reviews ADD COLUMN IF NOT EXISTS sitter_response_at TIMESTAMPTZ;

-- Allow reviewees to update their own reviews (for adding a response).
DROP POLICY IF EXISTS "Reviewees can respond to reviews" ON reviews;
CREATE POLICY "Reviewees can respond to reviews"
  ON reviews FOR UPDATE
  USING (auth.uid() = reviewee_id)
  WITH CHECK (auth.uid() = reviewee_id);

-- Defense-in-depth: prevent modification of protected columns via a trigger.
-- Even though the API route only updates sitter_response/sitter_response_at,
-- this blocks any direct Supabase client attempts to tamper with rating, comment, etc.
CREATE OR REPLACE FUNCTION protect_review_columns()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.rating IS DISTINCT FROM OLD.rating THEN
    RAISE EXCEPTION 'Cannot modify rating';
  END IF;
  IF NEW.comment IS DISTINCT FROM OLD.comment THEN
    RAISE EXCEPTION 'Cannot modify comment';
  END IF;
  IF NEW.reviewer_id IS DISTINCT FROM OLD.reviewer_id THEN
    RAISE EXCEPTION 'Cannot modify reviewer_id';
  END IF;
  IF NEW.reviewee_id IS DISTINCT FROM OLD.reviewee_id THEN
    RAISE EXCEPTION 'Cannot modify reviewee_id';
  END IF;
  IF NEW.booking_id IS DISTINCT FROM OLD.booking_id THEN
    RAISE EXCEPTION 'Cannot modify booking_id';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS protect_review_columns_trigger ON reviews;
CREATE TRIGGER protect_review_columns_trigger
  BEFORE UPDATE ON reviews
  FOR EACH ROW
  EXECUTE FUNCTION protect_review_columns();
