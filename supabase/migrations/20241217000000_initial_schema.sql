-- SitEasy Database Schema

-- Enable necessary extensions (use schema-qualified for Supabase)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA extensions;

-- ============================================
-- ENUMS
-- ============================================

CREATE TYPE user_role AS ENUM ('client', 'sitter', 'agency_admin');
CREATE TYPE service_type AS ENUM ('pet_sitting', 'house_sitting');
CREATE TYPE pet_type AS ENUM ('dogs', 'cats', 'birds', 'fish', 'reptiles', 'small_mammals', 'other');
CREATE TYPE home_type AS ENUM ('house', 'apartment', 'complex', 'estate');
CREATE TYPE booking_status AS ENUM ('pending', 'meet_greet_scheduled', 'confirmed', 'in_progress', 'completed', 'cancelled');
CREATE TYPE meet_greet_status AS ENUM ('proposed', 'confirmed', 'completed', 'cancelled');
CREATE TYPE transaction_type AS ENUM ('deposit', 'final_payment', 'payout', 'refund');
CREATE TYPE transaction_status AS ENUM ('pending', 'completed', 'failed');
CREATE TYPE flag_type AS ENUM ('multiple_requests', 'off_platform_contact', 'incomplete_profile', 'cancellation_pattern', 'new_long_sit');
CREATE TYPE incident_type AS ENUM ('damage', 'no_show', 'misconduct', 'other');
CREATE TYPE incident_status AS ENUM ('open', 'in_review', 'resolved', 'closed');
CREATE TYPE reminder_type AS ENUM ('24_hour', '2_hour');
CREATE TYPE verification_tier AS ENUM ('basic', 'verified', 'trusted');

-- ============================================
-- PROFILES (extends auth.users)
-- ============================================

CREATE TABLE profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    phone TEXT,
    first_name TEXT,
    last_name TEXT,
    avatar_url TEXT,
    role user_role NOT NULL DEFAULT 'client',
    city TEXT,
    suburb TEXT,
    coordinates POINT,
    is_verified BOOLEAN DEFAULT FALSE,
    verification_tier verification_tier DEFAULT 'basic',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- AGENCIES
-- ============================================

CREATE TABLE agencies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    admin_user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    logo_url TEXT,
    bio TEXT,
    business_registration_url TEXT,
    registration_verified BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- SITTER PROFILES
-- ============================================

CREATE TABLE sitter_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID UNIQUE NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    bio TEXT,
    services service_type[] DEFAULT '{}',
    pet_types pet_type[] DEFAULT '{}',
    rate_per_day INTEGER, -- in cents (ZAR)
    rate_per_visit INTEGER, -- in cents (ZAR)
    years_experience INTEGER DEFAULT 0,
    has_own_transport BOOLEAN DEFAULT FALSE,
    id_document_url TEXT,
    id_verified BOOLEAN DEFAULT FALSE,
    criminal_clearance_url TEXT,
    clearance_verified BOOLEAN DEFAULT FALSE,
    agency_id UUID REFERENCES agencies(id) ON DELETE SET NULL,
    rating_average DECIMAL(3,2) DEFAULT 0,
    rating_count INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- CLIENT PROFILES
-- ============================================

CREATE TABLE client_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID UNIQUE NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    address TEXT,
    home_type home_type,
    has_alarm BOOLEAN DEFAULT FALSE,
    has_pool BOOLEAN DEFAULT FALSE,
    special_instructions TEXT,
    id_document_url TEXT,
    id_verified BOOLEAN DEFAULT FALSE,
    selfie_url TEXT,
    selfie_verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- PETS
-- ============================================

CREATE TABLE pets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID NOT NULL REFERENCES client_profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    type pet_type NOT NULL,
    breed TEXT,
    age INTEGER,
    photo_url TEXT,
    medical_notes TEXT,
    feeding_instructions TEXT,
    temperament TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- BOOKINGS
-- ============================================

CREATE TABLE bookings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID NOT NULL REFERENCES profiles(id),
    sitter_id UUID NOT NULL REFERENCES profiles(id),
    service_type service_type NOT NULL,
    status booking_status DEFAULT 'pending',
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    total_amount INTEGER NOT NULL, -- in cents
    platform_fee INTEGER NOT NULL, -- in cents
    sitter_payout INTEGER NOT NULL, -- in cents
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- MEET & GREETS
-- ============================================

CREATE TABLE meet_greets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    proposed_location TEXT,
    proposed_time TIMESTAMPTZ,
    status meet_greet_status DEFAULT 'proposed',
    client_checked_in BOOLEAN DEFAULT FALSE,
    sitter_checked_in BOOLEAN DEFAULT FALSE,
    client_approved BOOLEAN DEFAULT FALSE,
    sitter_approved BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- MESSAGES
-- ============================================

CREATE TABLE messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES profiles(id),
    content TEXT NOT NULL,
    read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- REVIEWS
-- ============================================

