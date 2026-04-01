-- Fix RLS Performance Warnings
-- 1. auth_rls_initplan: Wrap auth.uid() in (select ...) to prevent per-row re-evaluation
-- 2. multiple_permissive_policies: Consolidate duplicate SELECT policies

-- ============================================
-- PROFILES
-- ============================================

DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile" ON public.profiles
    FOR UPDATE USING ((select auth.uid()) = id);

DROP POLICY IF EXISTS "Users can delete own profile" ON public.profiles;
CREATE POLICY "Users can delete own profile" ON public.profiles
    FOR DELETE USING ((select auth.uid()) = id);

-- ============================================
-- SITTER_PROFILES
-- ============================================

DROP POLICY IF EXISTS "Sitters can update own profile" ON public.sitter_profiles;
CREATE POLICY "Sitters can update own profile" ON public.sitter_profiles
    FOR UPDATE USING ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Allow sitter profile creation" ON public.sitter_profiles;
CREATE POLICY "Allow sitter profile creation" ON public.sitter_profiles
    FOR INSERT WITH CHECK ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can delete own sitter profile" ON public.sitter_profiles;
CREATE POLICY "Users can delete own sitter profile" ON public.sitter_profiles
    FOR DELETE USING ((select auth.uid()) = user_id);

-- Note: "Active sitter profiles are viewable" uses is_active = true, not auth.uid()
-- so it doesn't need fixing

-- ============================================
-- CLIENT_PROFILES - Consolidate SELECT policies
-- ============================================

DROP POLICY IF EXISTS "Users can view own client profile" ON public.client_profiles;
DROP POLICY IF EXISTS "Sitters can view client profiles for bookings" ON public.client_profiles;

-- Single consolidated SELECT policy
DROP POLICY IF EXISTS "Users can view client profiles" ON public.client_profiles;
CREATE POLICY "Users can view client profiles" ON public.client_profiles
    FOR SELECT USING (
        (select auth.uid()) = user_id
        OR EXISTS (
            SELECT 1 FROM public.bookings 
            WHERE bookings.client_id = client_profiles.user_id 
            AND bookings.sitter_id = (select auth.uid())
        )
    );

DROP POLICY IF EXISTS "Users can update own client profile" ON public.client_profiles;
CREATE POLICY "Users can update own client profile" ON public.client_profiles
    FOR UPDATE USING ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can delete own client profile" ON public.client_profiles;
CREATE POLICY "Users can delete own client profile" ON public.client_profiles
    FOR DELETE USING ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Allow client profile creation" ON public.client_profiles;
CREATE POLICY "Allow client profile creation" ON public.client_profiles
    FOR INSERT WITH CHECK ((select auth.uid()) = user_id);

-- ============================================
-- PETS - Consolidate SELECT policies
-- ============================================

DROP POLICY IF EXISTS "Users can manage own pets" ON public.pets;
DROP POLICY IF EXISTS "Sitters can view pets for bookings" ON public.pets;

-- Single consolidated SELECT policy
DROP POLICY IF EXISTS "Users can view pets" ON public.pets;
CREATE POLICY "Users can view pets" ON public.pets
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.client_profiles 
            WHERE client_profiles.id = pets.client_id 
            AND client_profiles.user_id = (select auth.uid())
        )
        OR EXISTS (
            SELECT 1 FROM public.bookings b
            JOIN public.client_profiles cp ON cp.user_id = b.client_id
            WHERE cp.id = pets.client_id 
            AND b.sitter_id = (select auth.uid())
        )
    );

-- Separate policies for INSERT, UPDATE, DELETE (owners only)
DROP POLICY IF EXISTS "Users can insert own pets" ON public.pets;
CREATE POLICY "Users can insert own pets" ON public.pets
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.client_profiles 
            WHERE client_profiles.id = pets.client_id 
            AND client_profiles.user_id = (select auth.uid())
        )
    );

DROP POLICY IF EXISTS "Users can update own pets" ON public.pets;
CREATE POLICY "Users can update own pets" ON public.pets
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.client_profiles 
            WHERE client_profiles.id = pets.client_id 
            AND client_profiles.user_id = (select auth.uid())
        )
    );

DROP POLICY IF EXISTS "Users can delete own pets" ON public.pets;
CREATE POLICY "Users can delete own pets" ON public.pets
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM public.client_profiles 
            WHERE client_profiles.id = pets.client_id 
            AND client_profiles.user_id = (select auth.uid())
        )
    );

