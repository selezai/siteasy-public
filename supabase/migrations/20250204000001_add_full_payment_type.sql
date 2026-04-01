-- Add full_payment to transaction_type enum
ALTER TYPE transaction_type ADD VALUE IF NOT EXISTS 'full_payment';
