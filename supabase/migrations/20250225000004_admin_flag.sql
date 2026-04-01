-- Add is_admin flag to profiles table
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT FALSE;

-- Set admin for the platform owner
UPDATE profiles SET is_admin = true
WHERE id = (SELECT id FROM auth.users WHERE email = 'selezmj@gmail.com');

-- Index for quick admin lookups
CREATE INDEX IF NOT EXISTS idx_profiles_is_admin ON profiles (is_admin) WHERE is_admin = true;

-- NOTE: No admin SELECT policy needed on profiles — "Profiles are viewable by everyone"
-- (USING true) already grants read access. Adding a self-referential subquery here
-- (SELECT is_admin FROM profiles) causes infinite RLS recursion → 500 errors.
DROP POLICY IF EXISTS "Admins can read all profiles" ON profiles;

-- RLS policy: allow admins to read all bookings
DROP POLICY IF EXISTS "Admins can read all bookings" ON bookings;
CREATE POLICY "Admins can read all bookings"
  ON bookings FOR SELECT
  TO authenticated
  USING (
    (SELECT is_admin FROM profiles WHERE id = auth.uid()) = true
  );

-- RLS policy: allow admins to read all sitter_profiles
DROP POLICY IF EXISTS "Admins can read all sitter_profiles" ON sitter_profiles;
CREATE POLICY "Admins can read all sitter_profiles"
  ON sitter_profiles FOR SELECT
  TO authenticated
  USING (
    (SELECT is_admin FROM profiles WHERE id = auth.uid()) = true
  );

-- RLS policy: allow admins to read all client_profiles
DROP POLICY IF EXISTS "Admins can read all client_profiles" ON client_profiles;
CREATE POLICY "Admins can read all client_profiles"
  ON client_profiles FOR SELECT
  TO authenticated
  USING (
    (SELECT is_admin FROM profiles WHERE id = auth.uid()) = true
  );

-- RLS policy: allow admins to read all payment_transactions
DROP POLICY IF EXISTS "Admins can read all payment_transactions" ON payment_transactions;
CREATE POLICY "Admins can read all payment_transactions"
  ON payment_transactions FOR SELECT
  TO authenticated
  USING (
    (SELECT is_admin FROM profiles WHERE id = auth.uid()) = true
  );

-- RLS policy: allow admins to read sitter_waitlist
DROP POLICY IF EXISTS "Admins can read sitter_waitlist" ON sitter_waitlist;
CREATE POLICY "Admins can read sitter_waitlist"
  ON sitter_waitlist FOR SELECT
  TO authenticated
  USING (
    (SELECT is_admin FROM profiles WHERE id = auth.uid()) = true
  );

-- RLS policy: allow admins to update sitter_waitlist
DROP POLICY IF EXISTS "Admins can update sitter_waitlist" ON sitter_waitlist;
CREATE POLICY "Admins can update sitter_waitlist"
  ON sitter_waitlist FOR UPDATE
  TO authenticated
  USING (
    (SELECT is_admin FROM profiles WHERE id = auth.uid()) = true
  )
  WITH CHECK (
    (SELECT is_admin FROM profiles WHERE id = auth.uid()) = true
  );

-- RLS policy: allow admins to read all pets (for user management pet counts)
DROP POLICY IF EXISTS "Admins can read all pets" ON pets;
CREATE POLICY "Admins can read all pets"
  ON pets FOR SELECT
  TO authenticated
  USING (
    (SELECT is_admin FROM profiles WHERE id = auth.uid()) = true
  );

-- RLS policy: allow admins to update sitter_profiles (for document verification)
DROP POLICY IF EXISTS "Admins can update sitter_profiles" ON sitter_profiles;
CREATE POLICY "Admins can update sitter_profiles"
  ON sitter_profiles FOR UPDATE
  TO authenticated
  USING (
    (SELECT is_admin FROM profiles WHERE id = auth.uid()) = true
  )
  WITH CHECK (
    (SELECT is_admin FROM profiles WHERE id = auth.uid()) = true
  );
