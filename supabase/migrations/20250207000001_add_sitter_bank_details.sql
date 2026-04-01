-- Add bank account details to sitter_profiles for payouts

-- Add bank details columns
ALTER TABLE sitter_profiles
ADD COLUMN IF NOT EXISTS bank_name TEXT,
ADD COLUMN IF NOT EXISTS bank_account_holder TEXT,
ADD COLUMN IF NOT EXISTS bank_account_number TEXT,
ADD COLUMN IF NOT EXISTS bank_branch_code TEXT,
ADD COLUMN IF NOT EXISTS bank_account_type TEXT CHECK (bank_account_type IN ('cheque', 'savings', 'transmission'));

-- Add comment explaining the fields
COMMENT ON COLUMN sitter_profiles.bank_name IS 'Name of the bank (e.g., FNB, Standard Bank, Capitec)';
COMMENT ON COLUMN sitter_profiles.bank_account_holder IS 'Name on the bank account';
COMMENT ON COLUMN sitter_profiles.bank_account_number IS 'Bank account number';
COMMENT ON COLUMN sitter_profiles.bank_branch_code IS 'Bank branch/universal code';
COMMENT ON COLUMN sitter_profiles.bank_account_type IS 'Type of account: cheque, savings, or transmission';
