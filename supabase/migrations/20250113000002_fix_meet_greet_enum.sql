-- Fix meet_greet_status enum to include all required values
-- The enum may have been created without 'no_show' and 'rescheduled' values

-- Add missing enum values (using a check to avoid errors if they exist)
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'no_show' AND enumtypid = 'meet_greet_status'::regtype) THEN
        ALTER TYPE meet_greet_status ADD VALUE 'no_show';
    END IF;
END $$;

DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'rescheduled' AND enumtypid = 'meet_greet_status'::regtype) THEN
        ALTER TYPE meet_greet_status ADD VALUE 'rescheduled';
    END IF;
END $$;
