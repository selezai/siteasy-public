-- Add meet & greet status enum for tracking completion
-- Statuses: proposed, completed, no_show, rescheduled, cancelled

-- First, we need to alter the existing status column to use an enum
-- The current column is TEXT, we'll create an enum and migrate

-- Create the enum type
DO $$ BEGIN
    CREATE TYPE meet_greet_status AS ENUM ('proposed', 'completed', 'no_show', 'rescheduled', 'cancelled');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Add a new column with the enum type
ALTER TABLE meet_greets ADD COLUMN IF NOT EXISTS status_enum meet_greet_status;

-- Migrate existing data
UPDATE meet_greets SET status_enum = 
    CASE 
        WHEN status = 'proposed' THEN 'proposed'::meet_greet_status
        WHEN status = 'completed' THEN 'completed'::meet_greet_status
        WHEN status = 'cancelled' THEN 'cancelled'::meet_greet_status
        ELSE 'proposed'::meet_greet_status
    END
WHERE status_enum IS NULL;

-- Set default for new rows
ALTER TABLE meet_greets ALTER COLUMN status_enum SET DEFAULT 'proposed'::meet_greet_status;

-- Add completed_at timestamp to track when meet & greet was marked complete
ALTER TABLE meet_greets ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ;

-- Add completed_by to track who marked it complete
ALTER TABLE meet_greets ADD COLUMN IF NOT EXISTS completed_by UUID REFERENCES profiles(id);

-- Add no_show_reported_by to track who reported a no-show
ALTER TABLE meet_greets ADD COLUMN IF NOT EXISTS no_show_reported_by UUID REFERENCES profiles(id);

-- Add notes field for any additional context
ALTER TABLE meet_greets ADD COLUMN IF NOT EXISTS completion_notes TEXT;

-- Create index for faster queries on status
CREATE INDEX IF NOT EXISTS idx_meet_greets_status_enum ON meet_greets(status_enum);

-- Create index for finding meet & greets that need follow-up (past date, not completed)
CREATE INDEX IF NOT EXISTS idx_meet_greets_pending_completion 
ON meet_greets(proposed_time, status_enum) 
WHERE status_enum = 'proposed';
