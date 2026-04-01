-- Add meet and greet requirement fields to bookings table
-- This supports the nuanced meet and greet flow:
-- 1. First-time bookings: meet and greet required (or video call minimum)
-- 2. Repeat clients with same sitter: optional
-- 3. High-value bookings (long duration, multiple pets): required
-- 4. Short/simple bookings: video call minimum

-- Add new enum for meet greet requirement type
CREATE TYPE meet_greet_requirement AS ENUM ('required', 'video_call_minimum', 'optional', 'waiver_signed');

-- Add columns to bookings table
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS meet_greet_requirement meet_greet_requirement DEFAULT 'required';
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS is_first_booking_with_sitter BOOLEAN DEFAULT TRUE;
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS waiver_signed_at TIMESTAMPTZ;
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS waiver_signed_by UUID REFERENCES profiles(id);

-- Add video call fields to meet_greets table
ALTER TABLE meet_greets ADD COLUMN IF NOT EXISTS is_video_call BOOLEAN DEFAULT FALSE;
ALTER TABLE meet_greets ADD COLUMN IF NOT EXISTS video_call_link TEXT;
ALTER TABLE meet_greets ADD COLUMN IF NOT EXISTS video_call_completed_at TIMESTAMPTZ;

-- Create a function to determine meet and greet requirement
CREATE OR REPLACE FUNCTION determine_meet_greet_requirement(
    p_client_id UUID,
    p_sitter_id UUID,
    p_start_date DATE,
    p_end_date DATE,
    p_pet_count INTEGER DEFAULT 1
) RETURNS meet_greet_requirement AS $$
DECLARE
    v_previous_bookings INTEGER;
    v_booking_days INTEGER;
    v_is_high_value BOOLEAN;
BEGIN
    -- Check if this is a repeat client with this sitter
    SELECT COUNT(*) INTO v_previous_bookings
    FROM bookings
    WHERE client_id = p_client_id
      AND sitter_id = p_sitter_id
      AND status = 'completed';
    
    -- Calculate booking duration
    v_booking_days := p_end_date - p_start_date + 1;
    
    -- Determine if high-value booking (7+ days or 3+ pets)
    v_is_high_value := v_booking_days >= 7 OR p_pet_count >= 3;
    
    -- Apply rules:
    -- 1. First-time booking with sitter AND high-value: required
    -- 2. First-time booking with sitter: video_call_minimum
    -- 3. Repeat client with high-value booking: video_call_minimum
    -- 4. Repeat client with normal booking: optional
    
    IF v_previous_bookings = 0 THEN
        -- First time booking with this sitter
        IF v_is_high_value THEN
            RETURN 'required';
        ELSE
            RETURN 'video_call_minimum';
        END IF;
    ELSE
        -- Repeat client
        IF v_is_high_value THEN
            RETURN 'video_call_minimum';
        ELSE
            RETURN 'optional';
        END IF;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Create waivers table for tracking signed waivers
CREATE TABLE IF NOT EXISTS waivers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    signed_by UUID NOT NULL REFERENCES profiles(id),
    waiver_type TEXT NOT NULL DEFAULT 'meet_greet_skip',
    waiver_text TEXT NOT NULL,
    ip_address TEXT,
    user_agent TEXT,
    signed_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(booking_id, signed_by, waiver_type)
);

-- Enable RLS on waivers
ALTER TABLE waivers ENABLE ROW LEVEL SECURITY;

-- RLS policies for waivers
CREATE POLICY "Users can view own waivers" ON waivers
    FOR SELECT USING (
        signed_by = auth.uid() OR
        EXISTS (
            SELECT 1 FROM bookings 
            WHERE bookings.id = waivers.booking_id 
            AND (bookings.client_id = auth.uid() OR bookings.sitter_id = auth.uid())
        )
    );

CREATE POLICY "Users can sign waivers for their bookings" ON waivers
    FOR INSERT WITH CHECK (
        signed_by = auth.uid() AND
        EXISTS (
            SELECT 1 FROM bookings 
            WHERE bookings.id = waivers.booking_id 
            AND (bookings.client_id = auth.uid() OR bookings.sitter_id = auth.uid())
        )
    );
