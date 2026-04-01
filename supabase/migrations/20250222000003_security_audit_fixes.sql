-- Security Audit Fix: Tighten check-in photo upload RLS policy
-- Previously any authenticated user could upload to any path in check-in-photos bucket.
-- Now requires user ID as the first folder segment in the path.

-- Drop the overly permissive upload policies
DROP POLICY IF EXISTS "Authenticated users can upload check-in photos" ON storage.objects;
DROP POLICY IF EXISTS "Sitters can upload check-in photos" ON storage.objects;

-- Recreate with user-ID folder enforcement
CREATE POLICY "Sitters can upload check-in photos"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'check-in-photos'
  AND (select auth.uid())::text = (storage.foldername(name))[1]
);