CREATE TABLE reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    reviewer_id UUID NOT NULL REFERENCES profiles(id),
    reviewee_id UUID NOT NULL REFERENCES profiles(id),
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- TRANSACTIONS
-- ============================================

CREATE TABLE transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    type transaction_type NOT NULL,
    amount INTEGER NOT NULL, -- in cents
    status transaction_status DEFAULT 'pending',
    payment_provider_ref TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- SITTER CLIENT NOTES (Private)
-- ============================================

CREATE TABLE sitter_client_notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sitter_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    client_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(sitter_id, client_id)
);

-- ============================================
-- SAFETY WAIVERS
-- ============================================

CREATE TABLE safety_waivers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    sitter_id UUID NOT NULL REFERENCES profiles(id),
    public_meet_offered BOOLEAN DEFAULT TRUE,
    public_meet_accepted BOOLEAN DEFAULT FALSE,
    video_call_offered BOOLEAN DEFAULT FALSE,
    video_call_accepted BOOLEAN DEFAULT FALSE,
    waiver_signed BOOLEAN DEFAULT FALSE,
    waiver_signed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- MEETING REMINDERS
-- ============================================

CREATE TABLE meeting_reminders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    meet_greet_id UUID NOT NULL REFERENCES meet_greets(id) ON DELETE CASCADE,
    reminder_type reminder_type NOT NULL,
    scheduled_for TIMESTAMPTZ NOT NULL,
    sent BOOLEAN DEFAULT FALSE,
    sent_at TIMESTAMPTZ
);

-- ============================================
-- CLIENT RED FLAGS
-- ============================================

CREATE TABLE client_red_flags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    flag_type flag_type NOT NULL,
    details TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ
);

-- ============================================
-- INCIDENT REPORTS
-- ============================================

CREATE TABLE incident_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    reporter_id UUID NOT NULL REFERENCES profiles(id),
    reported_user_id UUID NOT NULL REFERENCES profiles(id),
    agency_id UUID REFERENCES agencies(id),
    incident_type incident_type NOT NULL,
    description TEXT NOT NULL,
    status incident_status DEFAULT 'open',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    resolved_at TIMESTAMPTZ
);

-- ============================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE sitter_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE client_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE agencies ENABLE ROW LEVEL SECURITY;
ALTER TABLE pets ENABLE ROW LEVEL SECURITY;
ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE meet_greets ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE sitter_client_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE safety_waivers ENABLE ROW LEVEL SECURITY;
ALTER TABLE meeting_reminders ENABLE ROW LEVEL SECURITY;
ALTER TABLE client_red_flags ENABLE ROW LEVEL SECURITY;
ALTER TABLE incident_reports ENABLE ROW LEVEL SECURITY;

-- ============================================
-- RLS POLICIES - PROFILES
-- ============================================

-- Anyone can view profiles
CREATE POLICY "Profiles are viewable by everyone" ON profiles
    FOR SELECT USING (true);

-- Users can update their own profile
CREATE POLICY "Users can update own profile" ON profiles
    FOR UPDATE USING (auth.uid() = id);

-- Users can insert their own profile
CREATE POLICY "Users can insert own profile" ON profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

-- ============================================
-- RLS POLICIES - SITTER PROFILES
-- ============================================

-- Anyone can view active sitter profiles
CREATE POLICY "Active sitter profiles are viewable" ON sitter_profiles
    FOR SELECT USING (is_active = true);

-- Sitters can update their own profile
CREATE POLICY "Sitters can update own profile" ON sitter_profiles
    FOR UPDATE USING (auth.uid() = user_id);

-- Sitters can insert their own profile
CREATE POLICY "Sitters can insert own profile" ON sitter_profiles
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ============================================
-- RLS POLICIES - CLIENT PROFILES
-- ============================================

-- Users can view their own client profile
CREATE POLICY "Users can view own client profile" ON client_profiles
    FOR SELECT USING (auth.uid() = user_id);

-- Sitters can view client profiles for their bookings
CREATE POLICY "Sitters can view client profiles for bookings" ON client_profiles
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM bookings 
            WHERE bookings.client_id = client_profiles.user_id 
            AND bookings.sitter_id = auth.uid()
        )
    );

-- Users can update their own client profile
CREATE POLICY "Users can update own client profile" ON client_profiles
    FOR UPDATE USING (auth.uid() = user_id);

-- Users can insert their own client profile
CREATE POLICY "Users can insert own client profile" ON client_profiles
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ============================================
-- RLS POLICIES - PETS
-- ============================================

-- Pet owners can manage their pets
CREATE POLICY "Users can manage own pets" ON pets
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM client_profiles 
            WHERE client_profiles.id = pets.client_id 
            AND client_profiles.user_id = auth.uid()
        )
    );

-- Sitters can view pets for their bookings
CREATE POLICY "Sitters can view pets for bookings" ON pets
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM bookings b
            JOIN client_profiles cp ON cp.user_id = b.client_id
            WHERE cp.id = pets.client_id 
            AND b.sitter_id = auth.uid()
        )
    );