-- ============================================
-- BOOKINGS
-- ============================================

DROP POLICY IF EXISTS "Users can view own bookings" ON public.bookings;
CREATE POLICY "Users can view own bookings" ON public.bookings
    FOR SELECT USING ((select auth.uid()) = client_id OR (select auth.uid()) = sitter_id);

DROP POLICY IF EXISTS "Clients can create bookings" ON public.bookings;
CREATE POLICY "Clients can create bookings" ON public.bookings
    FOR INSERT WITH CHECK ((select auth.uid()) = client_id);

DROP POLICY IF EXISTS "Participants can update bookings" ON public.bookings;
CREATE POLICY "Participants can update bookings" ON public.bookings
    FOR UPDATE USING ((select auth.uid()) = client_id OR (select auth.uid()) = sitter_id);

-- ============================================
-- REVIEWS
-- ============================================

DROP POLICY IF EXISTS "Booking participants can create reviews" ON public.reviews;
CREATE POLICY "Booking participants can create reviews" ON public.reviews
    FOR INSERT WITH CHECK (
        (select auth.uid()) = reviewer_id AND
        EXISTS (
            SELECT 1 FROM public.bookings 
            WHERE bookings.id = reviews.booking_id 
            AND (bookings.client_id = (select auth.uid()) OR bookings.sitter_id = (select auth.uid()))
            AND bookings.status = 'completed'
        )
    );

-- ============================================
-- SITTER_CLIENT_NOTES
-- ============================================

DROP POLICY IF EXISTS "Sitters can manage own notes" ON public.sitter_client_notes;
CREATE POLICY "Sitters can manage own notes" ON public.sitter_client_notes
    FOR ALL USING ((select auth.uid()) = sitter_id);

-- ============================================
-- MEET_GREETS
-- ============================================

DROP POLICY IF EXISTS "Booking participants can view meet greets" ON public.meet_greets;
CREATE POLICY "Booking participants can view meet greets" ON public.meet_greets
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.bookings 
            WHERE bookings.id = meet_greets.booking_id 
            AND (bookings.client_id = (select auth.uid()) OR bookings.sitter_id = (select auth.uid()))
        )
    );

DROP POLICY IF EXISTS "Sitters can create meet greets" ON public.meet_greets;
CREATE POLICY "Sitters can create meet greets" ON public.meet_greets
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.bookings 
            WHERE bookings.id = meet_greets.booking_id 
            AND bookings.sitter_id = (select auth.uid())
        )
    );

DROP POLICY IF EXISTS "Participants can update meet greets" ON public.meet_greets;
CREATE POLICY "Participants can update meet greets" ON public.meet_greets
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.bookings 
            WHERE bookings.id = meet_greets.booking_id 
            AND (bookings.client_id = (select auth.uid()) OR bookings.sitter_id = (select auth.uid()))
        )
    );

-- ============================================
-- TRANSACTIONS
-- ============================================

DROP POLICY IF EXISTS "Users can view own transactions" ON public.transactions;
CREATE POLICY "Users can view own transactions" ON public.transactions
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.bookings 
            WHERE bookings.id = transactions.booking_id 
            AND (bookings.client_id = (select auth.uid()) OR bookings.sitter_id = (select auth.uid()))
        )
    );

DROP POLICY IF EXISTS "Booking participants can create transactions" ON public.transactions;
CREATE POLICY "Booking participants can create transactions" ON public.transactions
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.bookings 
            WHERE bookings.id = transactions.booking_id 
            AND (bookings.client_id = (select auth.uid()) OR bookings.sitter_id = (select auth.uid()))
        )
    );

DROP POLICY IF EXISTS "Booking participants can update transactions" ON public.transactions;
CREATE POLICY "Booking participants can update transactions" ON public.transactions
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.bookings 
            WHERE bookings.id = transactions.booking_id 
            AND (bookings.client_id = (select auth.uid()) OR bookings.sitter_id = (select auth.uid()))
        )
    );

-- ============================================
-- WAIVERS
-- ============================================

DROP POLICY IF EXISTS "Users can view own waivers" ON public.waivers;
CREATE POLICY "Users can view own waivers" ON public.waivers
    FOR SELECT USING (
        signed_by = (select auth.uid()) OR
        EXISTS (
            SELECT 1 FROM public.bookings 
            WHERE bookings.id = waivers.booking_id 
            AND (bookings.client_id = (select auth.uid()) OR bookings.sitter_id = (select auth.uid()))
        )
    );

