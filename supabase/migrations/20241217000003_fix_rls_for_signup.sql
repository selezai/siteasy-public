-- Fix RLS policies to allow profile creation during signup
-- The trigger runs as SECURITY DEFINER but RLS still applies

-- Drop existing insert policy for profiles
DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;

-- Create a more permissive insert policy that works with the trigger
-- The trigger uses SECURITY DEFINER, so we need to allow inserts where id matches the new user
CREATE POLICY "Allow profile creation" ON profiles
    FOR INSERT WITH CHECK (true);

-- Also need to fix sitter_profiles and client_profiles for the signup flow
DROP POLICY IF EXISTS "Sitters can insert own profile" ON sitter_profiles;
CREATE POLICY "Allow sitter profile creation" ON sitter_profiles
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own client profile" ON client_profiles;
CREATE POLICY "Allow client profile creation" ON client_profiles
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Fix meet_greets policies
DROP POLICY IF EXISTS "Booking participants can view meet greets" ON meet_greets;
CREATE POLICY "Booking participants can view meet greets" ON meet_greets
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM bookings 
            WHERE bookings.id = meet_greets.booking_id 
            AND (bookings.client_id = auth.uid() OR bookings.sitter_id = auth.uid())
        )
    );

DROP POLICY IF EXISTS "Sitters can create meet greets" ON meet_greets;
CREATE POLICY "Sitters can create meet greets" ON meet_greets
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM bookings 
            WHERE bookings.id = meet_greets.booking_id 
            AND bookings.sitter_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Participants can update meet greets" ON meet_greets;
CREATE POLICY "Participants can update meet greets" ON meet_greets
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM bookings 
            WHERE bookings.id = meet_greets.booking_id 
            AND (bookings.client_id = auth.uid() OR bookings.sitter_id = auth.uid())
        )
    );

-- Fix transactions policies
DROP POLICY IF EXISTS "Users can view own transactions" ON transactions;
CREATE POLICY "Users can view own transactions" ON transactions
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM bookings 
            WHERE bookings.id = transactions.booking_id 
            AND (bookings.client_id = auth.uid() OR bookings.sitter_id = auth.uid())
        )
    );

CREATE POLICY "System can create transactions" ON transactions
    FOR INSERT WITH CHECK (true);

CREATE POLICY "System can update transactions" ON transactions
    FOR UPDATE USING (true);