-- ============================================
-- RLS POLICIES - BOOKINGS
-- ============================================

-- Users can view their own bookings (as client or sitter)
CREATE POLICY "Users can view own bookings" ON bookings
    FOR SELECT USING (auth.uid() = client_id OR auth.uid() = sitter_id);

-- Clients can create bookings
CREATE POLICY "Clients can create bookings" ON bookings
    FOR INSERT WITH CHECK (auth.uid() = client_id);

-- Participants can update bookings
CREATE POLICY "Participants can update bookings" ON bookings
    FOR UPDATE USING (auth.uid() = client_id OR auth.uid() = sitter_id);

-- ============================================
-- RLS POLICIES - MESSAGES
-- ============================================

-- Booking participants can view messages
CREATE POLICY "Booking participants can view messages" ON messages
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM bookings 
            WHERE bookings.id = messages.booking_id 
            AND (bookings.client_id = auth.uid() OR bookings.sitter_id = auth.uid())
        )
    );

-- Booking participants can send messages
CREATE POLICY "Booking participants can send messages" ON messages
    FOR INSERT WITH CHECK (
        auth.uid() = sender_id AND
        EXISTS (
            SELECT 1 FROM bookings 
            WHERE bookings.id = messages.booking_id 
            AND (bookings.client_id = auth.uid() OR bookings.sitter_id = auth.uid())
        )
    );

-- ============================================
-- RLS POLICIES - REVIEWS
-- ============================================

-- Anyone can view reviews
CREATE POLICY "Reviews are viewable by everyone" ON reviews
    FOR SELECT USING (true);

-- Booking participants can create reviews
CREATE POLICY "Booking participants can create reviews" ON reviews
    FOR INSERT WITH CHECK (
        auth.uid() = reviewer_id AND
        EXISTS (
            SELECT 1 FROM bookings 
            WHERE bookings.id = reviews.booking_id 
            AND (bookings.client_id = auth.uid() OR bookings.sitter_id = auth.uid())
            AND bookings.status = 'completed'
        )
    );

-- ============================================
-- RLS POLICIES - SITTER CLIENT NOTES
-- ============================================

-- Sitters can manage their own notes
CREATE POLICY "Sitters can manage own notes" ON sitter_client_notes
    FOR ALL USING (auth.uid() = sitter_id);

-- ============================================
-- FUNCTIONS & TRIGGERS
-- ============================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at trigger to relevant tables
CREATE TRIGGER update_profiles_updated_at
    BEFORE UPDATE ON profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_sitter_profiles_updated_at
    BEFORE UPDATE ON sitter_profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_client_profiles_updated_at
    BEFORE UPDATE ON client_profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_pets_updated_at
    BEFORE UPDATE ON pets
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_bookings_updated_at
    BEFORE UPDATE ON bookings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_meet_greets_updated_at
    BEFORE UPDATE ON meet_greets
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_sitter_client_notes_updated_at
    BEFORE UPDATE ON sitter_client_notes
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to create profile on user signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO profiles (id, email)
    VALUES (NEW.id, NEW.email);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to create profile on signup
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Function to update sitter rating
CREATE OR REPLACE FUNCTION update_sitter_rating()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE sitter_profiles
    SET 
        rating_average = (
            SELECT AVG(rating)::DECIMAL(3,2) 
            FROM reviews 
            WHERE reviewee_id = NEW.reviewee_id
        ),
        rating_count = (
            SELECT COUNT(*) 
            FROM reviews 
            WHERE reviewee_id = NEW.reviewee_id
        )
    WHERE user_id = NEW.reviewee_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update rating on new review
CREATE TRIGGER on_review_created
    AFTER INSERT ON reviews
    FOR EACH ROW EXECUTE FUNCTION update_sitter_rating();

-- ============================================
-- STORAGE BUCKETS (run in Supabase Dashboard)
-- ============================================
-- Note: Create these buckets in Supabase Dashboard:
-- 1. avatars (public)
-- 2. documents (private)
-- 3. agency-logos (public)

-- ============================================
-- INDEXES FOR PERFORMANCE
-- ============================================

CREATE INDEX idx_sitter_profiles_user_id ON sitter_profiles(user_id);
CREATE INDEX idx_sitter_profiles_agency_id ON sitter_profiles(agency_id);
CREATE INDEX idx_sitter_profiles_is_active ON sitter_profiles(is_active);
CREATE INDEX idx_client_profiles_user_id ON client_profiles(user_id);
CREATE INDEX idx_pets_client_id ON pets(client_id);
CREATE INDEX idx_bookings_client_id ON bookings(client_id);
CREATE INDEX idx_bookings_sitter_id ON bookings(sitter_id);
CREATE INDEX idx_bookings_status ON bookings(status);
CREATE INDEX idx_messages_booking_id ON messages(booking_id);
CREATE INDEX idx_reviews_reviewee_id ON reviews(reviewee_id);
CREATE INDEX idx_client_red_flags_client_id ON client_red_flags(client_id);
