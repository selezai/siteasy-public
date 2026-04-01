-- Fix storage policies to allow uploads without folder structure
-- The current policies check for user ID in folder path, but uploads use flat filenames

-- Drop existing avatar policies
DROP POLICY IF EXISTS "Avatar images are publicly accessible" ON storage.objects;
DROP POLICY IF EXISTS "Users can upload their own avatar" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own avatar" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own avatar" ON storage.objects;

-- Recreate avatar policies with simpler checks
-- Public read access for avatars
CREATE POLICY "Avatar images are publicly accessible"
ON storage.objects FOR SELECT
USING (bucket_id = 'avatars');

-- Allow authenticated users to upload to avatars bucket
-- Filename must start with their user ID
CREATE POLICY "Users can upload their own avatar"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'avatars' 
  AND auth.role() = 'authenticated'
  AND (storage.filename(name) LIKE auth.uid()::text || '%' OR name LIKE auth.uid()::text || '%')
);

-- Allow users to update files that start with their user ID
CREATE POLICY "Users can update their own avatar"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'avatars' 
  AND auth.role() = 'authenticated'
  AND (storage.filename(name) LIKE auth.uid()::text || '%' OR name LIKE auth.uid()::text || '%')
);

-- Allow users to delete files that start with their user ID
CREATE POLICY "Users can delete their own avatar"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'avatars' 
  AND auth.role() = 'authenticated'
  AND (storage.filename(name) LIKE auth.uid()::text || '%' OR name LIKE auth.uid()::text || '%')
);

-- Fix documents bucket policies similarly
DROP POLICY IF EXISTS "Users can view their own documents" ON storage.objects;
DROP POLICY IF EXISTS "Users can upload their own documents" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own documents" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own documents" ON storage.objects;

CREATE POLICY "Users can view their own documents"
ON storage.objects FOR SELECT
USING (
  bucket_id = 'documents' 
  AND auth.role() = 'authenticated'
  AND (storage.filename(name) LIKE auth.uid()::text || '%' OR name LIKE auth.uid()::text || '%')
);

CREATE POLICY "Users can upload their own documents"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'documents' 
  AND auth.role() = 'authenticated'
  AND (storage.filename(name) LIKE auth.uid()::text || '%' OR name LIKE auth.uid()::text || '%')
);

CREATE POLICY "Users can update their own documents"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'documents' 
  AND auth.role() = 'authenticated'
  AND (storage.filename(name) LIKE auth.uid()::text || '%' OR name LIKE auth.uid()::text || '%')
);

CREATE POLICY "Users can delete their own documents"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'documents' 
  AND auth.role() = 'authenticated'
  AND (storage.filename(name) LIKE auth.uid()::text || '%' OR name LIKE auth.uid()::text || '%')
);