DROP POLICY IF EXISTS "Users can sign waivers for their bookings" ON public.waivers;
CREATE POLICY "Users can sign waivers for their bookings" ON public.waivers
    FOR INSERT WITH CHECK (
        signed_by = (select auth.uid()) AND
        EXISTS (
            SELECT 1 FROM public.bookings 
            WHERE bookings.id = waivers.booking_id 
            AND (bookings.client_id = (select auth.uid()) OR bookings.sitter_id = (select auth.uid()))
        )
    );

-- ============================================
-- NOTIFICATIONS
-- ============================================

DROP POLICY IF EXISTS "Users can view own notifications" ON public.notifications;
CREATE POLICY "Users can view own notifications" ON public.notifications
    FOR SELECT USING (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can update own notifications" ON public.notifications;
CREATE POLICY "Users can update own notifications" ON public.notifications
    FOR UPDATE USING (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Authenticated users can create notifications" ON public.notifications;
CREATE POLICY "Authenticated users can create notifications" ON public.notifications
    FOR INSERT WITH CHECK ((select auth.uid()) IS NOT NULL);

DROP POLICY IF EXISTS "Users can delete own notifications" ON public.notifications;
CREATE POLICY "Users can delete own notifications" ON public.notifications
    FOR DELETE USING (user_id = (select auth.uid()));

-- ============================================
-- CHECK_INS - Consolidate SELECT policies
-- ============================================

DROP POLICY IF EXISTS "Sitters can view check-ins for their bookings" ON public.check_ins;
DROP POLICY IF EXISTS "Clients can view check-ins for their bookings" ON public.check_ins;

-- Single consolidated SELECT policy
DROP POLICY IF EXISTS "Booking parties can view check-ins" ON public.check_ins;
CREATE POLICY "Booking parties can view check-ins" ON public.check_ins
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.bookings 
            WHERE bookings.id = check_ins.booking_id 
            AND (bookings.client_id = (select auth.uid()) OR bookings.sitter_id = (select auth.uid()))
        )
    );

DROP POLICY IF EXISTS "Sitters can create check-ins" ON public.check_ins;
CREATE POLICY "Sitters can create check-ins" ON public.check_ins
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.bookings 
            WHERE bookings.id = check_ins.booking_id 
            AND bookings.sitter_id = (select auth.uid())
        )
    );

-- ============================================
-- CHECK_IN_ACTIVITIES - Consolidate SELECT policies
-- ============================================

DROP POLICY IF EXISTS "Sitters can manage check-in activities" ON public.check_in_activities;
DROP POLICY IF EXISTS "Clients can view check-in activities" ON public.check_in_activities;

-- Single consolidated SELECT policy
DROP POLICY IF EXISTS "Booking parties can view check-in activities" ON public.check_in_activities;
CREATE POLICY "Booking parties can view check-in activities" ON public.check_in_activities
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.check_ins ci
            JOIN public.bookings b ON b.id = ci.booking_id
            WHERE ci.id = check_in_activities.check_in_id
            AND (b.client_id = (select auth.uid()) OR b.sitter_id = (select auth.uid()))
        )
    );

-- Sitters can manage (insert, update, delete)
DROP POLICY IF EXISTS "Sitters can insert check-in activities" ON public.check_in_activities;
CREATE POLICY "Sitters can insert check-in activities" ON public.check_in_activities
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.check_ins ci
            JOIN public.bookings b ON b.id = ci.booking_id
            WHERE ci.id = check_in_activities.check_in_id
            AND b.sitter_id = (select auth.uid())
        )
    );

DROP POLICY IF EXISTS "Sitters can update check-in activities" ON public.check_in_activities;
CREATE POLICY "Sitters can update check-in activities" ON public.check_in_activities
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.check_ins ci
            JOIN public.bookings b ON b.id = ci.booking_id
            WHERE ci.id = check_in_activities.check_in_id
            AND b.sitter_id = (select auth.uid())
        )
    );

DROP POLICY IF EXISTS "Sitters can delete check-in activities" ON public.check_in_activities;
CREATE POLICY "Sitters can delete check-in activities" ON public.check_in_activities
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM public.check_ins ci
            JOIN public.bookings b ON b.id = ci.booking_id
            WHERE ci.id = check_in_activities.check_in_id
            AND b.sitter_id = (select auth.uid())
        )
    );

-- ============================================
-- CHECK_IN_PHOTOS - Consolidate SELECT policies
-- ============================================

