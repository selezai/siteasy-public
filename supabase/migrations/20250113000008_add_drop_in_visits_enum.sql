-- Add drop_in_visits to service_type enum
ALTER TYPE service_type ADD VALUE IF NOT EXISTS 'drop_in_visits';
