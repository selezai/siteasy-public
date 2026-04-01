-- Add 'no_show' and 'rescheduled' to meet_greet_status enum
-- Using pg_enum check to avoid errors if they already exist

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
