-- Create storage bucket for check-in photos
INSERT INTO storage.buckets (id, name, public)
VALUES ('check-in-photos', 'check-in-photos', true)
ON CONFLICT (id) DO NOTHING;

-- Allow authenticated users to upload to check-in-photos bucket
CREATE POLICY "Authenticated users can upload check-in photos"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'check-in-photos');

-- Allow public read access to check-in photos
CREATE POLICY "Public can view check-in photos"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'check-in-photos');

-- Allow users to delete their own check-in photos
CREATE POLICY "Users can delete own check-in photos"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'check-in-photos' AND auth.uid()::text = (storage.foldername(name))[1]);
