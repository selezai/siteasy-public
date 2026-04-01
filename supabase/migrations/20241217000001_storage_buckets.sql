-- Create storage buckets for SitEasy

-- Avatars bucket (public)
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

-- Documents bucket (private - for ID docs and clearance certificates)
INSERT INTO storage.buckets (id, name, public)
VALUES ('documents', 'documents', false)
ON CONFLICT (id) DO NOTHING;

-- Agency logos bucket (public)
INSERT INTO storage.buckets (id, name, public)
VALUES ('agency-logos', 'agency-logos', true)
ON CONFLICT (id) DO NOTHING;

-- Storage policies for avatars bucket
CREATE POLICY "Avatar images are publicly accessible"
ON storage.objects FOR SELECT
USING (bucket_id = 'avatars');

CREATE POLICY "Users can upload their own avatar"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'avatars' 
  AND auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Users can update their own avatar"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'avatars' 
  AND auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Users can delete their own avatar"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'avatars' 
  AND auth.uid()::text = (storage.foldername(name))[1]
);

-- Storage policies for documents bucket
CREATE POLICY "Users can view their own documents"
ON storage.objects FOR SELECT
USING (
  bucket_id = 'documents' 
  AND auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Users can upload their own documents"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'documents' 
  AND auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Users can update their own documents"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'documents' 
  AND auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Users can delete their own documents"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'documents' 
  AND auth.uid()::text = (storage.foldername(name))[1]
);

-- Storage policies for agency-logos bucket
CREATE POLICY "Agency logos are publicly accessible"
ON storage.objects FOR SELECT
USING (bucket_id = 'agency-logos');

CREATE POLICY "Agency admins can upload logos"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'agency-logos' 
  AND auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Agency admins can update logos"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'agency-logos' 
  AND auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Agency admins can delete logos"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'agency-logos' 
  AND auth.uid()::text = (storage.foldername(name))[1]
);