DROP POLICY IF EXISTS "Sitters can manage check-in photos" ON public.check_in_photos;
DROP POLICY IF EXISTS "Clients can view check-in photos" ON public.check_in_photos;

-- Single consolidated SELECT policy
DROP POLICY IF EXISTS "Booking parties can view check-in photos" ON public.check_in_photos;
CREATE POLICY "Booking parties can view check-in photos" ON public.check_in_photos
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.check_ins ci
            JOIN public.bookings b ON b.id = ci.booking_id
            WHERE ci.id = check_in_photos.check_in_id
            AND (b.client_id = (select auth.uid()) OR b.sitter_id = (select auth.uid()))
        )
    );

-- Sitters can manage (insert, update, delete)
DROP POLICY IF EXISTS "Sitters can insert check-in photos" ON public.check_in_photos;
CREATE POLICY "Sitters can insert check-in photos" ON public.check_in_photos
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.check_ins ci
            JOIN public.bookings b ON b.id = ci.booking_id
            WHERE ci.id = check_in_photos.check_in_id
            AND b.sitter_id = (select auth.uid())
        )
    );

DROP POLICY IF EXISTS "Sitters can update check-in photos" ON public.check_in_photos;
CREATE POLICY "Sitters can update check-in photos" ON public.check_in_photos
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.check_ins ci
            JOIN public.bookings b ON b.id = ci.booking_id
            WHERE ci.id = check_in_photos.check_in_id
            AND b.sitter_id = (select auth.uid())
        )
    );

DROP POLICY IF EXISTS "Sitters can delete check-in photos" ON public.check_in_photos;
CREATE POLICY "Sitters can delete check-in photos" ON public.check_in_photos
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM public.check_ins ci
            JOIN public.bookings b ON b.id = ci.booking_id
            WHERE ci.id = check_in_photos.check_in_id
            AND b.sitter_id = (select auth.uid())
        )
    );

-- ============================================
-- BOOKING_CHECK_IN_STATUS - Consolidate SELECT policies
-- ============================================

DROP POLICY IF EXISTS "Booking parties can view check-in status" ON public.booking_check_in_status;
DROP POLICY IF EXISTS "Sitters can manage check-in status" ON public.booking_check_in_status;

-- Single consolidated SELECT policy
DROP POLICY IF EXISTS "Booking parties can view check-in status" ON public.booking_check_in_status;
CREATE POLICY "Booking parties can view check-in status" ON public.booking_check_in_status
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.bookings 
            WHERE bookings.id = booking_check_in_status.booking_id 
            AND (bookings.client_id = (select auth.uid()) OR bookings.sitter_id = (select auth.uid()))
        )
    );

-- Sitters can manage (insert, update)
DROP POLICY IF EXISTS "Sitters can insert check-in status" ON public.booking_check_in_status;
CREATE POLICY "Sitters can insert check-in status" ON public.booking_check_in_status
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.bookings 
            WHERE bookings.id = booking_check_in_status.booking_id 
            AND bookings.sitter_id = (select auth.uid())
        )
    );

DROP POLICY IF EXISTS "Sitters can update check-in status" ON public.booking_check_in_status;
CREATE POLICY "Sitters can update check-in status" ON public.booking_check_in_status
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.bookings 
            WHERE bookings.id = booking_check_in_status.booking_id 
            AND bookings.sitter_id = (select auth.uid())
        )
    );

-- ============================================
-- PAYMENT_TRANSACTIONS
-- ============================================

DROP POLICY IF EXISTS "Booking parties can view payment transactions" ON public.payment_transactions;
CREATE POLICY "Booking parties can view payment transactions" ON public.payment_transactions
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.bookings 
            WHERE bookings.id = payment_transactions.booking_id 
            AND (bookings.client_id = (select auth.uid()) OR bookings.sitter_id = (select auth.uid()))
        )
    );

DROP POLICY IF EXISTS "Clients can insert payment transactions for their bookings" ON public.payment_transactions;
CREATE POLICY "Clients can insert payment transactions for their bookings" ON public.payment_transactions
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.bookings 
            WHERE bookings.id = payment_transactions.booking_id 
            AND bookings.client_id = (select auth.uid())
        )
    );

-- ============================================
-- PAYOUT_RELEASES
-- ============================================

