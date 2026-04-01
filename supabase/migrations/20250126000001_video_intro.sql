-- Add video intro URL to sitter_profiles
ALTER TABLE sitter_profiles ADD COLUMN IF NOT EXISTS video_intro_url TEXT;

-- Create storage bucket for videos if not exists
INSERT INTO storage.buckets (id, name, public)
VALUES ('videos', 'videos', true)
ON CONFLICT (id) DO NOTHING;

-- Storage policies for videos bucket
CREATE POLICY "Users can upload their own videos"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'videos' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "Users can update their own videos"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'videos' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "Users can delete their own videos"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'videos' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "Videos are publicly viewable"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'videos');
