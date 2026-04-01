-- Upload security: Add per-bucket file size limits and MIME type restrictions
-- Client-side validation exists but can be bypassed; these are server-side enforced

-- 1. Avatars bucket: max 5MB, images only
UPDATE storage.buckets SET
  file_size_limit = 5242880,  -- 5MB in bytes
  allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp']
WHERE id = 'avatars';

-- 2. Documents bucket: max 10MB, PDFs and images only
UPDATE storage.buckets SET
  file_size_limit = 10485760,  -- 10MB in bytes
  allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'application/pdf']
WHERE id = 'documents';

-- 3. Agency logos bucket: max 5MB, images only
UPDATE storage.buckets SET
  file_size_limit = 5242880,  -- 5MB in bytes
  allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/svg+xml']
WHERE id = 'agency-logos';

-- 4. Create videos bucket if not exists (for sitter video intros)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'videos', 'videos', true,
  52428800,  -- 50MB in bytes
  ARRAY['video/mp4', 'video/quicktime', 'video/webm']
)
ON CONFLICT (id) DO UPDATE SET
  file_size_limit = 52428800,
  allowed_mime_types = ARRAY['video/mp4', 'video/quicktime', 'video/webm'];

-- 5. Create check-in-photos bucket if not exists
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'check-in-photos', 'check-in-photos', true,
  10485760,  -- 10MB in bytes
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif']
)
ON CONFLICT (id) DO UPDATE SET
  file_size_limit = 10485760,
  allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif'];

-- 6. Add RLS policies for videos bucket (if missing)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'objects' AND policyname = 'Video intros are publicly accessible'
  ) THEN
    CREATE POLICY "Video intros are publicly accessible"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'videos');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'objects' AND policyname = 'Sitters can upload their own videos'
  ) THEN
    CREATE POLICY "Sitters can upload their own videos"
    ON storage.objects FOR INSERT
    WITH CHECK (
      bucket_id = 'videos'
      AND (select auth.uid())::text = (storage.foldername(name))[1]
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'objects' AND policyname = 'Sitters can delete their own videos'
  ) THEN
    CREATE POLICY "Sitters can delete their own videos"
    ON storage.objects FOR DELETE
    USING (
      bucket_id = 'videos'
      AND (select auth.uid())::text = (storage.foldername(name))[1]
    );
  END IF;
END $$;

-- 7. Add RLS policies for check-in-photos bucket (if missing)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'objects' AND policyname = 'Check-in photos are publicly accessible'
  ) THEN
    CREATE POLICY "Check-in photos are publicly accessible"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'check-in-photos');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'objects' AND policyname = 'Sitters can upload check-in photos'
  ) THEN
    CREATE POLICY "Sitters can upload check-in photos"
    ON storage.objects FOR INSERT
    WITH CHECK (
      bucket_id = 'check-in-photos'
      AND (select auth.uid()) IS NOT NULL
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'objects' AND policyname = 'Sitters can delete their check-in photos'
  ) THEN
    CREATE POLICY "Sitters can delete their check-in photos"
    ON storage.objects FOR DELETE
    USING (
      bucket_id = 'check-in-photos'
      AND (select auth.uid()) IS NOT NULL
    );
  END IF;
END $$;
