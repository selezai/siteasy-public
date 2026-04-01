-- Add not_required to meet_greet_requirement enum for returning clients

ALTER TYPE meet_greet_requirement ADD VALUE IF NOT EXISTS 'not_required';