DROP POLICY IF EXISTS "Booking parties can view escrow releases" ON public.payout_releases;
DROP POLICY IF EXISTS "Booking parties can view escrow releases" ON public.payout_releases;
CREATE POLICY "Booking parties can view escrow releases" ON public.payout_releases
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.bookings 
            WHERE bookings.id = payout_releases.booking_id 
            AND (bookings.client_id = (select auth.uid()) OR bookings.sitter_id = (select auth.uid()))
        )
    );

DROP POLICY IF EXISTS "System can insert escrow releases" ON public.payout_releases;
-- System inserts are done via service role which bypasses RLS
-- If needed for authenticated users, uncomment below:
-- CREATE POLICY "System can insert escrow releases" ON public.payout_releases
--     FOR INSERT WITH CHECK ((select auth.uid()) IS NOT NULL);

-- ============================================
-- CONVERSATIONS
-- ============================================

DROP POLICY IF EXISTS "Users can view their own conversations" ON public.conversations;
CREATE POLICY "Users can view their own conversations" ON public.conversations
    FOR SELECT USING ((select auth.uid()) = client_id OR (select auth.uid()) = sitter_id);

DROP POLICY IF EXISTS "Users can create conversations they're part of" ON public.conversations;
CREATE POLICY "Users can create conversations they're part of" ON public.conversations
    FOR INSERT WITH CHECK ((select auth.uid()) = client_id OR (select auth.uid()) = sitter_id);

DROP POLICY IF EXISTS "Users can update their own conversations" ON public.conversations;
CREATE POLICY "Users can update their own conversations" ON public.conversations
    FOR UPDATE USING ((select auth.uid()) = client_id OR (select auth.uid()) = sitter_id);

-- ============================================
-- MESSAGES
-- ============================================

DROP POLICY IF EXISTS "Users can view messages in their conversations" ON public.messages;
CREATE POLICY "Users can view messages in their conversations" ON public.messages
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.conversations c
            WHERE c.id = messages.conversation_id
            AND (c.client_id = (select auth.uid()) OR c.sitter_id = (select auth.uid()))
        )
        OR EXISTS (
            SELECT 1 FROM public.bookings b
            WHERE b.id = messages.booking_id
            AND (b.client_id = (select auth.uid()) OR b.sitter_id = (select auth.uid()))
        )
    );

DROP POLICY IF EXISTS "Users can send messages in their conversations" ON public.messages;
CREATE POLICY "Users can send messages in their conversations" ON public.messages
    FOR INSERT WITH CHECK (
        (select auth.uid()) = sender_id
        AND (
            EXISTS (
                SELECT 1 FROM public.conversations c
                WHERE c.id = conversation_id
                AND (c.client_id = (select auth.uid()) OR c.sitter_id = (select auth.uid()))
            )
            OR EXISTS (
                SELECT 1 FROM public.bookings b
                WHERE b.id = booking_id
                AND (b.client_id = (select auth.uid()) OR b.sitter_id = (select auth.uid()))
            )
        )
    );

DROP POLICY IF EXISTS "Recipients can mark messages as read" ON public.messages;
CREATE POLICY "Recipients can mark messages as read" ON public.messages
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.conversations c
            WHERE c.id = messages.conversation_id
            AND (c.client_id = (select auth.uid()) OR c.sitter_id = (select auth.uid()))
        )
        OR EXISTS (
            SELECT 1 FROM public.bookings b
            WHERE b.id = messages.booking_id
            AND (b.client_id = (select auth.uid()) OR b.sitter_id = (select auth.uid()))
        )
    );

-- ============================================
-- CLIENT_NOTES
-- ============================================

DROP POLICY IF EXISTS "Sitters can view their own notes" ON public.client_notes;
CREATE POLICY "Sitters can view their own notes" ON public.client_notes
    FOR SELECT USING (sitter_id = (select auth.uid()));

DROP POLICY IF EXISTS "Sitters can insert their own notes" ON public.client_notes;
CREATE POLICY "Sitters can insert their own notes" ON public.client_notes
    FOR INSERT WITH CHECK (sitter_id = (select auth.uid()));

DROP POLICY IF EXISTS "Sitters can update their own notes" ON public.client_notes;
CREATE POLICY "Sitters can update their own notes" ON public.client_notes
    FOR UPDATE USING (sitter_id = (select auth.uid()));

DROP POLICY IF EXISTS "Sitters can delete their own notes" ON public.client_notes;
CREATE POLICY "Sitters can delete their own notes" ON public.client_notes
    FOR DELETE USING (sitter_id = (select auth.uid()));
